require 'abstract_unit'

class ActionController::Base
  class << self
    %w(append_around_action prepend_after_action prepend_around_action prepend_before_action skip_after_action skip_before_action skip_action_callback).each do |pending|
      define_method(pending) do |*args|
        $stderr.puts "#{pending} unimplemented: #{args.inspect}"
      end unless method_defined?(pending)
    end

    def before_actions
      filters = _process_action_callbacks.select { |c| c.kind == :before }
      filters.map! { |c| c.raw_filter }
    end
  end

  def assigns(key = nil)
    assigns = {}
    instance_variables.each do |ivar|
      next if ActionController::Base.protected_instance_variables.include?(ivar)
      assigns[ivar[1..-1]] = instance_variable_get(ivar)
    end

    key.nil? ? assigns : assigns[key.to_s]
  end
end

class FilterTest < ActionController::TestCase

  class TestController < ActionController::Base
    before_action :ensure_login
    after_action  :clean_up

    def show
      render :inline => "ran action"
    end

    private
      def ensure_login
        @ran_filter ||= []
        @ran_filter << "ensure_login"
      end

      def clean_up
        @ran_after_action ||= []
        @ran_after_action << "clean_up"
      end
  end

  class ChangingTheRequirementsController < TestController
    before_action :ensure_login, :except => [:go_wild]

    def go_wild
      render :text => "gobble"
    end
  end

  class TestMultipleFiltersController < ActionController::Base
    before_action :try_1
    before_action :try_2
    before_action :try_3

    (1..3).each do |i|
      define_method "fail_#{i}" do
        render :text => i.to_s
      end
    end

    protected
    (1..3).each do |i|
      define_method "try_#{i}" do
        instance_variable_set :@try, i
        if action_name == "fail_#{i}"
          head(404)
        end
      end
    end
  end

  class RenderingController < ActionController::Base
    before_action :before_action_rendering
    after_action :unreached_after_action

    def show
      @ran_action = true
      render :inline => "ran action"
    end

    private
      def before_action_rendering
        @ran_filter ||= []
        @ran_filter << "before_action_rendering"
        render :inline => "something else"
      end

      def unreached_after_action
        @ran_filter << "unreached_after_action_after_render"
      end
  end

  class RenderingForPrependAfterActionController < RenderingController
    prepend_after_action :unreached_prepend_after_action

    private
      def unreached_prepend_after_action
        @ran_filter << "unreached_preprend_after_action_after_render"
      end
  end

  class BeforeActionRedirectionController < ActionController::Base
    before_action :before_action_redirects
    after_action :unreached_after_action

    def show
      @ran_action = true
      render :inline => "ran show action"
    end

    def target_of_redirection
      @ran_target_of_redirection = true
      render :inline => "ran target_of_redirection action"
    end

    private
      def before_action_redirects
        @ran_filter ||= []
        @ran_filter << "before_action_redirects"
        redirect_to(:action => 'target_of_redirection')
      end

      def unreached_after_action
        @ran_filter << "unreached_after_action_after_redirection"
      end
  end

  class BeforeActionRedirectionForPrependAfterActionController < BeforeActionRedirectionController
    prepend_after_action :unreached_prepend_after_action_after_redirection

    private
      def unreached_prepend_after_action_after_redirection
        @ran_filter << "unreached_prepend_after_action_after_redirection"
      end
  end

  class ConditionalFilterController < ActionController::Base
    def show
      render :inline => "ran action"
    end

    def another_action
      render :inline => "ran action"
    end

    def show_without_action
      render :inline => "ran action without action"
    end

    private
      def ensure_login
        @ran_filter ||= []
        @ran_filter << "ensure_login"
      end

      def clean_up_tmp
        @ran_filter ||= []
        @ran_filter << "clean_up_tmp"
      end
  end

  class ConditionalCollectionFilterController < ConditionalFilterController
    before_action :ensure_login, :except => [ :show_without_action, :another_action ]
  end

  class OnlyConditionSymController < ConditionalFilterController
    before_action :ensure_login, :only => :show
  end

  class ExceptConditionSymController < ConditionalFilterController
    before_action :ensure_login, :except => :show_without_action
  end

  class BeforeAndAfterConditionController < ConditionalFilterController
    before_action :ensure_login, :only => :show
    after_action  :clean_up_tmp, :only => :show
  end

  class OnlyConditionProcController < ConditionalFilterController
    before_action(:only => :show) {|c| c.instance_variable_set(:"@ran_proc_action", true) }
  end

  class ExceptConditionProcController < ConditionalFilterController
    before_action(:except => :show_without_action) {|c| c.instance_variable_set(:"@ran_proc_action", true) }
  end

  class ConditionalClassFilter
    def self.before(controller) controller.instance_variable_set(:"@ran_class_action", true) end
  end

  class OnlyConditionClassController < ConditionalFilterController
    before_action ConditionalClassFilter, :only => :show
  end

  class ExceptConditionClassController < ConditionalFilterController
    before_action ConditionalClassFilter, :except => :show_without_action
  end

  class AnomolousYetValidConditionController < ConditionalFilterController
    before_action(ConditionalClassFilter, :ensure_login, Proc.new {|c| c.instance_variable_set(:"@ran_proc_action1", true)}, :except => :show_without_action) { |c| c.instance_variable_set(:"@ran_proc_action2", true)}
  end

  class OnlyConditionalOptionsFilterController < ConditionalFilterController
    before_action :ensure_login, :only => :index, :if => Proc.new {|c| c.instance_variable_set(:"@ran_conditional_index_proc", true) }
  end

  class ConditionalOptionsFilterController < ConditionalFilterController
    before_action :ensure_login, :if => Proc.new { |c| true }
    before_action :clean_up_tmp, :if => Proc.new { |c| false }
  end

  class ConditionalOptionsSkipFilterController < ConditionalFilterController
    before_action :ensure_login
    before_action :clean_up_tmp

    skip_before_action :ensure_login, if: -> { false }
    skip_before_action :clean_up_tmp, if: -> { true }
  end

  class ClassController < ConditionalFilterController
    before_action ConditionalClassFilter
  end

  class PrependingController < TestController
    prepend_before_action :wonderful_life
    # skip_before_action :fire_flash

    private
      def wonderful_life
        @ran_filter ||= []
        @ran_filter << "wonderful_life"
      end
  end

  class SkippingAndLimitedController < TestController
    skip_before_action :ensure_login
    before_action :ensure_login, :only => :index

    def index
      render :text => 'ok'
    end

    def public
      render :text => 'ok'
    end
  end

  class SkippingAndReorderingController < TestController
    skip_before_action :ensure_login
    before_action :find_record
    before_action :ensure_login

    def index
      render :text => 'ok'
    end

    private
      def find_record
        @ran_filter ||= []
        @ran_filter << "find_record"
      end
  end

  class ConditionalSkippingController < TestController
    skip_before_action :ensure_login, :only => [ :login ]
    skip_after_action  :clean_up,     :only => [ :login ]

    before_action :find_user, :only => [ :change_password ]

    def login
      render :inline => "ran action"
    end

    def change_password
      render :inline => "ran action"
    end

    protected
      def find_user
        @ran_filter ||= []
        @ran_filter << "find_user"
      end
  end

  class ConditionalParentOfConditionalSkippingController < ConditionalFilterController
    before_action :conditional_in_parent_before, :only => [:show, :another_action]
    after_action  :conditional_in_parent_after, :only => [:show, :another_action]

    private

      def conditional_in_parent_before
        @ran_filter ||= []
        @ran_filter << 'conditional_in_parent_before'
      end

      def conditional_in_parent_after
        @ran_filter ||= []
        @ran_filter << 'conditional_in_parent_after'
      end
  end

  class ChildOfConditionalParentController < ConditionalParentOfConditionalSkippingController
    skip_before_action :conditional_in_parent_before, :only => :another_action
    skip_after_action  :conditional_in_parent_after, :only => :another_action
  end

  class AnotherChildOfConditionalParentController < ConditionalParentOfConditionalSkippingController
    skip_before_action :conditional_in_parent_before, :only => :show
  end

  class ProcController < PrependingController
    before_action(proc { |c| c.instance_variable_set(:"@ran_proc_action", true) })
  end

  class ImplicitProcController < PrependingController
    before_action { |c| c.instance_variable_set(:"@ran_proc_action", true) }
  end

  class AuditFilter
    def self.before(controller)
      controller.instance_variable_set(:"@was_audited", true)
    end
  end

  class AroundFilter
    def before(controller)
      @execution_log = "before"
      controller.class.execution_log << " before aroundfilter " if controller.respond_to? :execution_log
      controller.instance_variable_set(:"@before_ran", true)
    end

    def after(controller)
      controller.instance_variable_set(:"@execution_log", @execution_log + " and after")
      controller.instance_variable_set(:"@after_ran", true)
      controller.class.execution_log << " after aroundfilter " if controller.respond_to? :execution_log
    end

    def around(controller)
      before(controller)
      yield
      after(controller)
    end
  end

  class AppendedAroundFilter
    def before(controller)
      controller.class.execution_log << " before appended aroundfilter "
    end

    def after(controller)
      controller.class.execution_log << " after appended aroundfilter "
    end

    def around(controller)
      before(controller)
      yield
      after(controller)
    end
  end

  class AuditController < ActionController::Base
    before_action(AuditFilter)

    def show
      render :text => "hello"
    end
  end

  class AroundFilterController < PrependingController
    around_action AroundFilter.new
  end

  class BeforeAfterClassFilterController < PrependingController
    begin
      filter = AroundFilter.new
      before_action filter
      after_action filter
    end
  end

  class MixedFilterController < PrependingController
    cattr_accessor :execution_log

    def initialize
      @@execution_log = ""
      super()
    end

    before_action { |c| c.class.execution_log << " before procfilter "  }
    prepend_around_action AroundFilter.new

    after_action  { |c| c.class.execution_log << " after procfilter " }
    append_around_action AppendedAroundFilter.new
  end

  class MixedSpecializationController < ActionController::Base
    class OutOfOrder < StandardError; end

    before_action :first
    before_action :second, :only => :foo

    def foo
      render :text => 'foo'
    end

    def bar
      render :text => 'bar'
    end

    protected
      def first
        @first = true
      end

      def second
        raise OutOfOrder unless @first
      end
  end

  class DynamicDispatchController < ActionController::Base
    before_action :choose

    %w(foo bar baz).each do |action|
      define_method(action) { render :text => action }
    end

    private
      def choose
        self.action_name = params[:choose]
      end
  end

  class PrependingBeforeAndAfterController < ActionController::Base
    prepend_before_action :before_all
    prepend_after_action :after_all
    before_action :between_before_all_and_after_all

    def before_all
      @ran_filter ||= []
      @ran_filter << 'before_all'
    end

    def after_all
      @ran_filter ||= []
      @ran_filter << 'after_all'
    end

    def between_before_all_and_after_all
      @ran_filter ||= []
      @ran_filter << 'between_before_all_and_after_all'
    end
    def show
      render :text => 'hello'
    end
  end

  class ErrorToRescue < Exception; end

  class RescuingAroundFilterWithBlock
    def around(controller)
      yield
    rescue ErrorToRescue => ex
      controller.__send__ :render, :text => "I rescued this: #{ex.inspect}"
    end
  end

  class RescuedController < ActionController::Base
    around_action RescuingAroundFilterWithBlock.new

    def show
      raise ErrorToRescue.new("Something made the bad noise.")
    end
  end

  class NonYieldingAroundFilterController < ActionController::Base

    before_action :filter_one
    around_action :non_yielding_action
    before_action :action_two
    after_action :action_three

    def index
      render :inline => "index"
    end

    private

      def filter_one
        @filters  ||= []
        @filters  << "filter_one"
      end

      def action_two
        @filters  << "action_two"
      end

      def non_yielding_action
        @filters  << "it didn't yield"
        @filter_return_value
      end

      def action_three
        @filters  << "action_three"
      end

  end

  class ImplicitActionsController < ActionController::Base
    before_action :find_only, :only => :edit
    before_action :find_except, :except => :edit

    private

    def find_only
      @only = 'Only'
    end

    def find_except
      @except = 'Except'
    end
  end

  class SkippingClassController < ClassController
    skip_before_action ConditionalClassFilter
  end

  def test_non_yielding_around_actions_not_returning_false_do_not_raise
    controller = NonYieldingAroundFilterController.new
    controller.instance_variable_set "@filter_return_value", true
    assert_nothing_raised do
      test_process(controller, "index")
    end
  end

  def test_non_yielding_around_actions_returning_false_do_not_raise
    controller = NonYieldingAroundFilterController.new
    controller.instance_variable_set "@filter_return_value", false
    assert_nothing_raised do
      test_process(controller, "index")
    end
  end

  def test_after_actions_are_not_run_if_around_action_returns_false
    controller = NonYieldingAroundFilterController.new
    controller.instance_variable_set "@filter_return_value", false
    test_process(controller, "index")
    assert_equal ["filter_one", "it didn't yield"], assigns['filters']
  end

  def test_after_actions_are_not_run_if_around_action_does_not_yield
    controller = NonYieldingAroundFilterController.new
    controller.instance_variable_set "@filter_return_value", true
    test_process(controller, "index")
    assert_equal ["filter_one", "it didn't yield"], assigns['filters']
  end

  def test_added_action_to_inheritance_graph
    assert_equal [ :ensure_login ], TestController.before_actions
  end

  def test_base_class_in_isolation
    assert_equal [ ], ActionController::Base.before_actions
  end

  def test_prepending_action
    assert_equal [ :wonderful_life, :ensure_login ], PrependingController.before_actions
  end

  def test_running_actions
    test_process(PrependingController)
    assert_equal %w( wonderful_life ensure_login ), assigns["ran_filter"]
  end

  def test_running_actions_with_proc
    test_process(ProcController)
    assert assigns["ran_proc_action"]
  end

  def test_running_actions_with_implicit_proc
    test_process(ImplicitProcController)
    assert assigns["ran_proc_action"]
  end

  def test_running_actions_with_class
    test_process(AuditController)
    assert assigns["was_audited"]
  end

  def test_running_anomolous_yet_valid_condition_actions
    test_process(AnomolousYetValidConditionController)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
    assert assigns["ran_class_action"]
    assert assigns["ran_proc_action1"]
    assert assigns["ran_proc_action2"]

    test_process(AnomolousYetValidConditionController, "show_without_action")
    assert_nil assigns["ran_filter"]
    assert !assigns["ran_class_action"]
    assert !assigns["ran_proc_action1"]
    assert !assigns["ran_proc_action2"]
  end

  def test_running_conditional_options
    test_process(ConditionalOptionsFilterController)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
  end

  def test_running_conditional_skip_options
    test_process(ConditionalOptionsSkipFilterController)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
  end

  def test_skipping_class_actions
    test_process(ClassController)
    assert_equal true, assigns["ran_class_action"]

    test_process(SkippingClassController)
    assert_nil assigns['ran_class_action']
  end

  def test_running_collection_condition_actions
    test_process(ConditionalCollectionFilterController)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
    test_process(ConditionalCollectionFilterController, "show_without_action")
    assert_nil assigns["ran_filter"]
    test_process(ConditionalCollectionFilterController, "another_action")
    assert_nil assigns["ran_filter"]
  end

  def test_running_only_condition_actions
    test_process(OnlyConditionSymController)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
    test_process(OnlyConditionSymController, "show_without_action")
    assert_nil assigns["ran_filter"]

    test_process(OnlyConditionProcController)
    assert assigns["ran_proc_action"]
    test_process(OnlyConditionProcController, "show_without_action")
    assert !assigns["ran_proc_action"]

    test_process(OnlyConditionClassController)
    assert assigns["ran_class_action"]
    test_process(OnlyConditionClassController, "show_without_action")
    assert !assigns["ran_class_action"]
  end

  def test_running_except_condition_actions
    test_process(ExceptConditionSymController)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
    test_process(ExceptConditionSymController, "show_without_action")
    assert_nil assigns["ran_filter"]

    test_process(ExceptConditionProcController)
    assert assigns["ran_proc_action"]
    test_process(ExceptConditionProcController, "show_without_action")
    assert !assigns["ran_proc_action"]

    test_process(ExceptConditionClassController)
    assert assigns["ran_class_action"]
    test_process(ExceptConditionClassController, "show_without_action")
    assert !assigns["ran_class_action"]
  end

  def test_running_only_condition_and_conditional_options
    test_process(OnlyConditionalOptionsFilterController, "show")
    assert_not assigns["ran_conditional_index_proc"]
  end

  def test_running_before_and_after_condition_actions
    test_process(BeforeAndAfterConditionController)
    assert_equal %w( ensure_login clean_up_tmp), assigns["ran_filter"]
    test_process(BeforeAndAfterConditionController, "show_without_action")
    assert_nil assigns["ran_filter"]
  end

  def test_around_action
    test_process(AroundFilterController)
    assert assigns["before_ran"]
    assert assigns["after_ran"]
  end

  def test_before_after_class_action
    test_process(BeforeAfterClassFilterController)
    assert assigns["before_ran"]
    assert assigns["after_ran"]
  end

  def test_having_properties_in_around_action
    test_process(AroundFilterController)
    assert_equal "before and after", assigns["execution_log"]
  end

  def test_prepending_and_appending_around_action
    test_process(MixedFilterController)
    assert_equal " before aroundfilter  before procfilter  before appended aroundfilter " +
                 " after appended aroundfilter  after procfilter  after aroundfilter ",
                 MixedFilterController.execution_log
  end

  def test_rendering_breaks_actioning_chain
    response = test_process(RenderingController)
    assert_equal "something else", response.body
    assert !assigns["ran_action"]
  end

  def test_before_action_rendering_breaks_actioning_chain_for_after_action
    test_process(RenderingController)
    assert_equal %w( before_action_rendering ), assigns["ran_filter"]
    assert !assigns["ran_action"]
  end

  def test_before_action_redirects_breaks_actioning_chain_for_after_action
    test_process(BeforeActionRedirectionController)
    assert_response :redirect
    assert_equal "http://test.host/filter_test/before_action_redirection/target_of_redirection", redirect_to_url
    assert_equal %w( before_action_redirects ), assigns["ran_filter"]
  end

  def test_before_action_rendering_breaks_actioning_chain_for_preprend_after_action
    test_process(RenderingForPrependAfterActionController)
    assert_equal %w( before_action_rendering ), assigns["ran_filter"]
    assert !assigns["ran_action"]
  end

  def test_before_action_redirects_breaks_actioning_chain_for_preprend_after_action
    test_process(BeforeActionRedirectionForPrependAfterActionController)
    assert_response :redirect
    assert_equal "http://test.host/filter_test/before_action_redirection_for_prepend_after_action/target_of_redirection", redirect_to_url
    assert_equal %w( before_action_redirects ), assigns["ran_filter"]
  end

  def test_actions_with_mixed_specialization_run_in_order
    assert_nothing_raised do
      response = test_process(MixedSpecializationController, 'bar')
      assert_equal 'bar', response.body
    end

    assert_nothing_raised do
      response = test_process(MixedSpecializationController, 'foo')
      assert_equal 'foo', response.body
    end
  end

  def test_dynamic_dispatch
    %w(foo bar baz).each do |action|
      request = ActionController::TestRequest.new(Rack::MockRequest.env_for('/'))
      request.query_parameters[:choose] = action
      response = DynamicDispatchController.action(action).call(request.env).last
      assert_equal action, response.body
    end
  end

  def test_running_prepended_before_and_after_action
    test_process(PrependingBeforeAndAfterController)
    assert_equal %w( before_all between_before_all_and_after_all after_all ), assigns["ran_filter"]
  end

  def test_skipping_and_limiting_controller
    test_process(SkippingAndLimitedController, "index")
    assert_equal %w( ensure_login ), assigns["ran_filter"]
    test_process(SkippingAndLimitedController, "public")
    assert_nil assigns["ran_filter"]
  end

  def test_skipping_and_reordering_controller
    test_process(SkippingAndReorderingController, "index")
    assert_equal %w( find_record ensure_login ), assigns["ran_filter"]
  end

  def test_conditional_skipping_of_actions
    test_process(ConditionalSkippingController, "login")
    assert_nil assigns["ran_filter"]
    test_process(ConditionalSkippingController, "change_password")
    assert_equal %w( ensure_login find_user ), assigns["ran_filter"]

    test_process(ConditionalSkippingController, "login")
    assert !@controller.instance_variable_defined?("@ran_after_action")
    test_process(ConditionalSkippingController, "change_password")
    assert_equal %w( clean_up ), @controller.instance_variable_get("@ran_after_action")
  end

  def test_conditional_skipping_of_actions_when_parent_action_is_also_conditional
    test_process(ChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_before conditional_in_parent_after ), assigns['ran_filter']
    test_process(ChildOfConditionalParentController, 'another_action')
    assert_nil assigns['ran_filter']
  end

  def test_condition_skipping_of_actions_when_siblings_also_have_conditions
    test_process(ChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_before conditional_in_parent_after ), assigns['ran_filter']
    test_process(AnotherChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_after ), assigns['ran_filter']
    test_process(ChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_before conditional_in_parent_after ), assigns['ran_filter']
  end

  def test_changing_the_requirements
    test_process(ChangingTheRequirementsController, "go_wild")
    assert_nil assigns['ran_filter']
  end

  def test_a_rescuing_around_action
    response = nil
    assert_nothing_raised do
      response = test_process(RescuedController)
    end

    assert response.success?
    assert_equal("I rescued this: #<FilterTest::ErrorToRescue: Something made the bad noise.>", response.body)
  end

  def test_actions_obey_only_and_except_for_implicit_actions
    test_process(ImplicitActionsController, 'show')
    assert_equal 'Except', assigns(:except)
    assert_nil assigns(:only)
    assert_equal 'show', response.body

    test_process(ImplicitActionsController, 'edit')
    assert_equal 'Only', assigns(:only)
    assert_nil assigns(:except)
    assert_equal 'edit', response.body
  end

  private
    def test_process(controller, action = "show")
      @controller = controller.is_a?(Class) ? controller.new : controller
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new

      process(action)
    end
end

class PostsController < ActionController::Base
  module AroundExceptions
    class Error < StandardError ; end
    class Before < Error ; end
    class After < Error ; end
  end
  include AroundExceptions

  class DefaultFilter
    include AroundExceptions
  end

  module_eval %w(raises_before raises_after raises_both no_raise no_action).map { |action| "def #{action}; default_action end" }.join("\n")

  private
    def default_action
      render :inline => "#{action_name} called"
    end
end

class WithSymbolAsFilterController < PostsController
  around_action :raise_before, :only => :raises_before
  around_action :raise_after, :only => :raises_after
  around_action :without_exception, :only => :no_raise

  private
    def raise_before
      raise Before
      yield
    end

    def raise_after
      yield
      raise After
    end

    def without_exception
      # Do stuff...
      wtf = 1 + 1

      yield

      # Do stuff...
      wtf += 1
    end
end

class WithFilterClassController < PostsController
  class YieldingFilter < DefaultFilter
    def self.around(controller)
      yield
      raise After
    end
  end

  around_action YieldingFilter, :only => :raises_after
end

class WithFilterInstanceController < PostsController
  class YieldingFilter < DefaultFilter
    def around(controller)
      yield
      raise After
    end
  end

  around_action YieldingFilter.new, :only => :raises_after
end

class WithProcFilterController < PostsController
  around_action(:only => :no_raise) do |c,b|
    c.instance_variable_set(:"@before", true)
    b.call
    c.instance_variable_set(:"@after", true)
  end
end

class WithNestedFiltersController < WithSymbolAsFilterController
  around_action :raise_before, :raise_after, :without_exception, :only => :raises_both
end

class WithAllTypesOfFiltersController < PostsController
  before_action :before
  around_action :around
  after_action :after
  around_action :around_again

  private
  def before
    @ran_filter ||= []
    @ran_filter << 'before'
  end

  def around
    @ran_filter << 'around (before yield)'
    yield
    @ran_filter << 'around (after yield)'
  end

  def after
    @ran_filter << 'after'
  end

  def around_again
    @ran_filter << 'around_again (before yield)'
    yield
    @ran_filter << 'around_again (after yield)'
  end
end

class WithTwoLessFiltersController < WithAllTypesOfFiltersController
  skip_action_callback :around_again
  skip_action_callback :after
end

class YieldingAroundFiltersTest < ActionController::TestCase
  include PostsController::AroundExceptions

  def test_base
    controller = PostsController
    assert_nothing_raised { test_process(controller,'no_raise') }
    assert_nothing_raised { test_process(controller,'raises_before') }
    assert_nothing_raised { test_process(controller,'raises_after') }
    assert_nothing_raised { test_process(controller,'no_action') }
  end

  def test_with_symbol
    controller = WithSymbolAsFilterController
    assert_nothing_raised { test_process(controller,'no_raise') }
    assert_raise(Before) { test_process(controller,'raises_before') }
    assert_raise(After) { test_process(controller,'raises_after') }
    assert_nothing_raised { test_process(controller,'no_raise') }
  end

  def test_with_class
    controller = WithFilterClassController
    assert_nothing_raised { test_process(controller,'no_raise') }
    assert_raise(After) { test_process(controller,'raises_after') }
  end

  def test_with_instance
    controller = WithFilterInstanceController
    assert_nothing_raised { test_process(controller,'no_raise') }
    assert_raise(After) { test_process(controller,'raises_after') }
  end

  def test_with_proc
    test_process(WithProcFilterController,'no_raise')
    assert assigns['before']
    assert assigns['after']
  end

  def test_nested_actions
    controller = WithNestedFiltersController
    assert_nothing_raised do
      begin
        test_process(controller,'raises_both')
      rescue Before, After
      end
    end
    assert_raise Before do
      begin
        test_process(controller,'raises_both')
      rescue After
      end
    end
  end

  def test_action_order_with_all_action_types
    test_process(WithAllTypesOfFiltersController,'no_raise')
    assert_equal 'before around (before yield) around_again (before yield) around_again (after yield) after around (after yield)', assigns['ran_filter'].join(' ')
  end

  def test_action_order_with_skip_action_method
    test_process(WithTwoLessFiltersController,'no_raise')
    assert_equal 'before around (before yield) around (after yield)', assigns['ran_filter'].join(' ')
  end

  def test_first_action_in_multiple_before_action_chain_halts
    controller = ::FilterTest::TestMultipleFiltersController.new
    response = test_process(controller, 'fail_1')
    assert_equal ' ', response.body
    assert_equal 1, @controller.instance_variable_get(:@try)
  end

  def test_second_action_in_multiple_before_action_chain_halts
    controller = ::FilterTest::TestMultipleFiltersController.new
    response = test_process(controller, 'fail_2')
    assert_equal ' ', response.body
    assert_equal 2, @controller.instance_variable_get(:@try)
  end

  def test_last_action_in_multiple_before_action_chain_halts
    controller = ::FilterTest::TestMultipleFiltersController.new
    response = test_process(controller, 'fail_3')
    assert_equal ' ', response.body
    assert_equal 3, @controller.instance_variable_get(:@try)
  end

  protected
    def test_process(controller, action = "show")
      @controller = controller.is_a?(Class) ? controller.new : controller
      process(action)
    end
end
