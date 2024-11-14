# frozen_string_literal: true

require "abstract_unit"

class RateLimitedController < ActionController::Base
  self.cache_store = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 2, within: 2.seconds, only: :limited
  rate_limit to: 5, within: 1.minute, name: "long-term", only: :limited

  def limited
    head :ok
  end

  rate_limit to: 2, within: 2.seconds, by: -> { params[:rate_limit_key] }, with: -> { head :forbidden }, only: :limited_with
  def limited_with
    head :ok
  end
end

class RateLimitingTest < ActionController::TestCase
  tests RateLimitedController

  setup do
    RateLimitedController.cache_store.clear
  end

  test "exceeding basic limit" do
    get :limited
    get :limited
    assert_response :ok

    get :limited
    assert_response :too_many_requests
  end

  test "multiple rate limits" do
    get :limited
    get :limited
    assert_response :ok

    travel_to 3.seconds.from_now do
      get :limited
      get :limited
      assert_response :ok
    end

    travel_to 3.seconds.from_now do
      get :limited
      get :limited
      assert_response :too_many_requests
    end
  end

  test "limit resets after time" do
    get :limited
    get :limited
    assert_response :ok

    travel_to Time.now + 3.seconds do
      get :limited
      assert_response :ok
    end
  end

  test "limit by" do
    get :limited_with
    get :limited_with
    get :limited_with
    assert_response :forbidden

    get :limited_with, params: { rate_limit_key: "other" }
    assert_response :ok
  end

  test "limited with" do
    get :limited_with
    get :limited_with
    get :limited_with
    assert_response :forbidden
  end

  test "cross-controller rate limit" do
    shared_store = ActiveSupport::Cache::MemoryStore.new

    @globally_limited_controller = Class.new(RateLimitedController) do
      self.cache_store = shared_store

      rate_limit to: 2, within: 2.seconds, scope: :global, name: "cross-controller", only: :limited_global
      def limited_global
        head :ok
      end
    end.new

    @another_globally_limited_controller = Class.new(RateLimitedController) do
      self.cache_store = shared_store

      rate_limit to: 2, within: 2.seconds, scope: :global, name: "cross-controller", only: :another_limited_global
      def another_limited_global
        head :ok
      end
    end.new

    @controller = @globally_limited_controller
    get :limited_global
    assert_response :ok

    @controller = @another_globally_limited_controller
    get :another_limited_global
    assert_response :ok

    @controller = @globally_limited_controller
    get :limited_global
    assert_response :too_many_requests
  end
end
