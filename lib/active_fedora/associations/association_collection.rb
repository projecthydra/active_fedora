module ActiveFedora
  module Associations
    class AssociationCollection < AssociationProxy #:nodoc:
      def initialize(owner, reflection)
        super
        construct_query
      end

      # Returns the size of the collection 
      #
      # If the collection has been already loaded +size+ and +length+ are
      # equivalent. If not and you are going to need the records anyway
      # +length+ will take one less query. Otherwise +size+ is more efficient.
      #
      # This method is abstract in the sense that it relies on
      # +count_records+, which is a method descendants have to provide.
      def size
        if @owner.new_record? && @target
          @target.size
        elsif !loaded? && @target.is_a?(Array)
          unsaved_records = @target.select { |r| r.new_record? }
          unsaved_records.size + count_records
        else
          count_records
        end
      end

      # Replace this collection with +other_array+
      # This will perform a diff and delete/add only records that have changed.
      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch(val) }

        load_target
        other   = other_array.size < 100 ? other_array : other_array.to_set
        current = @target.size < 100 ? @target : @target.to_set

        delete(@target.select { |v| !other.include?(v) })
        concat(other_array.select { |v| !current.include?(v) })
      end
      

      def to_ary
        load_target
        if @target.is_a?(Array)
          @target.to_ary
        else
          Array.wrap(@target)
        end
      end
      alias_method :to_a, :to_ary

      def reset
        reset_target!
        @loaded = false
      end

      def build(attributes = {}, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          build_record(attributes) do |record|
            block.call(record) if block_given?
            set_belongs_to_association_for(record)
          end
        end
      end

      # Add +records+ to this association.  Returns +self+ so method calls may be chained.
      # Since << flattens its argument list and inserts each record, +push+ and +concat+ behave identically.
      def <<(*records)
        result = true
        load_target unless loaded?

        flatten_deeper(records).each do |record|
          raise_on_type_mismatch(record)
          add_record_to_target_with_callbacks(record) do |r|
            result &&= insert_record(record)
          end
        end

        result && self
      end

      alias_method :push, :<<
      alias_method :concat, :<<

      # Removes +records+ from this association calling +before_remove+ and
      # +after_remove+ callbacks.
      #
      # This method is abstract in the sense that +delete_records+ has to be
      # provided by descendants. Note this method does not imply the records
      # are actually removed from the database, that depends precisely on
      # +delete_records+. They are in any case removed from the collection.
      def delete(*records)
        remove_records(records) do |_records, old_records|
          delete_records(old_records) if old_records.any?
          _records.each { |record| @target.delete(record) }
        end
      end

      def create(attrs = {})
        if attrs.is_a?(Array)
          attrs.collect { |attr| create(attr) }
        else
          create_record(attrs) do |record|
            yield(record) if block_given?
            record.save
          end
        end
      end

      def create!(attrs = {})
        create_record(attrs) do |record|
          yield(record) if block_given?
          record.save!
        end
      end
      

      def load_target
        if !@owner.new_record?
          begin
            if !loaded?
              if @target.is_a?(Array) && @target.any?
                @target = find_target.map do |f|
                  i = @target.index(f)
                  if i
                    @target.delete_at(i).tap do |t|
                      keys = ["id"] + t.changes.keys + (f.attribute_names - t.attribute_names)
                      t.attributes = f.attributes.except(*keys)
                    end
                  else
                    f
                  end
                end + @target
              else
                @target = find_target
              end
            end
          rescue ObjectNotFoundError => e
            logger.error "Solr and Fedora may be out of sync:\n" + e.message
            reset
          end
        end

        loaded if target
        target
      end

      def find_target
        return [] if @finder_query.empty?
        solr_result = SolrService.query(@finder_query, :rows=>1000)
#TODO, don't reify, just store the solr results and lazily reify.
        return ActiveFedora::SolrService.reify_solr_results(solr_result)
      end

      def load_from_solr
        return [] if @finder_query.empty?
        SolrService.query(@finder_query, :rows=>1000)
      end


      def add_record_to_target_with_callbacks(record)
      #  callback(:before_add, record)
        yield(record) if block_given?
        @target ||= [] unless loaded?
        if index = @target.index(record)
          @target[index] = record
        else
           @target << record
        end
      #  callback(:after_add, record)
      #  set_inverse_instance(record, @owner)
        record
      end

      protected
        def reset_target!
          @target = Array.new
        end

        def construct_query
          clauses = {@reflection.options[:property] => @owner.internal_uri}
          clauses[:has_model] = @reflection.class_name.constantize.to_class_uri if @reflection.class_name && @reflection.class_name != 'ActiveFedora::Base'
          @counter_query = @finder_query = ActiveFedora::SolrService.construct_query_for_rel(clauses)
        end


      private 
        def create_record(attrs)
          attrs.update(@reflection.options[:conditions]) if @reflection.options[:conditions].is_a?(Hash)
          ensure_owner_is_not_new
          record = @reflection.klass.create do
            @reflection.build_association(attrs)
          end
          set_belongs_to_association_for(record)
          if block_given?
            add_record_to_target_with_callbacks(record) { |*block_args| yield(*block_args) }
          else
            add_record_to_target_with_callbacks(record)
          end
        end

        def build_record(attrs)
          #attrs.update(@reflection.options[:conditions]) if @reflection.options[:conditions].is_a?(Hash)
          record = @reflection.build_association(attrs)
          if block_given?
            add_record_to_target_with_callbacks(record) { |*block_args| yield(*block_args) }
          else
            add_record_to_target_with_callbacks(record)
          end
        end

        def remove_records(*records)
          records = flatten_deeper(records)
          records.each { |record| raise_on_type_mismatch(record) }

          #records.each { |record| callback(:before_remove, record) }
          old_records = records.reject { |r| r.new_record? }
          yield(records, old_records)
          #records.each { |record| callback(:after_remove, record) }
        end

        def ensure_owner_is_not_new
          if @owner.new_record?
            raise ActiveFedora::RecordNotSaved, "You cannot call create unless the parent is saved"
          end
        end
      
    end
  end
end
