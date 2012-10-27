require "cases/helper"

module ActiveRecord
  class Base
    class ConnectionSpecification
      class ResolverTest < ActiveRecord::TestCase
        def resolve(spec)
          Resolver.new(spec, {}).spec.config
        end

        def with_database_url(new_url)
          old_url, ENV['DATABASE_URL'] = ENV['DATABASE_URL'], new_url
          yield
        ensure
          old_url ? ENV['DATABASE_URL'] = old_url : ENV.delete('DATABASE_URL')
        end

        def test_url_host_no_db
          skip "only if mysql is available" unless defined?(MysqlAdapter)
          spec = resolve 'mysql://foo?encoding=utf8'
          assert_equal({
            :adapter  => "mysql",
            :database => "",
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end

        def test_url_host_db
          skip "only if mysql is available" unless defined?(MysqlAdapter)
          spec = resolve 'mysql://foo/bar?encoding=utf8'
          assert_equal({
            :adapter  => "mysql",
            :database => "bar",
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end

        def test_url_port
          skip "only if mysql is available" unless defined?(MysqlAdapter)
          spec = resolve 'mysql://foo:123?encoding=utf8'
          assert_equal({
            :adapter  => "mysql",
            :database => "",
            :port     => 123,
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end

        def test_url_no_database_yml
          with_database_url 'sqlite3://localhost/db/production.sqlite3' do
            spec = resolve ENV["DATABASE_URL"]
            assert_equal({
              :adapter  => "sqlite3",
              :database => "db/production.sqlite3",
              :host     => "localhost" }, spec)
            spec = resolve 'production'
            assert_equal({
              :adapter  => "sqlite3",
              :database => "db/production.sqlite3",
              :host     => "localhost" }, spec)
          end
        end
      end
    end
  end
end
