module ActiveFedora
  module Associations
    class Rdf < SingularAssociation #:nodoc:

      def replace(values)
        raise "can't modify frozen #{owner.class}" if owner.frozen?
        destroy
        values.each do |value|
          uri = ActiveFedora::Base.id_to_uri(value)
          owner.resource.insert [owner.rdf_subject, reflection.predicate, RDF::URI.new(uri)]
        end
        owner.send(:attribute_will_change!, reflection.name)
      end

      def reader
        filtered_results.map { |val| ActiveFedora::Base.uri_to_id(val) }
      end

      def destroy
        filtered_results.each do |candidate|
          owner.resource.delete([owner.rdf_subject, reflection.predicate, candidate])
        end
      end

      private

      # @return [Array<RDF::URI>] the rdf results filtered to objects that match the specified class_name consraint
      def filtered_results
        if filtering_required?
          filter_by_class(rdf_uris)
        else
          rdf_uris
        end
      end

      # TODO Detect when this is the only relationship for this predicate, then skip the filtering.
      def filtering_required?
        reflection.klass != ActiveFedora::Base
      end

      # @return [Array<RDF::URI>]
      def rdf_uris
        rdf_query.map(&:object)
      end

      # @return [Array<RDF::Statement>]
      def rdf_query
        owner.resource.query(subject: owner.rdf_subject, predicate: reflection.predicate).enum_statement
      end


      # TODO this is a huge waste of time that can be completely avoided if the attributes aren't sharing predicates.
      # @return [Array<RDF::URI>]
      def filter_by_class(candidate_uris)
        return [] if candidate_uris.empty?
        ids = candidate_uris.map {|uri| ActiveFedora::Base.uri_to_id(uri) }
        results = ActiveFedora::SolrService.query(ActiveFedora::SolrService.construct_query_for_pids(ids), rows: 10000)

        docs = results.select do |result|
          ActiveFedora::SolrService.classes_from_solr_document(result).any? { |klass|
            class_ancestors(klass).include? reflection.klass
          }
        end

        docs.map {|doc| RDF::URI.new(ActiveFedora::Base.id_to_uri(doc['id']))}
      end

      ##
      # Returns a list of all the ancestor classes up to ActiveFedora::Base including the class itself
      # @param [Class] klass
      # @return [Array<Class>]
      # @example
      #   class Car < ActiveFedora::Base; end
      #   class SuperCar < Car; end
      #   class_ancestors(SuperCar)
      #   # => [SuperCar, Car, ActiveFedora::Base]
      def class_ancestors(klass)
        klass.ancestors.select {|k| k.instance_of?(Class) } - [Object, BasicObject]
      end



    end
  end
end
