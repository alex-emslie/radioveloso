require "test_helper"
require "stubs/test_socket"
require "stubs/room"

module ActionCable::StreamTests
  class Socket < ActionCable::Socket::Base
    attr_reader :websocket

    def send_async(method, *args)
      send method, *args
    end
  end

  class ChatChannel < ActionCable::Channel::Base
    def subscribed
      if params[:id]
        @room = Room.new params[:id]
        stream_from "test_room_#{@room.id}", coder: pick_coder(params[:coder])
      end
    end

    def send_confirmation
      transmit_subscription_confirmation
    end

    private def pick_coder(coder)
      case coder
      when nil, "json"
        ActiveSupport::JSON
      when "custom"
        DummyEncoder
      when "none"
        nil
      end
    end
  end

  module DummyEncoder
    extend self
    def encode(*) '{ "foo": "encoded" }' end
    def decode(*) { foo: "decoded" } end
  end

  class SymbolChannel < ActionCable::Channel::Base
    def subscribed
      stream_from :channel
    end
  end

  class StreamTest < ActionCable::TestCase
    test "streaming start and stop" do
      run_in_eventmachine do
        socket = TestSocket.new
        socket.expects(:pubsub).returns mock().tap { |m| m.expects(:subscribe).with("test_room_1", kind_of(Proc), kind_of(Proc)).returns stub_everything(:pubsub) }
        channel = ChatChannel.new socket.connection, "{id: 1}", id: 1
        channel.subscribe_to_channel

        socket.expects(:pubsub).returns mock().tap { |m| m.expects(:unsubscribe) }
        channel.unsubscribe_from_channel
      end
    end

    test "stream from non-string channel" do
      run_in_eventmachine do
        socket = TestSocket.new
        socket.expects(:pubsub).returns mock().tap { |m| m.expects(:subscribe).with("channel", kind_of(Proc), kind_of(Proc)).returns stub_everything(:pubsub) }
        channel = SymbolChannel.new socket.connection, ""
        channel.subscribe_to_channel

        socket.expects(:pubsub).returns mock().tap { |m| m.expects(:unsubscribe) }
        channel.unsubscribe_from_channel
      end
    end

    test "stream_for" do
      run_in_eventmachine do
        socket = TestSocket.new
        socket.expects(:pubsub).returns mock().tap { |m| m.expects(:subscribe).with("action_cable:stream_tests:chat:Room#1-Campfire", kind_of(Proc), kind_of(Proc)).returns stub_everything(:pubsub) }

        channel = ChatChannel.new socket.connection, ""
        channel.subscribe_to_channel
        channel.stream_for Room.new(1)
      end
    end

    test "stream_from subscription confirmation" do
      run_in_eventmachine do
        socket = TestSocket.new

        channel = ChatChannel.new socket.connection, "{id: 1}", id: 1
        channel.subscribe_to_channel

        assert_nil socket.last_transmission

        wait_for_async

        confirmation = { "identifier" => "{id: 1}", "type" => "confirm_subscription" }
        socket.connection.transmit(confirmation)

        assert_equal confirmation, socket.last_transmission, "Did not receive subscription confirmation within 0.1s"
      end
    end

    test "subscription confirmation should only be sent out once" do
      run_in_eventmachine do
        socket = TestSocket.new

        channel = ChatChannel.new socket.connection, "test_channel"
        channel.send_confirmation
        channel.send_confirmation

        wait_for_async

        expected = { "identifier" => "test_channel", "type" => "confirm_subscription" }
        assert_equal expected, socket.last_transmission, "Did not receive subscription confirmation"

        assert_equal 1, socket.transmissions.size
      end
    end
  end

  require "action_cable/subscription_adapter/async"

  class UserCallbackChannel < ActionCable::Channel::Base
    def subscribed
      stream_from :channel do
        Thread.current[:ran_callback] = true
      end
    end
  end

  class MultiChatChannel < ActionCable::Channel::Base
    def subscribed
      stream_from "main_room"
      stream_from "test_all_rooms"
    end
  end

  class StreamFromTest < ActionCable::TestCase
    setup do
      @server = TestServer.new(subscription_adapter: ActionCable::SubscriptionAdapter::Async)
      @server.config.allowed_request_origins = %w( http://rubyonrails.com )
    end

    test "custom encoder" do
      run_in_eventmachine do
        socket = open_socket
        subscribe_to socket, identifiers: { id: 1 }

        socket.websocket.expects(:transmit)
        @server.broadcast "test_room_1", { foo: "bar" }, coder: DummyEncoder
        wait_for_async
        wait_for_executor socket.server.worker_pool.executor
      end
    end

    test "user supplied callbacks are run through the worker pool" do
      run_in_eventmachine do
        socket = open_socket
        receive(socket, command: "subscribe", channel: UserCallbackChannel.name, identifiers: { id: 1 })

        @server.broadcast "channel", {}
        wait_for_async
        refute Thread.current[:ran_callback], "User callback was not run through the worker pool"
      end
    end

    test "subscription confirmation should only be sent out once with muptiple stream_from" do
      run_in_eventmachine do
        socket = open_socket
        expected = { "identifier" => { "channel" => MultiChatChannel.name }.to_json, "type" => "confirm_subscription" }
        socket.websocket.expects(:transmit).with(expected.to_json)
        receive(socket, command: "subscribe", channel: MultiChatChannel.name, identifiers: {})

        wait_for_async
      end
    end

    private
      def subscribe_to(socket, identifiers:)
        receive socket, command: "subscribe", identifiers: identifiers
      end

      def open_socket
        env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket", "HTTP_ORIGIN" => "http://rubyonrails.com"

        Socket.new(@server, env).tap do |socket|
          socket.process
          assert socket.websocket.possible?

          wait_for_async
          assert socket.websocket.alive?
        end
      end

      def receive(socket, command:, identifiers:, channel: "ActionCable::StreamTests::ChatChannel")
        identifier = JSON.generate(channel: channel, **identifiers)
        socket.dispatch_websocket_message JSON.generate(command: command, identifier: identifier)
        wait_for_async
      end
  end
end
