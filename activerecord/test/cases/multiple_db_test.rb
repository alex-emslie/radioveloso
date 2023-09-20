# frozen_string_literal: true

require "cases/helper"
require "models/entrant"
require "models/bird"
require "models/course"

class MultipleDbTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  def setup
    @courses  = create_fixtures("courses") { Course.retrieve_connection }
    @colleges = create_fixtures("colleges") { College.retrieve_connection }
    @entrants = create_fixtures("entrants")
  end

  def teardown
    clean_up_connection_handler
  end

  def test_connected
    assert_not_nil Entrant.connection
    assert_not_nil Course.connection
  end

  def test_proper_connection
    assert_not_equal(Entrant.connection, Course.connection)
    assert_equal(Entrant.connection, Entrant.retrieve_connection)
    assert_equal(Course.connection, Course.retrieve_connection)
    assert_equal(ActiveRecord::Base.connection, Entrant.connection)
  end

  def test_swapping_the_connection
    old_spec_name, Course.connection_specification_name = Course.connection_specification_name, "ActiveRecord::Base"
    assert_equal(Entrant.connection, Course.connection)
  ensure
    Course.connection_specification_name = old_spec_name
  end

  def test_find
    c1 = Course.find(1)
    assert_equal "Ruby Development", c1.name
    c2 = Course.find(2)
    assert_equal "Java Development", c2.name
    e1 = Entrant.find(1)
    assert_equal "Ruby Developer", e1.name
    e2 = Entrant.find(2)
    assert_equal "Ruby Guru", e2.name
    e3 = Entrant.find(3)
    assert_equal "Java Lover", e3.name
  end

  def test_associations
    c1 = Course.find(1)
    assert_equal 2, c1.entrants.count
    e1 = Entrant.find(1)
    assert_equal e1.course.id, c1.id
    c2 = Course.find(2)
    assert_equal 1, c2.entrants.count
    e3 = Entrant.find(3)
    assert_equal e3.course.id, c2.id
  end

  def test_course_connection_should_survive_reloads
    assert Course.connection

    assert Object.send(:remove_const, :Course)
    assert load("models/course.rb")

    assert Course.connection
  end

  def test_transactions_across_databases
    c1 = Course.find(1)
    e1 = Entrant.find(1)

    begin
      Course.transaction do
        Entrant.transaction do
          c1.name = "Typo"
          e1.name = "Typo"
          c1.save
          e1.save
          raise "No I messed up."
        end
      end
    rescue
      # Yup caught it
    end

    assert_equal "Typo", c1.name
    assert_equal "Typo", e1.name

    assert_equal "Ruby Development", Course.find(1).name
    assert_equal "Ruby Developer", Entrant.find(1).name
  end

  def test_connection
    assert_same Entrant.connection, Bird.connection
    assert_not_same Entrant.connection, Course.connection
  end

  unless in_memory_db?
    def test_count_on_custom_connection
      assert_equal ARUnit2Model.connection, College.connection
      assert_not_equal ActiveRecord::Base.connection, College.connection
      assert_equal 1, College.count
    end

    def test_associations_should_work_when_model_has_no_connection
      assert_nothing_raised do
        College.first.courses.first
      end
    end
  end

  def test_exception_contains_connection_pool
    error = assert_raises(ActiveRecord::StatementInvalid) do
      Course.where(wrong_column: "wrong").first!
    end

    assert_equal Course.connection.pool, error.connection_pool
  end

  def test_exception_contains_correct_pool
    course_conn = Course.connection
    entrant_conn = Entrant.connection

    assert_not_equal course_conn, entrant_conn

    course_error = assert_raises(ActiveRecord::StatementInvalid) do
      course_conn.execute("SELECT * FROM entrants")
    end

    assert_equal course_conn.pool, course_error.connection_pool

    entrant_error = assert_raises(ActiveRecord::StatementInvalid) do
      entrant_conn.execute("SELECT * FROM courses")
    end

    assert_equal entrant_conn.pool, entrant_error.connection_pool
  end

  unless in_memory_db?
    def test_exception_message_includes_connection_info
      previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

      config = {
        "default_env" => {
          "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
          "primary_shard_one" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3" }
        }
      }

      prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

      ActiveRecord::Base.connects_to(shards: {
        default: { writing: :primary },
        shard_one: { writing: :primary_shard_one, reading: :primary_shard_one }
      })

      assert_raises(ActiveRecord::StatementInvalid, match: /Connection: ActiveRecord::Base\(role: reading, shard: shard_one, config name: primary_shard_one\)/) do
        ActiveRecord::Base.connected_to(role: :reading, shard: :shard_one) do
          ActiveRecord::Base.connection.execute("select * from nonexistent")
        end
      end
    ensure
      ActiveRecord::Base.configurations = prev_configs
      ActiveRecord::Base.establish_connection(:arunit)
      ENV["RAILS_ENV"] = previous_env
    end

    def test_exception_message_does_not_include_connection_info_for_single_database
      error = assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.connection.execute("select * from nonexistent")
      end
      assert_no_match(/Connection: ActiveRecord::Base/, error.message)
    end
  end
end
