# frozen_string_literal: true

require "active_support/time"

module Rails
  module Generators
    class GeneratedAttribute # :nodoc:
      INDEX_OPTIONS = %w(index uniq)
      UNIQ_INDEX_OPTIONS = %w(uniq)
      DEFAULT_TYPES = %w(
        attachment
        attachments
        belongs_to
        boolean
        date
        datetime
        decimal
        digest
        float
        integer
        references
        rich_text
        string
        text
        time
        timestamp
        token
      )

      attr_accessor :name, :type
      attr_reader   :attr_options
      attr_writer   :index_name

      class << self
        def parse(column_definition)
          name, type, index_type = column_definition.split(":")

          # if user provided "name:index" instead of "name:string:index"
          # type should be set blank so GeneratedAttribute's constructor
          # could set it to :string
          index_type, type = type, nil if valid_index_type?(type)

          type, attr_options = *parse_type_and_options(type)
          type = type.to_sym if type

          if type && !valid_type?(type)
            raise Error, "Could not generate field '#{name}' with unknown type '#{type}'."
          end

          if index_type && !valid_index_type?(index_type)
            raise Error, "Could not generate field '#{name}' with unknown index '#{index_type}'."
          end

          if type && reference?(type)
            if UNIQ_INDEX_OPTIONS.include?(index_type)
              attr_options[:index] = { unique: true }
            end
          end

          new(name, type, index_type, attr_options)
        end

        def valid_type?(type)
          DEFAULT_TYPES.include?(type.to_s) ||
            ActiveRecord::Base.connection.valid_type?(type)
        end

        def valid_index_type?(index_type)
          INDEX_OPTIONS.include?(index_type.to_s)
        end

        def reference?(type)
          [:references, :belongs_to].include? type
        end

        private
          # parse possible attribute options like :limit for string/text/binary/integer, :precision/:scale for decimals or :polymorphic for references/belongs_to
          # when declaring options curly brackets should be used
          def parse_type_and_options(type)
            case type
            when /(string|text|binary|integer)\{(\d+)\}/
              return $1, limit: $2.to_i
            when /decimal\{(\d+)[,.-](\d+)\}/
              return :decimal, precision: $1.to_i, scale: $2.to_i
            when /(references|belongs_to)\{(.+)\}/
              type = $1
              provided_options = $2.split(/[,.-]/)
              options = Hash[provided_options.map { |opt| [opt.to_sym, true] }]

              return type, options
            else
              return type, {}
            end
          end
      end

      def initialize(name, type = nil, index_type = false, attr_options = {})
        @name           = name
        @type           = type || :string
        @has_index      = INDEX_OPTIONS.include?(index_type)
        @has_uniq_index = UNIQ_INDEX_OPTIONS.include?(index_type)
        @attr_options   = attr_options
      end

      def field_type
        @field_type ||= case type
                        when :integer                  then :number_field
                        when :float, :decimal          then :text_field
                        when :time                     then :time_field
                        when :datetime, :timestamp     then :datetime_field
                        when :date                     then :date_field
                        when :text                     then :text_area
                        when :rich_text                then :rich_text_area
                        when :boolean                  then :check_box
                        when :attachment, :attachments then :file_field
                        else
                          :text_field
        end
      end

      def default
        @default ||= case type
                     when :integer                     then 1
                     when :float                       then 1.5
                     when :decimal                     then "9.99"
                     when :datetime, :timestamp, :time then Time.now.to_s(:db)
                     when :date                        then Date.today.to_s(:db)
                     when :string                      then name == "type" ? "" : "MyString"
                     when :text                        then "MyText"
                     when :boolean                     then false
                     when :references, :belongs_to,
                          :attachment, :attachments,
                          :rich_text                   then nil
                     else
                       ""
        end
      end

      def plural_name
        name.delete_suffix("_id").pluralize
      end

      def singular_name
        name.delete_suffix("_id").singularize
      end

      def human_name
        name.humanize
      end

      def index_name
        @index_name ||= if polymorphic?
          %w(id type).map { |t| "#{name}_#{t}" }
        else
          column_name
        end
      end

      def column_name
        @column_name ||= reference? ? "#{name}_id" : name
      end

      def foreign_key?
        name.end_with?("_id")
      end

      def reference?
        self.class.reference?(type)
      end

      def polymorphic?
        attr_options[:polymorphic]
      end

      def required?
        reference? && Rails.application.config.active_record.belongs_to_required_by_default
      end

      def has_index?
        @has_index
      end

      def has_uniq_index?
        @has_uniq_index
      end

      def password_digest?
        name == "password" && type == :digest
      end

      def token?
        type == :token
      end

      def rich_text?
        type == :rich_text
      end

      def attachment?
        type == :attachment
      end

      def attachments?
        type == :attachments
      end

      def virtual?
        rich_text? || attachment? || attachments?
      end

      def inject_options
        (+"").tap { |s| options_for_migration.each { |k, v| s << ", #{k}: #{v.inspect}" } }
      end

      def inject_index_options
        has_uniq_index? ? ", unique: true" : ""
      end

      def options_for_migration
        @attr_options.dup.tap do |options|
          if required?
            options[:null] = false
          end

          if reference? && !polymorphic?
            options[:foreign_key] = true
          end
        end
      end
    end
  end
end
