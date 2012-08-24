SOLR_DOCUMENT_ID = "id" unless (defined?(SOLR_DOCUMENT_ID) && !SOLR_DOCUMENT_ID.nil?)
ENABLE_SOLR_UPDATES = true unless defined?(ENABLE_SOLR_UPDATES)
require "digest"

module ActiveFedora
  
  # This class ties together many of the lower-level modules, and
  # implements something akin to an ActiveRecord-alike interface to
  # fedora. If you want to represent a fedora object in the ruby
  # space, this is the class you want to extend.
  #
  # =The Basics
  #   class Oralhistory < ActiveFedora::Base
  #     has_metadata :name => "properties", :type => ActiveFedora::MetadataDatastream do |m|
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
    self.profile_solr_name = ActiveFedora::SolrService.solr_name("object_profile", :string, :displayable)

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


    # Has this object been saved?
    def new_object?
      inner_object.new?
    end
    
    def new_object=(bool)
      ActiveSupport::Deprecation.warn("ActiveFedora::Base.new_object= has been deprecated and nolonger has any effect. Will be removed in 5.0")
    end

    ## Required by associations
    def new_record?
      self.new_object?
    end

    def persisted?
      !new_object?
    end

    def attributes=(properties)
      properties.each do |k, v|
        respond_to?(:"#{k}=") ? send(:"#{k}=", v) : raise(UnknownAttributeError, "unknown attribute: #{k}")
      end
    end

    # Constructor.  You may supply a custom +:pid+, or we call the Fedora Rest API for the
    # next available Fedora pid, and mark as new object.
    # Also, if +attrs+ does not contain +:pid+ but does contain +:namespace+ it will pass the
    # +:namespace+ value to Fedora::Repository.nextid to generate the next pid available within
    # the given namespace.
    def initialize(attrs = nil)
      attrs = {} if attrs.nil?
      attributes = attrs.dup
      @inner_object = UnsavedDigitalObject.new(self.class, attributes.delete(:namespace), attributes.delete(:pid))
      self.relationships_loaded = true
      load_datastreams

      [:new_object,:create_date, :modified_date].each { |k| attributes.delete(k)}
      self.attributes=attributes
      run_callbacks :initialize
    end


    # Initialize an empty model object and set the +inner_obj+
    # example:
    #
    #   class Post < ActiveFedora::Base
    #     has_metadata :name => "properties", :type => ActiveFedora::MetadataDatastream
    #   end
    #
    #   post = Post.allocate
    #   post.init_with(DigitalObject.find(pid))
    #   post.properties.title # => 'hello world'
    def init_with(inner_obj)
      @inner_object = inner_obj
      unless @inner_object.is_a? SolrDigitalObject
        @inner_object.original_class = self.class
        ## Replace existing unchanged datastreams with the definitions found in this class if they have a different type.
        ## Any datastream that is deleted here will cause a reload from fedora, so avoid it whenever possible
        ds_specs.keys.each do |key|
          if !@inner_object.datastreams[key].changed.include?('content') && @inner_object.datastreams[key].class != self.class.ds_specs[key][:type]
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

    def self.create(args = {})
      obj = self.new(args)
      obj.save
      obj
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
      d = REXML::Document.new( fedora_connection[0].connection.next_pid(args))
      pid =d.elements['//pid'].text
      pid
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
    
    def to_key
      persisted? ? [pid] : nil
    end

    #return the internal fedora URI
    def internal_uri
      "info:fedora/#{pid}"
    end

    #return the state of the inner object
    def state 
      @inner_object.state
    end

    #return the owner id
    def owner_id
      @inner_object.ownerId
    end
    
    def owner_id=(owner_id)
      @inner_object.ownerId=(owner_id)
    end

    #return the create_date of the inner object (unless it's a new object)
    def create_date
      @inner_object.new? ? Time.now : @inner_object.profile["objCreateDate"]
    end

    #return the modification date of the inner object (unless it's a new object)
    def modified_date
      @inner_object.new? ? Time.now : @inner_object.profile["objLastModDate"]
    end

    #return the label of the inner object (unless it's a new object)
    def label
      @inner_object.label
    end
    
    def label=(new_label)
      @inner_object.label = new_label
    end

    #Return a hash of all available metadata fields for all 
    #ActiveFedora::MetadataDatastream datastreams, as well as 
    #system_create_date, system_modified_date, active_fedora_model_field, 
    #and the object id.
    def fields
    # TODO this can likely be removed once find_by_fields_by_solr is removed
      fields = {:id => {:values => [pid]}, :system_create_date => {:values => [self.create_date], :type=>:date}, :system_modified_date => {:values => [self.modified_date], :type=>:date}, :active_fedora_model => {:values => [self.class.inspect], :type=>:symbol}}
      datastreams.values.each do |ds|        
        fields.merge!(ds.fields) if [ActiveFedora::MetadataDatastream, ActiveFedora::SimpleDatastream, ActiveFedora::QualifiedDublinCoreDatastream].include?(ds.class)
      end
      return fields
    end
    
    #Returns the xml version of this object as a string.
    def to_xml(xml=Nokogiri::XML::Document.parse("<xml><fields/><content/></xml>"))
      ActiveSupport::Deprecation.warn("ActiveFedora::Base#to_xml has been deprecated and will be removed in version 5.0")
      fields_xml = xml.xpath('//fields').first
      builder = Nokogiri::XML::Builder.with(fields_xml) do |fields_xml|
        fields_xml.id_ pid
        fields_xml.system_create_date self.create_date
        fields_xml.system_modified_date self.modified_date
        fields_xml.active_fedora_model self.class.inspect
      end
      
      datastreams.each_value do |ds|  
        ds.to_xml(fields_xml) if ds.class.included_modules.include?(ActiveFedora::MetadataDatastreamHelper)
        ds.to_rels_ext if ds.kind_of?(ActiveFedora::RelsExtDatastream)
      end
      return xml.to_s
    end

    def ==(comparison_object)
         comparison_object.equal?(self) ||
           (comparison_object.instance_of?(self.class) &&
             comparison_object.pid == pid &&
             !comparison_object.new_record?)
    end
  
    def inspect
      "#<#{self.class}:#{self.hash} @pid=\"#{pid}\" >"
    end

    # Return a Hash representation of this object where keys in the hash are appropriate Solr field names.
    # @param [Hash] solr_doc (optional) Hash to insert the fields into
    # @param [Hash] opts (optional) 
    # If opts[:model_only] == true, the base object metadata and the RELS-EXT datastream will be omitted.  This is mainly to support shelver, which calls .to_solr for each model an object subscribes to. 
    def to_solr(solr_doc = Hash.new, opts={})
      unless opts[:model_only]
        c_time = create_date
        c_time = Time.parse(c_time) unless c_time.is_a?(Time)
        m_time = modified_date
        m_time = Time.parse(m_time) unless m_time.is_a?(Time)
        solr_doc.merge!(SOLR_DOCUMENT_ID.to_sym => pid, ActiveFedora::SolrService.solr_name(:system_create, :date) => c_time.utc.xmlschema, ActiveFedora::SolrService.solr_name(:system_modified, :date) => m_time.utc.xmlschema, ActiveFedora::SolrService.solr_name(:active_fedora_model, :symbol) => self.class.inspect)
        solrize_profile(solr_doc)
      end
      datastreams.each_value do |ds|
        ds.ensure_xml_loaded if ds.respond_to? :ensure_xml_loaded  ### Can't put this in the model because it's often implemented in Solrizer::XML::TerminologyBasedSolrizer 
        solr_doc = ds.to_solr(solr_doc)
      end
      solr_doc = solrize_relationships(solr_doc) unless opts[:model_only]
      solr_doc
    end

    def solrize_profile(solr_doc = Hash.new) # :nodoc:
      profile_hash = { 'datastreams' => {} }
      if inner_object.respond_to? :profile
        inner_object.profile.each_pair do |property,value|
          if property =~ /Date/
            value = Time.parse(value) unless value.is_a?(Time)
            value = value.xmlschema
          end
          profile_hash[property] = value
        end
      end
      self.datastreams.each_pair { |dsid,ds| profile_hash['datastreams'][dsid] = ds.solrize_profile }
      solr_doc[self.class.profile_solr_name] = profile_hash.to_json
    end
    
    # Serialize the datastream's RDF relationships to solr
    # @param [Hash] solr_doc @deafult an empty Hash
    def solrize_relationships(solr_doc = Hash.new)
      relationships.each_statement do |statement|
        predicate = RelsExtDatastream.short_predicate(statement.predicate)
        literal = statement.object.kind_of?(RDF::Literal)
        val = literal ? statement.object.value : statement.object.to_str
        ::Solrizer::Extractor.insert_solr_field_value(solr_doc, solr_name(predicate, :symbol), val )
      end
      return solr_doc
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
    
    # This method can be used instead of ActiveFedora::Model::ClassMethods.find.  
    # It works similarly except it populates an object from Solr instead of Fedora.
    # It is most useful for objects used in read-only displays in order to speed up loading time.  If only
    # a pid is passed in it will query solr for a corresponding solr document and then use it
    # to populate this object.
    # 
    # If a value is passed in for optional parameter solr_doc it will not query solr again and just use the
    # one passed to populate the object.
    #
    # It will anything stored within solr such as metadata and relationships.  Non-metadata datastreams will not
    # be loaded and if needed you should use find instead.
    def self.load_instance_from_solr(pid,solr_doc=nil)
      if solr_doc.nil?
        result = find_with_conditions(:id=>pid)
        raise ActiveFedora::ObjectNotFoundError, "Object #{pid} not found in solr" if result.empty?
        solr_doc = result.first
        #double check pid and id in record match
        raise ActiveFedora::ObjectNotFoundError, "Object #{pid} not found in Solr" unless !result.nil? && !solr_doc.nil? && pid == solr_doc[SOLR_DOCUMENT_ID]
      else
        raise "Solr document record id and pid do not match" unless pid == solr_doc[SOLR_DOCUMENT_ID]
      end
      klass = if class_str = solr_doc['has_model_s']
        # Parse RDF string "info:fedora/afmodel:ActiveFedora_Base"
        class_str.first.split(/:/).last.gsub(/_/,"::").constantize
      else
        ActiveFedora::Base
      end

      profile_json = Array(solr_doc[ActiveFedora::Base.profile_solr_name]).first
      unless profile_json.present?
        raise ActiveFedora::ObjectNotFoundError, "Object #{pid} does not contain a solrized profile"
      end
      profile_hash = ActiveSupport::JSON.decode(profile_json)
      obj = klass.allocate.init_with(SolrDigitalObject.new(solr_doc, profile_hash, klass))
      #set by default to load any dependent relationship objects from solr as well
      #need to call rels_ext once so it exists when iterating over datastreams
      obj.rels_ext
      obj.datastreams.each_value do |ds|
        if ds.respond_to?(:profile_from_hash) and (ds_prof = profile_hash['datastreams'][ds.dsid])
          ds.profile_from_hash(ds_prof)
        end
        if ds.respond_to?(:from_solr)
          ds.from_solr(solr_doc) if ds.kind_of?(ActiveFedora::MetadataDatastream) || ds.kind_of?(ActiveFedora::NokogiriDatastream) || ( ds.kind_of?(ActiveFedora::RelsExtDatastream))
        end
      end
      obj.inner_object.freeze
      obj
    end

    # A convenience method  for updating indexed attributes.  The passed in hash
    # must look like this : 
    #   {{:name=>{"0"=>"a","1"=>"b"}}
    #
    # This will result in any datastream field of name :name having the value [a,b]
    #
    # An index of -1 will insert a new value. any existing value at the relevant index 
    # will be overwritten.
    #
    # As in update_attributes, this overwrites _all_ available fields by default.
    #
    # If you want to specify which datastream(s) to update,
    # use the :datastreams argument like so:
    #  m.update_attributes({"fubar"=>{"-1"=>"mork", "0"=>"york", "1"=>"mangle"}}, :datastreams=>"my_ds")
    # or
    #  m.update_attributes({"fubar"=>{"-1"=>"mork", "0"=>"york", "1"=>"mangle"}}, :datastreams=>["my_ds", "my_other_ds"])
    #
    def update_indexed_attributes(params={}, opts={})
      if ds = opts[:datastreams]
        ds_array = []
        ds = [ds] unless ds.respond_to? :each
        ds.each do |dsname|
          ds_array << datastreams[dsname]
        end
      else
        ds_array = metadata_streams
      end
      result = {}
      ds_array.each do |d|
        result[d.dsid] = d.update_indexed_attributes(params,opts)
      end
      return result
    end
    
    # Updates the attributes for each datastream named in the params Hash
    # @param [Hash] params A Hash whose keys correspond to datastream ids and whose values are appropriate Hashes to submit to update_indexed_attributes on that datastream
    # @param [Hash] opts (currently ignored.)
    # @example Update the descMetadata and properties datastreams with new values
    #   article = HydrangeaArticle.new
    #   ds_values_hash = {
    #     "descMetadata"=>{ [{:person=>0}, :role]=>{"0"=>"role1", "1"=>"role2", "2"=>"role3"} },
    #     "properties"=>{ "notes"=>"foo" }
    #   }
    #   article.update_datastream_attributes( ds_values_hash )
    def update_datastream_attributes(params={}, opts={})
      result = params.dup
      params.each_pair do |dsid, ds_params| 
        if datastreams.include?(dsid)
          result[dsid] = datastreams[dsid].update_indexed_attributes(ds_params)
        else
          result.delete(dsid)
        end
      end
      return result
    end
    
    def get_values_from_datastream(dsid,field_key,default=[])
      if datastreams.include?(dsid)
        return datastreams[dsid].get_values(field_key,default)
      else
        return nil
      end
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
    include ActiveFedora::Persistence
    include Model
    include Solrizer::FieldNameMapper
    include Loggable
    include ActiveModel::Conversion
    include Validations
    include Callbacks
    include Datastreams
    extend ActiveModel::Naming
    include Delegating
    include Associations
    include NestedAttributes
    include Reflection
    include NamedRelationships ##TODO don't include by default
  end

end
