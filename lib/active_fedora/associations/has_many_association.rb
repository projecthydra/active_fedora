module ActiveFedora
  module Associations
    class HasManyAssociation < CollectionAssociation #:nodoc:
      def initialize(owner, reflection)
        super
      end

      # Returns the number of records in this collection.
      #
      # That does not depend on whether the collection has already been loaded
      # or not. The +size+ method is the one that takes the loaded flag into
      # account and delegates to +count_records+ if needed.
      #
      # If the collection is empty the target is set to an empty array and
      # the loaded flag is set to true as well.
      def count_records
        count = if loaded? 
          @target.size
        else
          @reflection.klass.count(:conditions => @counter_query)
          # load_target
          # @target.size
        end

        # If there's nothing in the database and @target has no new records
        # we are certain the current target is an empty array. This is a
        # documented side-effect of the method that may avoid an extra SELECT.
        @target ||= [] and loaded if count == 0

        return count
      end

      def insert_record(record, force = false, validate = true)
        set_belongs_to_association_for(record)
        record.save
      end

      protected

        # Deletes the records according to the <tt>:dependent</tt> option.
        def delete_records(records)
          records.each do |r| 
            r.remove_relationship(find_predicate, @owner)
          end
        end

        
    end
  end
end
