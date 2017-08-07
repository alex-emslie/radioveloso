# frozen_string_literal: true

module ActionDispatch
  module Journey # :nodoc:
    class Router # :nodoc:
      class Utils # :nodoc:
        # Normalizes URI path.
        #
        # Strips off trailing slash and ensures there is a leading slash.
        # Also converts downcase URL encoded string to uppercase.
        #
        #   normalize_path("/foo")  # => "/foo"
        #   normalize_path("/foo/") # => "/foo"
        #   normalize_path("foo")   # => "/foo"
        #   normalize_path("")      # => "/"
        #   normalize_path("/%ab")  # => "/%AB"
        def self.normalize_path(path)
          path ||= ""
          encoding = path.encoding
          path = "/#{path}".dup
          path.squeeze!("/".freeze)
          path.sub!(%r{/+\Z}, "".freeze)
          path.gsub!(/(%[a-f0-9]{2})/) { $1.upcase }
          path = "/".dup if path == "".freeze
          path.force_encoding(encoding)
          path
        end

        # URI path and fragment escaping
        # http://tools.ietf.org/html/rfc3986
        class UriEncoder # :nodoc:
          ENCODE   = "%%%02X".freeze
          US_ASCII = Encoding::US_ASCII
	  ASCII_8  = Encoding::ASCII_8BIT
          UTF_8    = Encoding::UTF_8
          EMPTY    = "".dup.force_encoding(US_ASCII).freeze
          DEC2HEX  = (0..255).to_a.map { |i| ENCODE % i }.map { |s| s.force_encoding(US_ASCII) }

          ALPHA = "a-zA-Z".freeze
          DIGIT = "0-9".freeze
          UNRESERVED = "#{ALPHA}#{DIGIT}\\-\\._~".freeze
          SUB_DELIMS = "!\\$&'\\(\\)\\*\\+,;=".freeze

          ESCAPED  = /%[a-zA-Z0-9]{2}/.freeze

          FRAGMENT = /[^#{UNRESERVED}#{SUB_DELIMS}:@\/\?]/.freeze
          SEGMENT  = /[^#{UNRESERVED}#{SUB_DELIMS}:@]/.freeze
          PATH     = /[^#{UNRESERVED}#{SUB_DELIMS}:@\/]/.freeze

          def escape_fragment(fragment)
            escape(fragment, FRAGMENT)
          end

          def escape_path(path)
            escape(path, PATH)
          end

          def escape_segment(segment)
            escape(segment, SEGMENT)
          end

          def unescape_uri(uri)
            encoding = uri.encoding
	    encoding = UTF_8 if ( encoding == US_ASCII || encoding == ASCII_8 )
            uri.gsub(ESCAPED) { |match| [match[1, 2].hex].pack("C") }.force_encoding(encoding)
          end

          private
            def escape(component, pattern)
              component.gsub(pattern) { |unsafe| percent_encode(unsafe) }.force_encoding(US_ASCII)
            end

            def percent_encode(unsafe)
              safe = EMPTY.dup
              unsafe.each_byte { |b| safe << DEC2HEX[b] }
              safe
            end
        end

        ENCODER = UriEncoder.new

        def self.escape_path(path)
          ENCODER.escape_path(path.to_s)
        end

        def self.escape_segment(segment)
          ENCODER.escape_segment(segment.to_s)
        end

        def self.escape_fragment(fragment)
          ENCODER.escape_fragment(fragment.to_s)
        end

        # Replaces any escaped sequences with their unescaped representations.
        #
        #   uri = "/topics?title=Ruby%20on%20Rails"
        #   unescape_uri(uri)  #=> "/topics?title=Ruby on Rails"
        def self.unescape_uri(uri)
          ENCODER.unescape_uri(uri)
        end
      end
    end
  end
end
