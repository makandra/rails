require "cases/helper"
require 'models/bird'
require 'bigdecimal'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class QuotingTest < ActiveRecord::TestCase
        def setup
          @conn = ActiveRecord::Base.connection
          @raise_int_wider_than_64bit = ActiveRecord::Base.raise_int_wider_than_64bit
        end

        def test_quote_true
          c = PostgreSQLColumn.new(nil, 1, 'boolean')
          assert_equal "'t'", @conn.quote(true, nil)
          assert_equal "'t'", @conn.quote(true, c)
        end

        def test_quote_false
          c = PostgreSQLColumn.new(nil, 1, 'boolean')
          assert_equal "'f'", @conn.quote(false, nil)
          assert_equal "'f'", @conn.quote(false, c)
        end

        def test_quote_range
          # There is no range support on 2.3's PG adapter, but we still want to
          # make sure that SQL injection is not possible since it was an issue
          # on Rails 4.x.
          # https://groups.google.com/d/msg/rubyonrails-security/wDxePLJGZdI/WP7EasCJTA4J
          #
          # Note that we can not test this using Connection#quote because
          # ActiveRecord expands ranges into two bind variables that are
          # quoted individually.
          range = "1,2]'; SELECT * FROM users; --".."a"
          sql = Bird.scoped(:conditions => { :name => range }).construct_finder_sql({})
          expected_sql = %{SELECT * FROM "birds" WHERE ("birds"."name" BETWEEN '1,2]''; SELECT * FROM users; --' AND 'a') }
          assert_equal expected_sql, sql
        end

        def test_quote_bit_string
          c = PostgreSQLColumn.new(nil, 1, 'bit')
          assert_equal nil, @conn.quote("'); SELECT * FORM users; /*\n01\n*/--", c)
        end

        def test_raise_when_int_is_wider_than_64bit
          value = 9223372036854775807 + 1
          assert_raise ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::IntegerOutOf64BitRange do
            @conn.quote(value)
          end

          value = -9223372036854775808 - 1
          assert_raise ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::IntegerOutOf64BitRange do
            @conn.quote(value)
          end
        end

        def test_do_not_raise_when_int_is_not_wider_than_64bit
          value = 9223372036854775807
          assert_equal "9223372036854775807", @conn.quote(value)

          value = -9223372036854775808
          assert_equal "-9223372036854775808", @conn.quote(value)
        end

        def test_do_not_raise_when_raise_int_wider_than_64bit_is_false
          ActiveRecord::Base.raise_int_wider_than_64bit = false
          value = 9223372036854775807 + 1
          assert_equal "9223372036854775808", @conn.quote(value)
        ensure
          ActiveRecord::Base.raise_int_wider_than_64bit = @raise_int_wider_than_64bit
        end

        def test_raise_when_string_int_is_wider_than_64bit
          c = PostgreSQLColumn.new(nil, nil, 'integer')
          value = '9223372036854775808'
          assert_raise ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::IntegerOutOf64BitRange do
            @conn.quote(value, c)
          end

          value = '-9223372036854775809'
          assert_raise ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::IntegerOutOf64BitRange do
            @conn.quote(value, c)
          end
        end

        def test_do_not_raise_for_string_int_at_64bit_boundary
          c = PostgreSQLColumn.new(nil, nil, 'integer')
          assert_equal "9223372036854775807", @conn.quote('9223372036854775807', c)
          assert_equal "-9223372036854775808", @conn.quote('-9223372036854775808', c)
        end

        def test_do_not_raise_for_string_int_wider_than_64bit_when_disabled
          ActiveRecord::Base.raise_int_wider_than_64bit = false
          c = PostgreSQLColumn.new(nil, nil, 'integer')
          assert_equal "9223372036854775808", @conn.quote('9223372036854775808', c)
        ensure
          ActiveRecord::Base.raise_int_wider_than_64bit = @raise_int_wider_than_64bit
        end
      end

      class IntegerOutOf64BitRangeIntegrationTest < ActiveRecord::TestCase
        TOO_BIG           =  99999999999999999999
        TOO_BIG_STR       = '99999999999999999999'
        TOO_SMALL         =  -99999999999999999999
        TOO_SMALL_STR     = '-99999999999999999999'
        TOO_BIG_FLOAT     =  TOO_BIG.to_f
        TOO_BIG_DECIMAL   =  BigDecimal('99999999999999999999')

        def setup
          @connection = ActiveRecord::Base.connection
          @connection.execute('drop table if exists ex_int_range')
          @connection.execute('create table ex_int_range (id serial primary key, int_val integer, bigint_val bigint, decimal_val decimal, float_val float)')
          @klass = Class.new(ActiveRecord::Base) { self.table_name = 'ex_int_range' }
        end

        def teardown
          @connection.execute('drop table if exists ex_int_range') rescue nil
        end

        def test_find_with_integer_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(TOO_BIG)
          end
        end

        def test_find_with_string_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(TOO_BIG_STR)
          end
        end

        def test_where_hash_with_integer_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(:all, :conditions => { :id => TOO_BIG })
          end
        end

        def test_where_hash_with_string_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(:all, :conditions => { :id => TOO_BIG_STR })
          end
        end

        def test_where_sql_placeholder_with_integer_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(:all, :conditions => ['id = ?', TOO_BIG])
          end
        end

        def test_where_sql_placeholder_with_string_raises
          assert_raise ActiveRecord::StatementInvalid do
            @klass.find(:all, :conditions => ['id = ?', TOO_BIG_STR])
          end
        end

        def test_where_sql_named_placeholder_with_string_raises
          assert_raise ActiveRecord::StatementInvalid do
            @klass.find(:all, :conditions => ['id = :id', { :id => TOO_BIG_STR }])
          end
        end

        def test_where_hash_with_integer_array_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(:all, :conditions => { :id => [TOO_BIG, TOO_SMALL] })
          end
        end

        def test_where_hash_with_string_array_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(:all, :conditions => { :id => [TOO_BIG_STR, TOO_SMALL_STR] })
          end
        end

        def test_where_hash_with_qualified_integer_column_and_string_raises
          assert_raise ActiveRecord::StatementInvalid do
            @klass.find(:all, :conditions => { 'ex_int_range.id' => TOO_BIG_STR })
          end
        end

        def test_where_hash_with_bigint_column_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(:all, :conditions => { :bigint_val => TOO_BIG })
          end
        end

        def test_where_hash_with_float_value_on_integer_column_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(:all, :conditions => { :id => TOO_BIG_FLOAT })
          end
        end

        def test_where_hash_with_big_decimal_value_on_integer_column_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(:all, :conditions => { :id => TOO_BIG_DECIMAL })
          end
        end

        def test_find_first_with_big_decimal_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(:first, :conditions => { :id => TOO_BIG_DECIMAL })
          end
        end

        def test_find_last_with_big_decimal_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(:last, :conditions => { :id => TOO_BIG_DECIMAL })
          end
        end

        def test_find_with_float_raises
          assert_raise IntegerOutOf64BitRange do
            @klass.find(TOO_BIG_FLOAT)
          end
        end

        def test_find_with_big_decimal_raises
          assert_raise ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::IntegerOutOf64BitRange do
            @klass.find(TOO_BIG_DECIMAL)
          end
        end

        def test_big_integer_against_decimal_column_does_not_raise
          assert_nothing_raised do
            @klass.find(:all, :conditions => { :decimal_val => TOO_BIG })
            @klass.find(:all, :conditions => { :decimal_val => TOO_BIG_STR })
            @klass.find(:all, :conditions => { :decimal_val => TOO_BIG_FLOAT })
            @klass.find(:all, :conditions => { :decimal_val => TOO_BIG_DECIMAL })
          end
        end

        def test_big_integer_against_float_column_does_not_raise
          assert_nothing_raised do
            @klass.find(:all, :conditions => { :float_val => TOO_BIG })
            @klass.find(:all, :conditions => { :float_val => TOO_BIG_STR })
            @klass.find(:all, :conditions => { :float_val => TOO_BIG_FLOAT })
            @klass.find(:all, :conditions => { :float_val => TOO_BIG_DECIMAL })
          end
        end

        def test_update_all_with_string_for_integer_column_raises
          assert_raise ActiveRecord::StatementInvalid do
            @klass.update_all({ :int_val => TOO_BIG_STR })
          end
        end
      end
    end
  end
end
