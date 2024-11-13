*   Raise `ActiveRecord::InverseOfAssociationNotFoundError` if invalid inverse_of is specified.

    This error occurs when the association specified in the `inverse_of` option does not exist on the associated class.
    Previously this would be implicitly ignored, so the developer wouldn't know they tried to make an invalid association.

    ```ruby
    Post.belongs_to(:user, inverse_of: :comment) # Correct inverse_of is :post
    user = User.create!

    # Before:
    Post.new(user: user) #=> No error

    # After:
    Post.new(user: user)
    #=> ActiveRecord::InverseOfAssociationNotFoundError: Could not find the inverse association for user (:comment in User).
    ```

    *Hiroyuki Ishii*

*   Add support for enabling or disabling transactional tests per database.

    A test class can now override the default `use_transactional_tests` setting
    for individual databases, which can be useful if some databases need their
    current state to be accessible to an external process while tests are running.

    ```ruby
    class MostlyTransactionalTest < ActiveSupport::TestCase
      self.use_transactional_tests = true
      skip_transactional_tests_for_database :shared
    end
    ```

    *Matthew Cheetham*, *Morgan Mareve*

*   Cast `query_cache` value when using URL configuration.

    *zzak*

*   NULLS NOT DISTINCT works with UNIQUE CONSTRAINT as well as UNIQUE INDEX.

    *Ryuta Kamizono*

*   `PG::UnableToSend: no connection to the server` is now retryable as a connection-related exception

    *Kazuma Watanabe*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activerecord/CHANGELOG.md) for previous changes.
