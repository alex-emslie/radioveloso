require 'active_support/core_ext/object/blank'

module ActiveModel
  module Validations
    # == Active Model Absence Validator
    class AbsenceValidator < EachValidator #:nodoc:
      def validate(record)
        record.errors.add_on_present(attributes, options)
      end
    end

    module HelperMethods
      # Validates that the specified attributes are blank (as defined by
      # Object#blank?). Happens by default on save.
      #
      #   class Person < ActiveRecord::Base
      #     validates_absence_of :first_name
      #   end
      #
      # The first_name attribute must be in the object and it must be blank.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "must be blank").
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+ and +:strict+.
      # See <tt>ActiveModel::Validation#validates</tt> for more information
      def validates_absence_of(*attr_names)
        validates_with AbsenceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
