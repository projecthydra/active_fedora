ENV["environment"] ||= 'test'
require "bundler/setup"

require 'simplecov'
require 'coveralls'

SimpleCov.start do
  add_filter "/spec/"
end

require 'active-fedora'
require 'rspec'
require 'rspec/its'
require 'equivalent-xml/rspec_matchers'
require 'logger'
require 'pry-byebug' unless ENV['CI']

ActiveFedora::Base.logger = Logger.new(STDERR)
ActiveFedora::Base.logger.level = Logger::WARN
# require 'http_logger'
# HttpLogger.logger = Logger.new(STDOUT)
# HttpLogger.ignore = [/localhost:8983\/solr/]
# HttpLogger.colorize = false
# HttpLogger.log_headers = true

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |f| require f }

$VERBOSE = nil

# This loads the Fedora and Solr config info from /config/fedora.yml
# You can load it from a different location by passing a file path as an argument.
def restore_spec_configuration
  ActiveFedora.init(fedora_config_path: File.join(File.dirname(__FILE__), "..", "config", "fedora.yml"))
end
restore_spec_configuration

require 'active_fedora/cleaner'
RSpec.configure do |config|
  config.before(:suite) do
    ActiveFedora::RDFDatastream.deprecation_behavior = :silence
    ActiveFedora::NtriplesRDFDatastream.deprecation_behavior = :silence
    ActiveFedora::OmDatastream.deprecation_behavior = :silence
    ActiveFedora::NomDatastream.deprecation_behavior = :silence
  end
  # Stub out test stuff.
  config.before(:each) do
    begin
      ActiveFedora::Cleaner.clean!
    rescue Faraday::ConnectionFailed, RSolr::Error::ConnectionRefused => e
      $stderr.puts e.message
    end
  end
  config.after(:each) do
    # cleanout_fedora
  end
  config.order = :random if ENV['CI']
end

def fixture(file)
  File.open(File.join(File.dirname(__FILE__), 'fixtures', file), 'rb')
end
