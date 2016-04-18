require 'rsolr'
require 'deprecation'

module ActiveFedora
  class SolrService
    extend Deprecation

    attr_writer :conn

    def initialize(options = {})
      @options = { read_timeout: 120, open_timeout: 120, url: 'http://localhost:8080/solr' }.merge(options)
    end

    def conn
      @conn ||= RSolr.connect @options
    end

    class << self
      def register(*args)
        options = args.extract_options!

        if args.length == 1
          Deprecation.warn(SolrService, "SolrService.register with a host argument is deprecated. Use `SolrService.register(url: host)` instead. This will be removed in active-fedora 10.0")

          host = args.first
          options[:url] = host if host
        elsif args.length > 1
          raise ArgumentError, "wrong number of arguments (#{args.length} for 0..2)"
        end

        ActiveFedora::RuntimeRegistry.solr_service = new(options)
      end

      def reset!
        ActiveFedora::RuntimeRegistry.solr_service = nil
      end

      def select_path
        ActiveFedora.solr_config.fetch(:select_path, 'select')
      end

      def instance
        # Register Solr

        unless ActiveFedora::RuntimeRegistry.solr_service
          register(ActiveFedora.solr_config)
        end

        raise SolrNotInitialized unless ActiveFedora::RuntimeRegistry.solr_service

        ActiveFedora::RuntimeRegistry.solr_service
      end

      def lazy_reify_solr_results(solr_results, opts = {})
        Deprecation.warn SolrService, "SolrService.lazy_reify_solr_results is deprecated. Use QueryResultBuilder.lazy_reify_solr_results instead. This will be removed in active-fedora 10.0"
        QueryResultBuilder.lazy_reify_solr_results(solr_results, opts)
      end

      def reify_solr_results(solr_results, opts = {})
        Deprecation.warn SolrService, "SolrService.reify_solr_results is deprecated. Use QueryResultBuilder.reify_solr_results instead. This will be removed in active-fedora 10.0"
        QueryResultBuilder.reify_solr_results(solr_results, opts)
      end

      def reify_solr_result(hit, opts = {})
        Deprecation.warn SolrService, "SolrService.reify_solr_result is deprecated. Use SolrHit#reify instead. This will be removed in active-fedora 10.0"
        QueryResultBuilder.reify_solr_result(hit, opts)
      end

      # Returns all possible classes for the solr object
      def classes_from_solr_document(hit, opts = {})
        Deprecation.warn SolrService, "SolrService.classes_from_solr_document is deprecated. Use SolrHit#models instead. This will be removed in active-fedora 10.0"
        QueryResultBuilder.classes_from_solr_document(hit, opts)
      end

      # Returns the best singular class for the solr object
      def class_from_solr_document(hit, opts = {})
        Deprecation.warn SolrService, "SolrService.class_from_solr_document is deprecated. Use SolrHit#model instead. This will be removed in active-fedora 10.0"
        QueryResultBuilder.class_from_solr_document(hit, opts)
      end

      # Construct a solr query for a list of ids
      # This is used to get a solr response based on the list of ids in an object's RELS-EXT relationhsips
      # If the id_array is empty, defaults to a query of "id:NEVER_USE_THIS_ID", which will return an empty solr response
      # @param [Array] id_array the ids that you want included in the query
      def construct_query_for_ids(id_array)
        Deprecation.warn SolrService, "SolrService.construct_query_for_ids is deprecated. Use SolrQueryBuilder.construct_query_for_ids instead. This will be removed in active-fedora 10.0"
        SolrQueryBuilder.construct_query_for_ids(id_array)
      end

      def construct_query_for_pids(id_array)
        Deprecation.warn SolrService, "SolrService.construct_query_for_pids is deprecated. Use SolrQueryBuilder.construct_query_for_ids instead. This will be removed in active-fedora 10.0"
        SolrQueryBuilder.construct_query_for_ids(id_array)
      end

      # Create a raw query clause suitable for sending to solr as an fq element
      # @param [String] key
      # @param [String] value
      def raw_query(key, value)
        Deprecation.warn SolrService, "SolrService.raw_query is deprecated. Use SolrQueryBuilder.construct_query instead. This will be removed in active-fedora 10.0"
        SolrQueryBuilder.construct_query(key, value)
      end

      def solr_name(*args)
        Deprecation.warn SolrService, "SolrService.solr_name is deprecated. Use SolrQueryBuilder.solr_name instead. This will be removed in active-fedora 10.0"
        SolrQueryBuilder.solr_name(*args)
      end

      # Create a query with a clause for each key, value
      # @param [Hash, Array<Array<String>>] field_pairs key is the predicate, value is the target_uri
      # @param [String] join_with ('AND') the value we're joining the clauses with
      # @example
      #   construct_query_for_rel [[:has_model, "info:fedora/afmodel:ComplexCollection"], [:has_model, "info:fedora/afmodel:ActiveFedora_Base"]], 'OR'
      #   # => _query_:"{!field f=has_model_ssim}info:fedora/afmodel:ComplexCollection" OR _query_:"{!field f=has_model_ssim}info:fedora/afmodel:ActiveFedora_Base"
      #
      #   construct_query_for_rel [[Book._reflect_on_association(:library), "foo/bar/baz"]]
      def construct_query_for_rel(field_pairs, join_with = 'AND')
        Deprecation.warn SolrService, "SolrService.construct_query_for_rel is deprecated. Use SolrQueryBuilder.construct_query_for_rel instead. This will be removed in active-fedora 10.0"
        SolrQueryBuilder.construct_query_for_rel(field_pairs, join_with)
      end

      def get(query, args = {})
        args = args.merge(q: query, qt: 'standard')
        SolrService.instance.conn.get(select_path, params: args)
      end

      def query(query, args = {})
        raw = args.delete(:raw)
        result = get(query, args)

        if raw
          Deprecation.warn SolrService, "SolrService.query with raw: true is deprecated. Use SolrService.get instead. This will be removed in active-fedora 10.0"
          return result
        end

        result['response']['docs'].map do |doc|
          ActiveFedora::SolrHit.new(doc)
        end
      end

      def delete(id)
        SolrService.instance.conn.delete_by_id(id, params: { 'softCommit' => true })
      end

      # Get the count of records that match the query
      # @param [String] query a solr query
      # @param [Hash] args arguments to pass through to `args' param of SolrService.query (note that :rows will be overwritten to 0)
      # @return [Integer] number of records matching
      def count(query, args = {})
        args = args.merge(rows: 0)
        SolrService.get(query, args)['response']['numFound'].to_i
      end

      # @param [Hash] doc the document to index
      # @param [Hash] params
      #   :commit => commits immediately
      #   :softCommit => commit to memory, but don't flush to disk
      def add(doc, params = {})
        SolrService.instance.conn.add(doc, params: params)
      end

      def commit
        SolrService.instance.conn.commit
      end
    end
  end # SolrService
  class SolrNotInitialized < StandardError; end
end # ActiveFedora
