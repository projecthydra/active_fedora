module ActiveFedora
  module Associations
    class BelongsToAssociation < SingularAssociation #:nodoc:

      def replace(record)
        raise_on_type_mismatch(record) if record

        replace_keys(record)

        @updated = true if record

        self.target = record
      end

      def reset
        super
        @updated = false
      end

      def updated?
        @updated
      end

      private

        def replace_keys(record)
          if record
            owner[reflection.foreign_key] = record.id # TODO change to url here (primary_key)
          else
            owner[reflection.foreign_key] = nil
          end
        end

        # Constructs a query that checks solr for the correct id & class_name combination
        def construct_query(ids)
          # Some descendants of ActiveFedora::Base are anonymous classes. They don't have names. Filter them out.
          candidate_classes = klass.descendants.select {|d| d.name }
          candidate_classes += [klass] unless klass == ActiveFedora::Base
          model_pairs = candidate_classes.inject([]) { |arr, klass| arr << [:has_model, klass.to_class_uri]; arr }
          '(' + ActiveFedora::SolrService.construct_query_for_pids(ids) + ') AND (' +
              ActiveFedora::SolrService.construct_query_for_rel(model_pairs, 'OR') + ')'
        end

        def remove_matching_property_relationship
          # puts "Results: #{@owner.graph.query([@owner.uri,  predicate, nil])}"
          ids = @owner.send :"#{@reflection.name}_id"
          # ids = @owner.ids_for_outbound(@reflection.options[:property])
          # puts "new #{new_ids.inspect} vs old #{ids.inspect}"
          ids.each do |id|
            result = SolrService.query(ActiveFedora::SolrService.construct_query_for_pids([id]))
            hit = ActiveFedora::SolrService.reify_solr_results(result).first
            # We remove_relationship on subjects that match the same class, or if the subject is nil 
            if hit.class == klass || hit.nil?
              @owner.remove_relationship(@reflection.options[:property], hit)
            end
          end
        end

        def foreign_key_present?
          owner[reflection.foreign_key]
        end

        def stale_state
          owner[reflection.foreign_key]
        end
    end
  end
end
