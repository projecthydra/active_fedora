require "loggable"
require 'active_support'
require "solrizer"
require 'active_fedora/file_configurator'
require 'active_fedora/rubydora_connection'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/object'
require 'active_support/core_ext/hash/indifferent_access'
require 'rdf'

SOLR_DOCUMENT_ID = Solrizer.default_field_mapper.id_field unless defined?(SOLR_DOCUMENT_ID)
ENABLE_SOLR_UPDATES = true unless defined?(ENABLE_SOLR_UPDATES)

module ActiveFedora #:nodoc:
  extend ActiveSupport::Autoload

  class ObjectNotFoundError < RuntimeError; end # :nodoc:
  class PredicateMappingsNotFoundError < RuntimeError; end # :nodoc:
  class UnknownAttributeError < NoMethodError; end; # :nodoc:
  class ConfigurationError < RuntimeError; end # :nodoc:
  class AssociationTypeMismatch < RuntimeError; end # :nodoc:
  class UnregisteredPredicateError < RuntimeError; end # :nodoc:
  class RecordNotSaved < RuntimeError; end # :nodoc:


  eager_autoload do
    autoload :Associations
    autoload :Attributes
    autoload :Base
    autoload :ContentModel
    autoload :Callbacks
    autoload :Config
    autoload :Datastream
    autoload :DatastreamHash
    autoload :Datastreams
    autoload :Delegating
    autoload :DigitalObject
    autoload :FileConfigurator
    autoload :Indexing
    autoload :Model
    autoload :NestedAttributes
    autoload :NokogiriDatastream
    autoload :NomDatastream
    autoload :NtriplesRDFDatastream
    autoload :OmDatastream
    autoload :Property
    autoload :Persistence
    autoload :QualifiedDublinCoreDatastream
    autoload :Querying
    autoload :RDFDatastream
    autoload :RdfList
    autoload :RdfNode
    autoload :RdfObject
    autoload :RdfxmlRDFDatastream
    autoload :Reflection
    autoload :Relation
    autoload :RelationshipGraph
    autoload :RelsExtDatastream
    autoload :ServiceDefinitions
    autoload :SemanticNode
    autoload :SimpleDatastream
    autoload :SolrDigitalObject
    autoload :SolrService
    autoload :UnsavedDigitalObject
    autoload :FixtureLoader
    autoload :FixtureExporter
    autoload :DatastreamCollections
    autoload :Predicates
    autoload :Validations
    autoload :SolrInstanceLoader
  end
  
  
  include Loggable
  
  class << self
    attr_reader :fedora_config, :solr_config, :config_options
    attr_accessor :configurator
  end
  self.configurator ||= ActiveFedora::FileConfigurator.new
  
  def self.fedora_config
    @fedora_config ||= Config.new(configurator.fedora_config)
  end
  def self.solr_config;    self.configurator.solr_config;    end
  def self.config_options; self.configurator.config_options; end
  def self.config_loaded?; self.configurator.config_loaded?; end
  
  def self.init( options={} )
    # Make config_options into a Hash if nil is passed in as the value
    options = {} if options.nil?
    # For backwards compatibility, handle cases where config_path (a String) is passed in as the argument rather than a config_options hash
    # In all other cases, set config_path to config_options[:config_path], which is ok if it's nil
    if options.is_a? String
      raise ArgumentError, "Calling ActiveFedora.init with a path as an argument has been removed.  Use ActiveFedora.init(:fedora_config_path=>#{options})"
    end
    @fedora_config = nil
    SolrService.reset!
    Predicates.predicate_config = nil
    self.configurator.init(options)
  end

  def self.config
    self.fedora_config
  end

  # Determine what environment we're running in. Order of preference is:
  # 1. config_options[:environment]
  # 2. Rails.env
  # 3. ENV['environment']
  # 4. ENV['RAILS_ENV']
  # 5. development
  # @return [String]
  # @example 
  #  ActiveFedora.init(:environment=>"test")
  #  ActiveFedora.environment => "test"
  def self.environment
    if config_options.fetch(:environment,nil)
      return config_options[:environment]
    elsif defined?(Rails.env) and !Rails.env.nil?
      return Rails.env.to_s
    elsif defined?(ENV['environment']) and !(ENV['environment'].nil?)
      return ENV['environment']
    elsif defined?(ENV['RAILS_ENV']) and !(ENV['RAILS_ENV'].nil?)
      raise RuntimeError, "You're depending on RAILS_ENV for setting your environment. Please use ENV['environment'] for non-rails environment setting: 'rake foo:bar environment=test'"
    else
      ENV['environment'] = 'development' 
    end
  end
  
  def self.solr
    ActiveFedora::SolrService.instance
  end
  
  def self.predicate_config
    configurator.predicate_config
  end
  
  def self.root
    File.expand_path('../..', __FILE__)
  end
  
  def self.version
    ActiveFedora::VERSION
  end

end


load File.join(File.dirname(__FILE__),"tasks/active_fedora.rake") if defined?(Rake)
I18n.load_path << File.dirname(__FILE__) + '/active_fedora/locale/en.yml'

require 'active_fedora/railtie' if defined?(Rails)
