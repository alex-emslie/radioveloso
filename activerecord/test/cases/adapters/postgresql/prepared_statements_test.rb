require "cases/helper"
require "models/computer"
require "models/developer"

class PreparedStatementsTest < ActiveRecord::PostgreSQLTestCase
  fixtures :developers

  def setup
    @default_prepared_statements = Developer.connection_config[:prepared_statements]
    Developer.connection_config[:prepared_statements] = false
  end

  def teardown
    Developer.connection_config[:prepared_statements] = @default_prepared_statements
  end

  def test_nothing_raised_with_falsy_prepared_statements
    assert_nothing_raised do
      Developer.first #With Binds
      Developer.count #Without Binds
    end
  end
end
