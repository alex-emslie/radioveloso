require "cases/helper"
require 'models/binary'

class SanitizeTest < ActiveRecord::TestCase
  def setup
  end

  def test_sanitize_sql_array_handles_string_interpolation
    quoted_bambi = ActiveRecord::Base.connection.quote_string("Bambi")
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=%s", "Bambi"])
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=%s", "Bambi".mb_chars])
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote_string("Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi_and_thumper}",Binary.send(:sanitize_sql_array, ["name=%s", "Bambi\nand\nThumper"])
    assert_equal "name=#{quoted_bambi_and_thumper}",Binary.send(:sanitize_sql_array, ["name=%s", "Bambi\nand\nThumper".mb_chars])
  end

  def test_sanitize_sql_array_handles_bind_variables
    quoted_bambi = ActiveRecord::Base.connection.quote("Bambi")
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi"])
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi".mb_chars])
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote("Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi_and_thumper}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi\nand\nThumper"])
    assert_equal "name=#{quoted_bambi_and_thumper}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi\nand\nThumper".mb_chars])
  end

  def test_sanitize_sql_array_handles_bind_variables_with_quotes
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote("Bambi\nand\nThumper")
    quoted_strs = [ %q{ 'foo?'    },
                    %q{ 'f''oo?'  },
                    %q{ "foo???'" },
                    %q{ 'fo\\'o?' },
                    %q{ `foo\\`?` },
                    %q{ 'fo'' \\\\\\'o?' },
                    ActiveRecord::Base.connection.quote("foo?") ]
    quoted_strs.each do |quoted_str|
      assert_equal "foo=#{quoted_str}, name=#{quoted_bambi_and_thumper}", Binary.send(:sanitize_sql_array, ["foo=#{quoted_str}, name=?", "Bambi\nand\nThumper"])
      assert_equal "foo=#{quoted_str}, name=#{quoted_bambi_and_thumper}", Binary.send(:sanitize_sql_array, ["foo=#{quoted_str}, name=?", "Bambi\nand\nThumper".mb_chars])
    end
  end
end
