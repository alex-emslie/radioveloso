require 'active_support/core_ext/module/attribute_accessors'

module ActiveRecord
  module AttributeMethods
    module Dirty # :nodoc:
      extend ActiveSupport::Concern

      include ActiveModel::Dirty

      included do
        if self < ::ActiveRecord::Timestamp
          raise "You cannot include Dirty after Timestamp"
        end

        class_attribute :partial_writes, instance_writer: false
        self.partial_writes = true
      end

      # Attempts to +save+ the record and clears changed attributes if successful.
      def save(*)
        if status = super
          changes_applied
        end
        status
      end

      # Attempts to <tt>save!</tt> the record and clears changed attributes if successful.
      def save!(*)
        super.tap do
          changes_applied
        end
      end

      # <tt>reload</tt> the record and clears changed attributes.
      def reload(*)
        super.tap do
          reset_changes
        end
      end

      # Wrap write_attribute to remember original attribute value.
      def write_attribute(attr, value)
        attr = attr.to_s
        #goal to do something like this (and not deal with attribute_changed?:
        ##set_original_value(attr)

        # BEGIN
        # The attribute already has an unsaved change.
        if attribute_changed?(attr)
          old = original_values[attr]
          reset_change(attr) unless _field_changed?(attr, old, value)
        else
          old = clone_attribute_value(:read_attribute, attr)
          set_original_value(attr, old, value)
        end
        # END

        # Carry on.
        super(attr, value)
      end

      def read_attribute(attr)
        super.tap { |value|
          attr = attr.to_s
          if attr != "" && attribute_names.include?(attr)
            set_original_value(attr, value, value)
          end
        }
      end

    private

    def set_original_value(*args)
      attr = args.first
      args << clone_attribute_value(:read_attribute, attr) if args.length < 2
      super(*args)
    end

      def update_record(*)
        partial_writes? ? super(keys_for_partial_write) : super
      end

      def create_record(*)
        partial_writes? ? super(keys_for_partial_write) : super
      end

      # Serialized attributes should always be written in case they've been
      # changed in place.
      def keys_for_partial_write
        changed
      end

      def attribute_change(attr)
        attr = attr.to_s
        if original_values.key?(attr)
          old = original_values[attr]
          value = __send__(attr)
          #for numbers and stuff, want to do a quick compare before type_casting - but not working
          #test_value =__send__("#{attr}_before_type_cast")

          # if changed_attributes_on_way_out.key?(attr) != _field_changed?(attr, old, test_value)
          #   ###puts [
          #   ###  attr,
          #   ###  "old=#{old}",
          #   ###  "changed=#{changed_attributes.key?(attr) ? changed_attributes[attr] : "doesnt have it"}",
          #   ###  "attributes=#{@attributes[attr]}",
          #   ###  "value=#{value}",
          #   ###  "before_typecast=#{__send__("#{attr}_before_type_cast")}",
          #   ###  _field_changed?(attr, old, value) ? "field_changed" : "field_NOT_changed",
          #   ###  old == @attributes[attr] ? "attr_same" : "attr_changed"
          #   ###].inspect #if attr == "zine_id"

          #   ###puts("   via #{caller[0..4].reverse.map {|c| c[/`.*'/][1..-2]}.join(" -> ") }") if attr == "zine_id"
          #   binding.pry
          # end
          #remove:
          [old, value] if _field_changed?(attr, old, value) || (changed_attributes_on_way_out.key?(attr))
          #goal to do something like this:
          #[old, value] if _field_changed?(attr, old, test_value)
        end
      end

      def _field_changed?(attr, old, value)
        if column = column_for_attribute(attr)
          if column.number? && (changes_from_nil_to_empty_string?(column, old, value) ||
                                changes_from_zero_to_string?(old, value))
            value = nil
          else
            value = column.type_cast(value)
          end
        end

        old != value
      end

      def changes_from_nil_to_empty_string?(column, old, value)
        # For nullable numeric columns, NULL gets stored in database for blank (i.e. '') values.
        # Hence we don't record it as a change if the value changes from nil to ''.
        # If an old value of 0 is set to '' we want this to get changed to nil as otherwise it'll
        # be typecast back to 0 (''.to_i => 0)
        column.null && (old.nil? || old == 0) && value.blank?
      end

      def changes_from_zero_to_string?(old, value)
        # For columns with old 0 and value non-empty string
        old == 0 && value.is_a?(String) && value.present? && non_zero?(value)
      end

      def non_zero?(value)
        value !~ /\A0+(\.0+)?\z/
      end
    end
  end
end
