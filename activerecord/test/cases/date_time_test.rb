require "cases/helper"
require 'models/topic'
require 'models/task'

class DateTimeTest < ActiveRecord::TestCase
  def test_saves_both_date_and_time
    with_env_tz 'America/New_York' do
      with_timezone_config default: :utc do
        time_values = [1807, 2, 10, 15, 30, 45]
        # create DateTime value with local time zone offset
        local_offset = Rational(Time.local(*time_values).utc_offset, 86400)
        now = DateTime.civil(*(time_values + [local_offset]))

        task = Task.new
        task.starting = now
        task.save!

        # check against Time.local, since some platforms will return a Time instead of a DateTime
        assert_equal Time.local(*time_values), Task.find(task.id).starting
      end
    end
  end

  def test_assign_empty_date_time
    task = Task.new
    task.starting = ''
    task.ending = nil
    assert_nil task.starting
    assert_nil task.ending
  end

  def test_assign_empty_date
    topic = Topic.new
    topic.last_read = ''
    assert_nil topic.last_read
  end

  def test_assign_empty_time
    topic = Topic.new
    topic.bonus_time = ''
    assert_nil topic.bonus_time
  end


  def test_saves_time_in_utc
    with_env_tz 'America/New_York' do
      with_active_record_default_timezone :utc do
        time_local = Time.local(2000,1,1,4,59,00)
        topic = Topic.create(bonus_time: time_local)
        saved_time = topic.reload.read_attribute(:bonus_time)
        
        #saved time returns in UTC, and time_local is in NY time, but both are equal
        assert_equal saved_time, time_local
      end
    end
  end
end
