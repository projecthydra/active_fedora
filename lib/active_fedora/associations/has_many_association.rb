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
        end

        # If there's nothing in the database and @target has no new records
        # we are certain the current target is an empty array. This is a
        # documented side-effect of the method that may avoid an extra SELECT.
        @target ||= [] and loaded! if count == 0

        return count
      end

      def set_owner_attributes(record)
        if klass == ActiveFedora::Base
          # This is a polymorphic case.  Find a reflection that matches by property
          inverse = record.reflections.values.find{ |r| r.options[:property] == :is_part_of}
          if inverse.belongs_to?
            record[inverse.foreign_key] = owner.id
          else # HABTM
            record[inverse.foreign_key] ||= []
            #TODO use primary_key instead of `owner.id`
            record[inverse.foreign_key] << owner.id
          end
        else
          #TODO use primary_key instead of `owner.id`
          record[reflection.foreign_key] = owner.id
        end
      end

      def insert_record(record, validate = true, raise = false)
        set_owner_attributes(record)

        if raise
          record.save!(:validate => validate)
        else
          record.save(:validate => validate)
        end
      end

      protected

        # Deletes the records according to the <tt>:dependent</tt> option.
        def delete_records(records, method)
          if method == :destroy
            records.each { |r| r.destroy }
            #update_counter(-records.length) unless inverse_updates_counter_cache?
          else
            # Find all the records that point to this and nullify them
            # keys  = records.map { |r| r[reflection.association_primary_key] }
            # scope = scoped.where(reflection.association_primary_key => keys)

            if method == :delete_all
              raise "Not Implemented"
              #update_counter(-scope.delete_all)
            else

              if reflection.inverse_of # Can't get an inverse when class_name: 'ActiveFedora::Base' is supplied
                inverse = reflection.inverse_of.name
                records.each do |record|
                  if record.persisted?
                    assoc = record.association(inverse)
                    if assoc.reflection.collection?
                      # Remove from a has_and_belongs_to_many
                      record.association(inverse).delete(@owner)
                    else
                      # Remove from a belongs_to
                      record[reflection.foreign_key] = nil
                    end
                    # Check to see if the object still exists (may be already deleted).
                    # In Rails, they do this with an update_all to avoid callbacks and validations, we may need the same.
                    record.save! if record.class.exists?(record.pid)
                  end
                end
              end

              #update_counter(-scope.update_all(reflection.foreign_key => nil))
            end
          end
        end

        
    end
  end
end
