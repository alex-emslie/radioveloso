# frozen_string_literal: true

module ActiveSupport
  # Actionable errors let's you define actions to resolve an error.
  #
  # To make an error actionable, include the <tt>ActiveSupport::ActionableError</tt>
  # module and invoke the +action+ class macro to define the action. An action
  # needs a name and a block to execute.
  module ActionableError
    extend Concern

    class NonActionable < StandardError; end # :nodoc:

    Trigger = Struct.new(:actionable, :condition) do # :nodoc:
      def act_on(error)
        raise actionable if condition&.call(error)
      end
    end

    mattr_accessor :triggers, default: Hash.new { |h, k| h[k] = [] } # :nodoc:

    included do
      class_attribute :_actions, default: {}
    end

    def self.actions(error) # :nodoc:
      case error
      when ActionableError, -> it { Class === it && it < ActionableError }
        error._actions
      else
        {}
      end
    end

    def self.dispatch(error, name) # :nodoc:
      actions(error).fetch(name).call
    rescue KeyError
      raise NonActionable, "Cannot find action \"#{name}\""
    end

    def self.raise_if_triggered_by(error) # :nodoc:
      triggers[error.class].each { |trigger| trigger.act_on(error) }
      raise_if_triggered_by(error.cause) if error.cause
    end

    module ClassMethods
      # Defines an action that can resolve the error.
      #
      #   class PendingMigrationError < MigrationError
      #     include ActiveSupport::ActionableError
      #
      #     action "Run pending migrations" do
      #       ActiveRecord::Tasks::DatabaseTasks.migrate
      #     end
      #   end
      def action(name, &block)
        _actions[name] = block
      end

      # Trigger the current actionable error from a pre-existing if the
      # condition, given as a block, returns a truthy value.
      #
      #   class SetupError < Error
      #     include ActiveSupport::ActionableError
      #
      #     trigger on: ActiveRecord::RecordInvalid, if: -> error do
      #       error.message.match?(InboundEmail.table_name)
      #     end
      #   end
      #
      # Note: For an actionable error to be triggered, its constant needs to be
      # loaded. If it isn't autoloaded, the triggers won't be registered until
      # it is. Keep that in mind, if the actionable error isn't triggered.
      def trigger(options)
        error = options.fetch(:on) { raise ArgumentError, "missing keyword: on" }
        condition = options.fetch(:if) { raise ArgumentError, "missing keyword: if" }

        ActiveSupport::ActionableError.triggers[error] << Trigger.new(self, condition)
      end
    end
  end
end
