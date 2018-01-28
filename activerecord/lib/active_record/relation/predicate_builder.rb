# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder # :nodoc:
    delegate :resolve_column_aliases, to: :table

    def initialize(table)
      @table = table
      @handlers = []

      register_handler(BasicObject, BasicObjectHandler.new(self))
      register_handler(Base, BaseHandler.new(self))
      register_handler(Range, RangeHandler.new(self))
      register_handler(Relation, RelationHandler.new)
      register_handler(Array, ArrayHandler.new(self))
      register_handler(Set, ArrayHandler.new(self))
    end

    def build_from_hash(attributes)
      return ["1=0"] if attributes.empty?

      attributes.flat_map do |key, value|
        build_from_key_value(key, value)
      end
    end

    # Define how a class is converted to Arel nodes when passed to +where+.
    # The handler can be any object that responds to +call+, and will be used
    # for any value that +===+ the class given. For example:
    #
    #     MyCustomDateRange = Struct.new(:start, :end)
    #     handler = proc do |column, range|
    #       Arel::Nodes::Between.new(column,
    #         Arel::Nodes::And.new([range.start, range.end])
    #       )
    #     end
    #     ActiveRecord::PredicateBuilder.new("users").register_handler(MyCustomDateRange, handler)
    def register_handler(klass, handler)
      @handlers.unshift([klass, handler])
    end

    def build(attribute, value)
      handler_for(value).call(attribute, value)
    end

    def build_bind_attribute(column_name, value)
      attr = Relation::QueryAttribute.new(column_name.to_s, value, table.type(column_name))
      Arel::Nodes::BindParam.new(attr)
    end

    def build_comparison(column_name, value, comparison_method)
      bind = build_bind_attribute(column_name, value)
      table.arel_attribute(column_name).send(comparison_method, bind)
    end

    def associated_predicate_builder(association_name)
      self.class.new(table.associated_table(association_name))
    end

    protected

      attr_reader :table

    private

      def build_from_key_value(key, value)
        if value.is_a?(Hash) && !table.has_column?(key)
          associated_predicate_builder(key).build_from_hash(value)
        elsif table.associated_with?(key)
          # Find the foreign key when using queries such as:
          # Post.where(author: author)
          #
          # For polymorphic relationships, find the foreign key and type:
          # PriceEstimate.where(estimate_of: treasure)
          associated_table = table.associated_table(key)
          if associated_table.polymorphic_association?
            case value.is_a?(Array) ? value.first : value
            when Base, Relation
              value = [value] unless value.is_a?(Array)
              klass = PolymorphicArrayValue
            end
          end

          klass ||= AssociationQueryValue
          queries = klass.new(associated_table, value).queries.map do |query|
            build_from_hash(query).reduce(&:and)
          end
          queries.reduce(&:or)
        # FIXME: Deprecate this and provide a public API to force equality
        elsif (value.is_a?(Range) || value.is_a?(Array)) &&
          table.type(key.to_s).respond_to?(:subtype)
          BasicObjectHandler.new(self).call(table.arel_attribute(key), value)
        else
          build(table.arel_attribute(key), value)
        end
      end

      def handler_for(object)
        @handlers.detect { |klass, _| klass === object }.last
      end
  end
end

require "active_record/relation/predicate_builder/array_handler"
require "active_record/relation/predicate_builder/base_handler"
require "active_record/relation/predicate_builder/basic_object_handler"
require "active_record/relation/predicate_builder/range_handler"
require "active_record/relation/predicate_builder/relation_handler"

require "active_record/relation/predicate_builder/association_query_value"
require "active_record/relation/predicate_builder/polymorphic_array_value"
