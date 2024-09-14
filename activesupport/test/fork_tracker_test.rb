# frozen_string_literal: true

require_relative "abstract_unit"

class ForkTrackerTest < ActiveSupport::TestCase
  def setup
    super

    @read, @write = IO.pipe
    @before_called = false
    @after_called = false

    @before_handler = ActiveSupport::ForkTracker.before_fork do
      @before_called = true
    end

    @after_handler = ActiveSupport::ForkTracker.after_fork do
      @after_called = true
      @write.write "forked"
    end
  end

  def teardown
    ActiveSupport::ForkTracker.unregister_before_fork(@before_handler)
    ActiveSupport::ForkTracker.unregister_after_fork(@after_handler)

    super
  end

  def test_object_fork
    assert_not respond_to?(:fork)
    pid = fork do
      @read.close
      @write.close
      exit!
    end

    @write.close

    Process.waitpid(pid)
    assert_equal "forked", @read.read
    @read.close

    assert @before_called
    assert_not @after_called
  end

  def test_object_fork_without_block
    if pid = fork
      @write.close
      Process.waitpid(pid)
      assert_equal "forked", @read.read
      @read.close
      assert @before_called
      assert_not @after_called
    else
      @read.close
      @write.close
      exit!
    end
  end

  def test_process_fork
    pid = Process.fork do
      @read.close
      @write.close
      exit!
    end

    @write.close

    Process.waitpid(pid)
    assert_equal "forked", @read.read
    @read.close
    assert @before_called
    assert_not @after_called
  end

  def test_process_fork_without_block
    if pid = Process.fork
      @write.close
      Process.waitpid(pid)
      assert_equal "forked", @read.read
      @read.close
      assert @before_called
      assert_not @after_called
    else
      @read.close
      @write.close
      exit!
    end
  end

  def test_kernel_fork
    pid = Kernel.fork do
      @read.close
      @write.close
      exit!
    end

    @write.close

    Process.waitpid(pid)
    assert_equal "forked", @read.read
    @read.close
    assert @before_called
    assert_not @after_called
  end

  def test_kernel_fork_without_block
    if pid = Kernel.fork
      @write.close
      Process.waitpid(pid)
      assert_equal "forked", @read.read
      @read.close
      assert @before_called
      assert_not @after_called
    else
      @read.close
      @write.close
      exit!
    end
  end

  def test_basic_object_with_kernel_fork
    klass = Class.new(BasicObject) do
      include ::Kernel
      def fark(&block)
        fork(&block)
      end
    end

    object = klass.new
    assert_not object.respond_to?(:fork)
    pid = object.fark do
      @read.close
      @write.close
      exit!
    end

    @write.close

    Process.waitpid(pid)
    assert_equal "forked", @read.read
    @read.close

    assert @before_called
    assert_not @after_called
  end

  def test_unregister_callback
    ActiveSupport::ForkTracker.unregister_before_fork(@before_handler)
    ActiveSupport::ForkTracker.unregister_after_fork(@after_handler)

    if pid = Process.fork
      @write.close
      Process.waitpid(pid)
      assert_equal "", @read.read
      @read.close
      assert_not @before_called
      assert_not @after_called
    else
      @read.close
      @write.close
      exit!
    end
  end
end if Process.respond_to?(:fork)
