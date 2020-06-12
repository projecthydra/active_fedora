require 'active_support/core_ext/module/attribute_accessors_per_thread'

module ActiveFedora
  class RuntimeRegistry
    thread_mattr_accessor :solr_service, :fedora_connection
  end
end
