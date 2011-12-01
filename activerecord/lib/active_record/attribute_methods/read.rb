module ActiveRecord
  module AttributeMethods
    module Read
      extend ActiveSupport::Concern

      ATTRIBUTE_TYPES_CACHED_BY_DEFAULT = [:datetime, :timestamp, :time, :date]

      included do
        cattr_accessor :attribute_types_cached_by_default, :instance_writer => false
        self.attribute_types_cached_by_default = ATTRIBUTE_TYPES_CACHED_BY_DEFAULT
      end

      module ClassMethods
        # +cache_attributes+ allows you to declare which converted attribute values should
        # be cached. Usually caching only pays off for attributes with expensive conversion
        # methods, like time related columns (e.g. +created_at+, +updated_at+).
        def cache_attributes(*attribute_names)
          cached_attributes.merge attribute_names.map { |attr| attr.to_s }
        end

        # Returns the attributes which are cached. By default time related columns
        # with datatype <tt>:datetime, :timestamp, :time, :date</tt> are cached.
        def cached_attributes
          @cached_attributes ||= columns.select { |c| cacheable_column?(c) }.map { |col| col.name }.to_set
        end

        # Returns +true+ if the provided attribute is being cached.
        def cache_attribute?(attr_name)
          cached_attributes.include?(attr_name)
        end

        def undefine_attribute_methods
          if base_class == self
            generated_attribute_methods.module_eval do
              public_methods(false).each do |m|
                singleton_class.send(:undef_method, m) if m.to_s =~ /^attribute_/
              end
            end
          end

          super
        end

        protected
          # Where possible, generate the method by evalling a string, as this will result in
          # faster accesses because it avoids the block eval and then string eval incurred
          # by the second branch.
          #
          # The second, slower, branch is necessary to support instances where the database
          # returns columns with extra stuff in (like 'my_column(omg)').
          def define_method_attribute(attr_name)
            cast_code = attribute_cast_code(attr_name)
            internal  = internal_attribute_access_code(attr_name, cast_code)
            external  = external_attribute_access_code(attr_name, cast_code)

            if attr_name =~ ActiveModel::AttributeMethods::NAME_COMPILABLE_REGEXP
              generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__
                def #{attr_name}
                  #{internal}
                end

                def self.attribute_#{attr_name}(v, attributes, attributes_cache, attr_name)
                  #{external}
                end
              STR
            else
              generated_attribute_methods.module_eval do
                define_method(attr_name) do
                  eval(internal)
                end

                singleton_class.send(:define_method, "attribute_#{attr_name}") do |v, attributes, attributes_cache, attr_name|
                  eval(external)
                end
              end
            end
          end

        private
          def cacheable_column?(column)
            attribute_types_cached_by_default.include?(column.type)
          end

          def internal_attribute_access_code(attr_name, cast_code)
            access_code = "(v=@attributes['#{attr_name}']) && #{cast_code}"

            unless attr_name == primary_key
              access_code.insert(0, "missing_attribute('#{attr_name}', caller) unless @attributes.has_key?('#{attr_name}'); ")
            end

            if cache_attribute?(attr_name)
              access_code = "@attributes_cache['#{attr_name}'] ||= (#{access_code})"
            end

            access_code
          end

          def external_attribute_access_code(attr_name, cast_code)
            access_code = "v && #{cast_code}"

            if cache_attribute?(attr_name)
              access_code = "attributes_cache[attr_name] ||= (#{access_code})"
            end

            access_code
          end

          def attribute_cast_code(attr_name)
            columns_hash[attr_name].type_cast_code('v')
          end
      end

      # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
      # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name)
        attr_name = attr_name.to_s
        accessor  = "attribute_#{attr_name}"
        methods   = self.class.generated_attribute_methods

        if methods.respond_to?(accessor)
          if @attributes.has_key?(attr_name) || attr_name == 'id'
            methods.send(accessor, @attributes[attr_name], @attributes, @attributes_cache, attr_name)
          end
        elsif !self.class.attribute_methods_generated?
          # If we haven't generated the caster methods yet, do that and
          # then try again
          self.class.define_attribute_methods
          read_attribute(attr_name)
        else
          # If we get here, the attribute has no associated DB column, so
          # just return it verbatim.
          @attributes[attr_name]
        end
      end

      private
        def attribute(attribute_name)
          read_attribute(attribute_name)
        end
    end
  end
end
