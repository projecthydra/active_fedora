SOLR_DOCUMENT_ID = "id" unless (defined?(SOLR_DOCUMENT_ID) && !SOLR_DOCUMENT_ID.nil?)
ENABLE_SOLR_UPDATES = true unless defined?(ENABLE_SOLR_UPDATES)
require "digest"
require 'active_support/descendants_tracker'

module ActiveFedora
  
  # This class ties together many of the lower-level modules, and
  # implements something akin to an ActiveRecord-alike interface to
  # fedora. If you want to represent a fedora object in the ruby
  # space, this is the class you want to extend.
  #
  # =The Basics
  #   class Oralhistory < ActiveFedora::Base
  #     has_metadata :name => "properties", :type => ActiveFedora::SimpleDatastream do |m|
  #       m.field "narrator",  :string
  #       m.field "narrator",  :text
  #     end
  #   end
  #
  # The above example creates a Fedora object with a metadata datastream named "properties", which is composed of a 
  # narrator and bio field.
  #
  # Datastreams defined with +has_metadata+ are accessed via the +datastreams+ member hash.
  #
  class Base
    include SemanticNode

    class_attribute :fedora_connection, :profile_solr_name
    self.fedora_connection = {}
    self.profile_solr_name = ActiveFedora::SolrService.solr_name("object_profile", :displayable)

    delegate :state=,:label=, to: :inner_object

    def method_missing(name, *args)
      dsid = corresponding_datastream_name(name)
      if dsid
        ### Create and invoke a proxy method 
        self.class.send :define_method, name do
            datastreams[dsid]
        end
        self.send(name)
      else 
        super
      end
    end

    def new?
      new_object?
    end

    # Has this object been saved?
    def new_object?
      inner_object.new?
    end
    
    ## Required by associations
    def new_record?
      self.new_object?
    end

    def persisted?
      !new_object?
    end

    def mark_for_destruction
      @marked_for_destruction = true
    end

    def marked_for_destruction?
      @marked_for_destruction
    end

    def reload(options = nil)
      @marked_for_destruction = false
      super
    end

    # Constructor.  You may supply a custom +:pid+, or we call the Fedora Rest API for the
    # next available Fedora pid, and mark as new object.
    # Also, if +attrs+ does not contain +:pid+ but does contain +:namespace+ it will pass the
    # +:namespace+ value to Fedora::Repository.nextid to generate the next pid available within
    # the given namespace.
    def initialize(attrs = nil)
      attrs = {} if attrs.nil?
      @association_cache = {}
      attributes = attrs.dup
      @inner_object = UnsavedDigitalObject.new(self.class, attributes.delete(:namespace), attributes.delete(:pid))
      self.relationships_loaded = true
      load_datastreams

      [:new_object,:create_date, :modified_date].each { |k| attributes.delete(k)}
      self.attributes=attributes
      run_callbacks :initialize
    end

    # Reloads the object from Fedora.
    def reload
      clear_association_cache
      init_with(self.class.find(self.pid).inner_object)
    end

    # Initialize an empty model object and set the +inner_obj+
    # example:
    #
    #   class Post < ActiveFedora::Base
    #     has_metadata :name => "properties", :type => ActiveFedora::SimpleDatastream
    #   end
    #
    #   post = Post.allocate
    #   post.init_with(DigitalObject.find(pid))
    #   post.properties.title # => 'hello world'
    def init_with(inner_obj)
      @association_cache = {}
      @inner_object = inner_obj
      unless @inner_object.is_a? SolrDigitalObject
        @inner_object.original_class = self.class
        ## Replace existing unchanged datastreams with the definitions found in this class if they have a different type.
        ## Any datastream that is deleted here will cause a reload from fedora, so avoid it whenever possible
        ds_specs.keys.each do |key|
          if !@inner_object.datastreams[key].content_changed? && @inner_object.datastreams[key].class != self.class.ds_specs[key][:type]
            @inner_object.datastreams.delete(key)
          end
        end
      end
      load_datastreams
      run_callbacks :find
      run_callbacks :initialize
      self
    end

    # Uses {shard_index} to find or create the rubydora connection for this pid
    # @param [String] pid the identifier of the object to get the connection for
    # @return [Rubydora::Repository] The repository that the identifier exists in.
    def self.connection_for_pid(pid)
      idx = shard_index(pid)
      unless fedora_connection.has_key? idx
        if ActiveFedora.config.sharded?
          fedora_connection[idx] = RubydoraConnection.new(ActiveFedora.config.credentials[idx])
        else
          fedora_connection[idx] = RubydoraConnection.new(ActiveFedora.config.credentials)
        end
      end
      fedora_connection[idx].connection
    end

    # This is where your sharding strategy is implemented -- it's how we figure out which shard an object will be (or was) written to.
    # Given a pid, it decides which shard that pid will be written to (and thus retrieved from).
    # For a given pid, as long as your shard configuration remains the same it will always return the same value.
    # If you're not using sharding, this will always return 0, meaning use the first/only Fedora Repository in your configuration.
    # Default strategy runs a modulo of the md5 of the pid against the number of shards.
    # If you want to use a different sharding strategy, override this method.  Make sure that it will always return the same value for a given pid and shard configuration.
    #@return [Integer] the index of the shard this object is stored in
    def self.shard_index(pid)
      if ActiveFedora.config.sharded?
        Digest::MD5.hexdigest(pid).hex % ActiveFedora.config.credentials.length
      else
        0
      end
    end
    

    def self.datastream_class_for_name(dsid)
      ds_specs[dsid] ? ds_specs[dsid].fetch(:type, ActiveFedora::Datastream) : ActiveFedora::Datastream
    end

    def clone
      new_object = self.class.create
      clone_into(new_object)
    end

    # Clone the datastreams from this object into the provided object, while preserving the pid of the provided object
    # @param [Base] new_object clone into this object
    def clone_into(new_object)
      rels = Nokogiri::XML( rels_ext.content)
      rels.xpath("//rdf:Description/@rdf:about").first.value = new_object.internal_uri
      new_object.rels_ext.content = rels.to_xml

      datastreams.each do |k, v|
        next if k == 'RELS-EXT'
        new_object.datastreams[k].content = v.content
      end
      new_object if new_object.save
    end

    ### if you are doing sharding, override this method to do something other than use a sequence
    # @return [String] the unique pid for a new object
    def self.assign_pid(obj)
      args = {}
      args[:namespace] = obj.namespace if obj.namespace
      # TODO: This juggling of Fedora credentials & establishing connections should be handled by 
      # an establish_fedora_connection method,possibly wrap it all into a fedora_connection method - MZ 06-05-2012
      if ActiveFedora.config.sharded?
        credentials = ActiveFedora.config.credentials[0]
      else
        credentials = ActiveFedora.config.credentials
      end
      fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(credentials)
      fedora_connection[0].connection.mint(args)
    end

    def inner_object # :nodoc
      @inner_object
    end

    #return the pid of the Fedora Object
    # if there is no fedora object (loaded from solr) get the instance var
    # TODO make inner_object a proxy that can hold the pid
    def pid
       @inner_object.pid
    end


    def id   ### Needed for the nested form helper
      self.pid
    end
    
    def to_param
      persisted? ? to_key.join('-') : nil
    end

    def to_key
      persisted? ? [pid] : nil
    end

    #return the internal fedora URI
    def internal_uri
      "info:fedora/#{pid}" if pid
    end

    #return the owner id
    def owner_id
      Array(@inner_object.ownerId).first
    end
    
    def owner_id=(owner_id)
      @inner_object.ownerId=(owner_id)
    end

    def label
      Array(@inner_object.label).first
    end

    def state
      Array(@inner_object.state).first
    end

    #return the create_date of the inner object (unless it's a new object)
    def create_date
      if @inner_object.new?
        Time.now
      elsif @inner_object.respond_to? :createdDate
        Array(@inner_object.createdDate).first
      else
        @inner_object.profile['objCreateDate']
      end
    end

    #return the modification date of the inner object (unless it's a new object)
    def modified_date
      @inner_object.new? ? Time.now : Array(@inner_object.lastModifiedDate).first
    end

    def ==(comparison_object)
         comparison_object.equal?(self) ||
           (comparison_object.instance_of?(self.class) &&
             comparison_object.pid == pid &&
             !comparison_object.new_record?)
    end


    def pretty_pid
      if self.pid == UnsavedDigitalObject::PLACEHOLDER
        nil
      else
        self.pid
      end
    end

    # This method adapts the inner_object to a new ActiveFedora::Base implementation
    # This is intended to minimize redundant interactions with Fedora
    def adapt_to(klass)
      unless klass.ancestors.include? ActiveFedora::Base
        raise "Cannot adapt #{self.class.name} to #{klass.name}: Not a ActiveFedora::Base subclass"
      end
      klass.allocate.init_with(inner_object)
    end

    # Examine the :has_model assertions in the RELS-EXT.  Adapt this class to the first first known model
    def adapt_to_cmodel
      the_model = ActiveFedora::ContentModel.known_models_for( self ).first
      self.class != the_model ? self.adapt_to(the_model) : self
    end
    
    # ** EXPERIMENTAL **
    # This method returns a new object of the same class, with the internal SolrDigitalObject
    # replaced with an actual DigitalObject.
    def reify
      if self.inner_object.is_a? DigitalObject
        raise "#{self.inspect} is already a full digital object"
      end
      self.class.find self.pid
    end
    
    # ** EXPERIMENTAL **
    # This method reinitializes a lightweight, loaded-from-solr object with an actual
    # DigitalObject inside.
    def reify!
      if self.inner_object.is_a? DigitalObject
        raise "#{self.inspect} is already a full digital object"
      end
      self.init_with DigitalObject.find(self.class,self.pid)
    end
    
    def self.pids_from_uris(uris) 
      if uris.class == String
        return uris.gsub("info:fedora/", "")
      elsif uris.class == Array
        arr = []
        uris.each do |uri|
          arr << uri.gsub("info:fedora/", "")
        end
        return arr
      end
    end
  end

  Base.class_eval do
    include Attributes
    include ActiveFedora::Persistence
    extend ActiveSupport::DescendantsTracker
    extend Model
    include Loggable
    include Indexing
    include ActiveModel::Conversion
    include Validations
    include Callbacks
    include Datastreams
    extend ActiveModel::Naming
    include Delegating
    extend Querying
    include Associations
    include NestedAttributes
    include Reflection
    include ActiveModel::Dirty
  end

end
