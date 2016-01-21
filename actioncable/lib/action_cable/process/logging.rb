require 'action_cable/server'

if defined?(::EventMachine)
  EventMachine.error_handler do |e|
    puts "Error raised inside the event loop: #{e.message}"
    puts e.backtrace.join("\n")
  end
end
