module ActiveFedora
  module AttributeMethods
    module Read
      ReaderMethodCache = Class.new(AttributeMethodCache) {
        private
        # We want to generate the methods via module_eval rather than
        # define_method, because define_method is slower on dispatch.
        # Evaluating many similar methods may use more memory as the instruction
        # sequences are duplicated and cached (in MRI).  define_method may
        # be slower on dispatch, but if you're careful about the closure
        # created, then define_method will consume much less memory.
        #
        # But sometimes the database might return columns with
        # characters that are not allowed in normal method names (like
        # 'my_column(omg)'. So to work around this we first define with
        # the __temp__ identifier, and then use alias method to rename
        # it to what we want.
        #
        # We are also defining a constant to hold the frozen string of
        # the attribute name. Using a constant means that we do not have
        # to allocate an object on each call to the attribute method.
        # Making it frozen means that it doesn't get duped when used to
        # key the @attributes_cache in read_attribute.
        def method_body(method_name, const_name)
          <<-EOMETHOD
          def #{method_name}
            name = ::ActiveFedora::AttributeMethods::AttrNames::ATTR_#{const_name}
            read_attribute(name) { |n| missing_attribute(n, caller) }
          end
          EOMETHOD
        end
      }.new

      extend ActiveSupport::Concern

      # Returns the value of the attribute identified by <tt>attr_name</tt> after
      # it has been typecast (for example, "2004-12-12" in a date column is cast
      # to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name)
        name = attr_name.to_s
        @attributes.fetch(name, nil)
      end

      private
        def attribute(attribute_name)
          read_attribute(attribute_name)
        end


      module ClassMethods
        # Copied from ActiveRecord.  This workaround should not be required
        # after ruby 1.9 support is ended.
        if Module.methods_transplantable?
          def define_method_attribute(name)
            method = ReaderMethodCache[name.to_s]
            generated_attribute_methods.module_eval {
              define_method name, method
            }
          end
        else
          def define_method_attribute(name)
            safe_name = name.unpack('h*').first
            temp_method = "__temp__#{safe_name}"

            ActiveFedora::AttributeMethods::AttrNames.set_name_cache safe_name, name

            generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
              def #{temp_method}
                name = ::ActiveFedora::AttributeMethods::AttrNames::ATTR_#{safe_name}
                read_attribute(name) { |n| missing_attribute(n, caller) }
              end
            STR

            generated_attribute_methods.module_eval do
              alias_method name, temp_method
              undef_method temp_method
            end
          end
        end


      end
    end
  end
end
