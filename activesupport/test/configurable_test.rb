require 'abstract_unit'
require 'active_support/configurable'

class ConfigurableActiveSupport < ActiveSupport::TestCase
  class Parent
    include ActiveSupport::Configurable
    config_accessor :foo
    config_accessor :bar, :instance_reader => false, :instance_writer => false
  end

  class Child < Parent
  end

  setup do
    Parent.config.clear
    Parent.config.foo = :bar

    Child.config.clear
  end

  test "adds a configuration hash" do
    assert_equal({ :foo => :bar }, Parent.config)
  end

  test "adds a configuration hash to a module as well" do
    mixin = Module.new { include ActiveSupport::Configurable }
    mixin.config.foo = :bar
    assert_equal({ :foo => :bar }, mixin.config)
  end

  test "configuration hash is inheritable" do
    assert_equal :bar, Child.config.foo
    assert_equal :bar, Parent.config.foo

    Child.config.foo = :baz
    assert_equal :baz, Child.config.foo
    assert_equal :bar, Parent.config.foo
  end

  test "configuration accessors is not available on instance" do
    instance = Parent.new
    assert !instance.respond_to?(:bar)
    assert !instance.respond_to?(:bar=)
  end

  test "configuration hash is available on instance" do
    instance = Parent.new
    assert_equal :bar, instance.config.foo
    assert_equal :bar, Parent.config.foo

    instance.config.foo = :baz
    assert_equal :baz, instance.config.foo
    assert_equal :bar, Parent.config.foo
  end

  test "configuration is crystalizeable" do
    parent = Class.new { include ActiveSupport::Configurable }
    child  = Class.new(parent)

    parent.config.bar = :foo
    assert_method_not_defined parent.config, :bar
    assert_method_not_defined child.config, :bar
    assert_method_not_defined child.new.config, :bar

    parent.config.compile_methods!
    assert_equal :foo, parent.config.bar
    assert_equal :foo, child.new.config.bar

    assert_method_defined parent.config, :bar
    assert_method_defined child.config, :bar
    assert_method_defined child.new.config, :bar
  end

  test "configuration can take defaults" do
    parent = Class.new do
      include ActiveSupport::Configurable
      config_accessor :foo, :bar, :default => 'bar'
    end

    assert_equal parent.config.foo, 'bar'
    assert_equal parent.config.bar, 'bar'
  end

  def assert_method_defined(object, method)
    methods = object.public_methods.map(&:to_s)
    assert methods.include?(method.to_s), "Expected #{methods.inspect} to include #{method.to_s.inspect}"
  end

  def assert_method_not_defined(object, method)
    methods = object.public_methods.map(&:to_s)
    assert !methods.include?(method.to_s), "Expected #{methods.inspect} to not include #{method.to_s.inspect}"
  end
end
