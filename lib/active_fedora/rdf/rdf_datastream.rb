module ActiveFedora
  class RDFDatastream < ActiveFedora::Datastream
    include Solrizer::Common
    include ActiveTriples::NestedAttributes
    include RDF::Indexing
    include ActiveTriples::Properties
    include ActiveTriples::Reflection

    delegate :rdf_subject, :set_value, :get_values, :attributes=, :to => :resource

    class << self
      def rdf_subject &block
        if block_given?
          return @subject_block = block
        end

        @subject_block ||= lambda { |ds| ds.pid }
      end

      ##
      # @param [Class] an object to set as the resource class, Must be a descendant of 
      # ActiveTriples::Resource and include ActiveFedora::Rdf::Persistence.
      #
      # @return [Class] the object resource class
      def resource_class(klass=nil)
        if klass
          raise ArgumentError, "#{self} already has a resource_class #{@resource_class}, cannot redefine it to #{klass}" if @resource_class and klass != @resource_class
          raise ArgumentError, "#{klass} must be a subclass of ActiveTriples::Resource" unless klass < ActiveTriples::Resource
        end
        
        @resource_class ||= begin
                              klass = Class.new(klass || ActiveTriples::Resource)
                              klass.send(:include, RDF::Persistence)
                              klass
                            end
      end                                                    
    end

    before_save do
      if content.blank?
        ActiveFedora::Base.logger.warn "Cowardly refusing to save a datastream with empty content: #{self.inspect}" if ActiveFedora::Base.logger
        if ActiveSupport.version >= Gem::Version.new('5.0')
          throw(:abort)
        else
          false
        end
      end
    end

    def metadata?
      true
    end

    def content
      serialize
    end

    def content=(new_content)
      resource.clear!
      resource << deserialize(new_content)
      new_content
    end

    def content_changed?
      return false unless instance_variable_defined? :@resource
      @content = serialize
      super
    end

    def freeze
      @resource.freeze
    end

    ##
    # The resource is the RdfResource object that stores the graph for
    # the datastream and is the central point for its relationship to
    # other nodes.
    #
    # set_value, get_value, and property accessors are delegated to this object.
    def resource
      @resource ||= begin
                      klass = self.class.resource_class
                      klass.properties.merge(self.class.properties).each do |prop, config|
                        klass.property(config.term, 
                                       predicate: config.predicate, 
                                       class_name: config.class_name, 
                                       multivalue: config.multivalue)
                      end
                      klass.accepts_nested_attributes_for(*nested_attributes_options.keys) unless nested_attributes_options.blank?
                      uri_stub = digital_object ? self.class.rdf_subject.call(self) : nil

                      r = klass.new(uri_stub)
                      r.datastream = self
                      r << deserialize
                      r
                    end
    end

    alias_method :graph, :resource

    ##
    # This method allows for delegation.
    # This patches the fact that there's no consistent API for allowing delegation - we're matching the
    # OMDatastream implementation as our "consistency" point.
    # @TODO: We may need to enable deep RDF delegation at one point.
    def term_values(*values)
      self.send(values.first)
    end

    def update_indexed_attributes(hash)
      hash.each do |fields, value|
        fields.each do |field|
          self.send("#{field}=", value)
        end
      end
    end

    def serialize
      resource.set_subject!(pid) if (digital_object or pid) and rdf_subject.node?
      resource.dump serialization_format
    end

    def deserialize(data=nil)
      return ::RDF::Graph.new if new? && data.nil?

      if data.nil?
        data = datastream_content
      elsif behaves_like_io?(data)
        data = io_content(data)
      end

      # Because datastream_content can return nil, we should check that here.
      return ::RDF::Graph.new if data.nil?

      data.force_encoding('utf-8')
      ::RDF::Graph.new << ::RDF::Reader.for(serialization_format).new(data)
    end

    def serialization_format
      raise "you must override the `serialization_format' method in a subclass"
    end

    private

    def io_content(data)
      begin
        data.rewind
        data.read
      ensure
        data.rewind
      end
    end

  end
end
