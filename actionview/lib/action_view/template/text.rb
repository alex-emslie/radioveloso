module ActionView #:nodoc:
  # = Action View Text Template
  class Template
    class Text #:nodoc:
      attr_accessor :type

      def initialize(string, type = nil)
        @string = string.to_s
        @type = if type
          Types[type] || type
        else
          Types[:text]
        end
      end

      def identifier
        "text template"
      end

      alias_method :inspect, :identifier

      def to_str
        @string
      end

      def render(*args)
        to_str
      end

      def formats
        [@type.respond_to?(:ref) ? @type.ref : @type.to_s]
      end
    end
  end
end
