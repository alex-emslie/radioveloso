# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/module/attribute_accessors"
require "uri/generic"

module ActionDispatch
  module Http
    class URI
      IP_HOST_REGEXP  = /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
      HOST_REGEXP     = /(^[^:]+:\/\/)?(\[[^\]]+\]|[^:]+)(?::(\d+$))?/
      PROTOCOL_REGEXP = /^([^:]+)(:)?(\/\/)?$/

      mattr_accessor :secure_protocol, default: false
      mattr_accessor :tld_length, default: 1

      delegate :scheme, :host, :port, :path, :query, :fragment, :to_s, to: :@uri

      class << self
        # Returns the domain part of a host given the domain level.
        #
        #    # Top-level domain example
        #    extract_domain('www.example.com', 1) # => "example.com"
        #    # Second-level domain example
        #    extract_domain('dev.www.example.co.uk', 2) # => "example.co.uk"
        def extract_domain(host, tld_length)
          extract_domain_from(host, tld_length) if named_host?(host)
        end

        # Returns the subdomains of a host as an Array given the domain level.
        #
        #    # Top-level domain example
        #    extract_subdomains('www.example.com', 1) # => ["www"]
        #    # Second-level domain example
        #    extract_subdomains('dev.www.example.co.uk', 2) # => ["dev", "www"]
        def extract_subdomains(host, tld_length)
          if named_host?(host)
            extract_subdomains_from(host, tld_length)
          else
            []
          end
        end

        # Returns the subdomains of a host as a String given the domain level.
        #
        #    # Top-level domain example
        #    extract_subdomain('www.example.com', 1) # => "www"
        #    # Second-level domain example
        #    extract_subdomain('dev.www.example.co.uk', 2) # => "dev.www"
        def extract_subdomain(host, tld_length)
          extract_subdomains(host, tld_length).join(".")
        end

        def url_for(options)
          if options[:only_path]
            path_for options
          else
            full_url_for options
          end
        end

        def full_url_for(options)
          host     = options[:host]
          protocol = options[:protocol]
          port     = options[:port]

          unless host
            raise ArgumentError, "Missing host to link to! Please provide the :host parameter, set default_url_options[:host], or set :only_path to true"
          end

          build_host_url(host, port, protocol, options, path_for(options))
        end

        def path_for(options)
          path = options[:script_name].to_s.chomp("/")
          path << options[:path] if options.key?(:path)

          path = "/" if options[:trailing_slash] && path.blank?

          add_params(path, options[:params]) if options.key?(:params)
          add_anchor(path, options[:anchor]) if options.key?(:anchor)

          path
        end

        private
          def add_params(path, params)
            params = { params: params } unless params.is_a?(Hash)
            params.reject! { |_, v| v.to_param.nil? }
            query = params.to_query
            path << "?#{query}" unless query.empty?
          end

          def add_anchor(path, anchor)
            if anchor
              path << "##{ActionDispatch::Journey::Router::Utils.escape_fragment(anchor.to_param)}"
            end
          end

          def extract_domain_from(host, tld_length)
            host.split(".").last(1 + tld_length).join(".")
          end

          def extract_subdomains_from(host, tld_length)
            parts = host.split(".")
            parts[0..-(tld_length + 2)]
          end

          def build_host_url(host, port, protocol, options, path)
            if match = host.match(HOST_REGEXP)
              protocol ||= match[1] unless protocol == false
              host       = match[2]
              port       = match[3] unless options.key? :port
            end

            protocol = normalize_protocol protocol
            host     = normalize_host(host, options)

            result = protocol.dup

            if options[:user] && options[:password]
              result << "#{Rack::Utils.escape(options[:user])}:#{Rack::Utils.escape(options[:password])}@"
            end

            result << host
            normalize_port(port, protocol) { |normalized_port|
              result << ":#{normalized_port}"
            }

            result.concat path
          end

          def named_host?(host)
            !IP_HOST_REGEXP.match?(host)
          end

          def normalize_protocol(protocol)
            case protocol
            when nil
              secure_protocol ? "https://" : "http://"
            when false, "//"
              "//"
            when PROTOCOL_REGEXP
              "#{$1}://"
            else
              raise ArgumentError, "Invalid :protocol option: #{protocol.inspect}"
            end
          end

          def normalize_host(_host, options)
            return _host unless named_host?(_host)

            tld_length = options[:tld_length] || @@tld_length
            subdomain  = options.fetch :subdomain, true
            domain     = options[:domain]

            host = +""
            if subdomain == true
              return _host if domain.nil?

              host << extract_subdomains_from(_host, tld_length).join(".")
            elsif subdomain
              host << subdomain.to_param
            end
            host << "." unless host.empty?
            host << (domain || extract_domain_from(_host, tld_length))
            host
          end

          def normalize_port(port, protocol)
            return unless port

            case protocol
            when "//" then yield port
            when "https://"
              yield port unless port.to_i == 443
            else
              yield port unless port.to_i == 80
            end
          end
      end

      def initialize(uri_string)
        @uri = ::URI.parse(uri_string)
      end

      def protocol
        "#{scheme}://"
      end

      # Returns the \domain part of a \host, such as "rubyonrails.org" in "www.rubyonrails.org". You can specify
      # a different <tt>tld_length</tt>, such as 2 to catch rubyonrails.co.uk in "www.rubyonrails.co.uk".
      def domain(tld_length = @@tld_length)
        self.class.extract_domain(host, tld_length)
      end

      # Returns all the \subdomains as an array, so <tt>["dev", "www"]</tt> would be
      # returned for "dev.www.rubyonrails.org". You can specify a different <tt>tld_length</tt>,
      # such as 2 to catch <tt>["www"]</tt> instead of <tt>["www", "rubyonrails"]</tt>
      # in "www.rubyonrails.co.uk".
      def subdomains(tld_length = @@tld_length)
        self.class.extract_subdomains(host, tld_length)
      end

      # Returns all the \subdomains as a string, so <tt>"dev.www"</tt> would be
      # returned for "dev.www.rubyonrails.org". You can specify a different <tt>tld_length</tt>,
      # such as 2 to catch <tt>"www"</tt> instead of <tt>"www.rubyonrails"</tt>
      # in "www.rubyonrails.co.uk".
      def subdomain(tld_length = @@tld_length)
        self.class.extract_subdomain(host, tld_length)
      end
    end
  end
end
