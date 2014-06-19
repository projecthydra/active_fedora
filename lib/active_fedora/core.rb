module ActiveFedora
  module Core
    extend ActiveSupport::Concern
    
    # Constructor.  You may supply a custom +:pid+, or we call the Fedora Rest API for the
    # next available Fedora pid, and mark as new object.
    # Also, if +attrs+ does not contain +:pid+ but does contain +:namespace+ it will pass the
    # +:namespace+ value to Fedora::Repository.nextid to generate the next pid available within
    # the given namespace.
    def initialize(attrs = nil)
      super
      @association_cache = {}
      load_datastreams
      run_callbacks :initialize
    end

    # Reloads the object from Fedora.
    def reload
      raise ActiveFedora::ObjectNotFoundError, "Can't reload an object that hasn't been saved" unless persisted?
      clear_association_cache
      clear_datastreams
      load_datastreams
      super
      self
    end

    def ==(comparison_object)
         comparison_object.equal?(self) ||
           (comparison_object.instance_of?(self.class) &&
             comparison_object.pid == pid &&
             !comparison_object.new_record?)
    end

    def clone
      new_object = self.class.create
      clone_into(new_object)
    end

    # Clone the datastreams from this object into the provided object, while preserving the pid of the provided object
    # @param [Base] new_object clone into this object
    def clone_into(new_object)
      raise "need to rewrite the local graph"
      datastreams.each do |k, v|
        new_object.datastreams[k].content = v.content
      end
      new_object if new_object.save
    end

    def freeze
      datastreams.freeze
      self
    end

    def frozen?
      datastreams.frozen?
    end

    module ClassMethods
      # Returns a suitable uri object for :has_model
      # Should reverse Model#from_class_uri
      def to_class_uri(attrs = {})
        if self.respond_to? :pid_suffix
          pid_suffix = self.pid_suffix
        else
          pid_suffix = attrs.fetch(:pid_suffix, ContentModel::CMODEL_PID_SUFFIX)
        end
        if self.respond_to? :pid_namespace
          namespace = self.pid_namespace
        else
          namespace = attrs.fetch(:namespace, ContentModel::CMODEL_NAMESPACE)
        end
        "info:fedora/#{namespace}:#{ContentModel.sanitized_class_name(self)}#{pid_suffix}" 
      end

      private
      def relation
        Relation.new(self)
      end
    end
  end
end
