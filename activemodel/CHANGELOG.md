*   Port `ActiveRecord::AttributeMethods::Query` to Active Model. Classes that include
    `ActiveModel::Attributes` will now provide this method. This method behaves
    the same for Active Model as it does for Active Record.

      ```ruby
      class MyModel
        include ActiveModel::Attributes

        attribute :my_attribute, :integer
      end

      MyModel.new(my_attribute: 0).my_attribute? # => false
      MyModel.new(my_attribute: 1).my_attribute? # => true
      ```

    *Sean Doyle*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activemodel/CHANGELOG.md) for previous changes.
