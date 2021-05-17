module ActiveFedora
  module Delegation # :nodoc:
    extend ActiveSupport::Concern

    # This module creates compiled delegation methods dynamically at runtime, which makes
    # subsequent calls to that method faster by avoiding method_missing. The delegations
    # may vary depending on the klass of a relation, so we create a subclass of Relation
    # for each different klass, and the delegations are compiled into that subclass only.

    NON_DELEGABLE_ARRAY_METHODS = [
      :compact!, :flatten!, :reject!, :reverse!, :rotate!, :map!,
      :shuffle!, :slice!, :sort!, :sort_by!, :delete_if,
      :keep_if, :pop, :shift, :delete_at, :select!
    ].to_set

    delegate :length, :map, :to_ary, to: :to_a
    delegate :any?, :all?, :collect, :include?, to: :each

    protected

      def array_delegable?(method)
        Array.method_defined?(method) && NON_DELEGABLE_ARRAY_METHODS.exclude?(method)
      end

      def method_missing(method, *args, &block)
        if array_delegable?(method)
          self.class.delegate method, to: :to_a
          to_a.public_send(method, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method, *args)
        array_delegable?(method) || super
      end
  end
end
