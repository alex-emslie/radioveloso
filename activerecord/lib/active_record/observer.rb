require 'active_support/core_ext/class/attribute'

module ActiveRecord
  # Observer classes respond to lifecycle callbacks to implement trigger-like
  # behavior outside the original class. This is a great way to reduce the
  # clutter that normally comes when the model class is burdened with
  # functionality that doesn't pertain to the core responsibility of the
  # class. Example:
  #
  #   class CommentObserver < ActiveRecord::Observer
  #     def after_save(comment)
  #       Notifications.deliver_comment("admin@do.com", "New comment was posted", comment)
  #     end
  #   end
  #
  # This Observer sends an email when a Comment#save is finished.
  #
  #   class ContactObserver < ActiveRecord::Observer
  #     def after_create(contact)
  #       contact.logger.info('New contact added!')
  #     end
  #
  #     def after_destroy(contact)
  #       contact.logger.warn("Contact with an id of #{contact.id} was destroyed!")
  #     end
  #   end
  #
  # This Observer uses logger to log when specific callbacks are triggered.
  #
  # == Observing a class that can't be inferred
  #
  # Observers will by default be mapped to the class with which they share a name. So CommentObserver will
  # be tied to observing Comment, ProductManagerObserver to ProductManager, and so on. If you want to name your observer
  # differently than the class you're interested in observing, you can use the Observer.observe class method which takes
  # either the concrete class (Product) or a symbol for that class (:product):
  #
  #   class AuditObserver < ActiveRecord::Observer
  #     observe :account
  #
  #     def after_update(account)
  #       AuditTrail.new(account, "UPDATED")
  #     end
  #   end
  #
  # If the audit observer needs to watch more than one kind of object, this can be specified with multiple arguments:
  #
  #   class AuditObserver < ActiveRecord::Observer
  #     observe :account, :balance
  #
  #     def after_update(record)
  #       AuditTrail.new(record, "UPDATED")
  #     end
  #   end
  #
  # The AuditObserver will now act on both updates to Account and Balance by treating them both as records.
  #
  # == Available callback methods
  #
  # The observer can implement callback methods for each of the methods described in the Callbacks module.
  #
  # == Storing Observers in Rails
  #
  # If you're using Active Record within Rails, observer classes are usually stored in app/models with the
  # naming convention of app/models/audit_observer.rb.
  #
  # == Configuration
  #
  # In order to activate an observer, list it in the <tt>config.active_record.observers</tt> configuration setting in your
  # <tt>config/environment.rb</tt> file.
  #
  #   config.active_record.observers = :comment_observer, :signup_observer
  #
  # Observers will not be invoked unless you define these in your application configuration.
  #
  # == Loading
  #
  # Observers register themselves in the model class they observe, since it is the class that
  # notifies them of events when they occur. As a side-effect, when an observer is loaded its
  # corresponding model class is loaded.
  #
  # Up to (and including) Rails 2.0.2 observers were instantiated between plugins and
  # application initializers. Now observers are loaded after application initializers,
  # so observed models can make use of extensions.
  #
  # If by any chance you are using observed models in the initialization you can still
  # load their observers by calling <tt>ModelObserver.instance</tt> before. Observers are
  # singletons and that call instantiates and registers them.
  #
  class Observer < ActiveModel::Observer
    class_attribute :observed_methods
    self.observed_methods = []

    def initialize
      super
      observed_subclasses.each { |klass| add_observer!(klass) }
    end

    def self.method_added(method)
      self.observed_methods += [method] if ActiveRecord::Callbacks::CALLBACKS.include?(method.to_sym)
    end

    protected
      def observed_subclasses
        observed_classes.sum([]) { |klass| klass.send(:subclasses) }
      end

      def add_observer!(klass)
        super

        # Check if a notifier callback was already added to the given class. If
        # it was not, add it.
        self.class.observed_methods.each do |method|
          callback = :"_notify_observers_for_#{method}"
          if (klass.instance_methods & [callback, callback.to_s]).empty?
            klass.class_eval "def #{callback}; notify_observers(:#{method}); end"
            klass.send(method, callback)
          end
        end
      end
  end
end
