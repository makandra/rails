require 'abstract_unit'
require 'timeout'

class NumberHelperTest < ActionView::TestCase
  tests ActionView::Helpers::NumberHelper


  def test_number_helpers_escape_delimiter_and_separator
    # html-escaping the right side is fine, since we only have a problem if the helper does
    # not escape AND return a safe string

    assert_equal "111&lt;script&gt;&lt;/script&gt;111&lt;script&gt;&lt;/script&gt;1111", ERB::Util.html_escape(number_to_phone(1111111111, :delimiter => "<script></script>"))

    assert_equal "$1&lt;script&gt;&lt;/script&gt;01", ERB::Util.html_escape(number_to_currency(1.01, :separator => "<script></script>"))
    assert_equal "$1&lt;script&gt;&lt;/script&gt;000.00", ERB::Util.html_escape(number_to_currency(1000, :delimiter => "<script></script>"))

    assert_equal "1&lt;script&gt;&lt;/script&gt;010%", ERB::Util.html_escape(number_to_percentage(1.01, :separator => "<script></script>"))
    assert_equal "1&lt;script&gt;&lt;/script&gt;000.000%", ERB::Util.html_escape(number_to_percentage(1000, :delimiter => "<script></script>"))

    assert_equal "1&lt;script&gt;&lt;/script&gt;01", ERB::Util.html_escape(number_with_delimiter(1.01, :separator => "<script></script>"))
    assert_equal "1&lt;script&gt;&lt;/script&gt;000", ERB::Util.html_escape(number_with_delimiter(1000, :delimiter => "<script></script>"))

    assert_equal "1&lt;script&gt;&lt;/script&gt;010", ERB::Util.html_escape(number_with_precision(1.01, :separator => "<script></script>"))
    assert_equal "1&lt;script&gt;&lt;/script&gt;000.000", ERB::Util.html_escape(number_with_precision(1000, :delimiter => "<script></script>"))

    assert_equal "9&lt;script&gt;&lt;/script&gt;9 KB", ERB::Util.html_escape(number_to_human_size(10100, :separator => "<script></script>"))
  end

  def test_number_to_phone
    assert_equal("555-1234", number_to_phone(5551234))
    assert_equal("800-555-1212", number_to_phone(8005551212))
    assert_equal("(800) 555-1212", number_to_phone(8005551212, {:area_code => true}))
    assert_equal("800 555 1212", number_to_phone(8005551212, {:delimiter => " "}))
    assert_equal("(800) 555-1212 x 123", number_to_phone(8005551212, {:area_code => true, :extension => 123}))
    assert_equal("800-555-1212", number_to_phone(8005551212, :extension => "  "))
    assert_equal("800-555-1212", number_to_phone("8005551212"))
    assert_equal("+1-800-555-1212", number_to_phone(8005551212, :country_code => 1))
    assert_equal("+18005551212", number_to_phone(8005551212, :country_code => 1, :delimiter => ''))
    assert_equal("22-555-1212", number_to_phone(225551212))
    assert_equal("+45-22-555-1212", number_to_phone(225551212, :country_code => 45))
    assert_equal "+&lt;script&gt;&lt;/script&gt;8005551212", ERB::Util.html_escape(number_to_phone(8005551212, :country_code => "<script></script>", :delimiter => ""))
    assert_equal "8005551212 x &lt;script&gt;&lt;/script&gt;", ERB::Util.html_escape(number_to_phone(8005551212, :extension => "<script></script>", :delimiter => ""))
    assert_equal("x", number_to_phone("x"))
    assert_nil number_to_phone(nil)
  end

  def test_number_to_currency
    assert_equal("$1,234,567,890.50", number_to_currency(1234567890.50))
    assert_equal("$1,234,567,890.51", number_to_currency(1234567890.506))
    assert_equal("$1,234,567,892", number_to_currency(1234567891.50, {:precision => 0}))
    assert_equal("$1,234,567,890.5", number_to_currency(1234567890.50, {:precision => 1}))
    assert_equal("&pound;1234567890,50", number_to_currency(1234567890.50, {:unit => raw("&pound;"), :separator => ",", :delimiter => ""}))
    assert_equal("&amp;pound;1234567890,50", number_to_currency(1234567890.50, {:unit => "&pound;", :separator => ",", :delimiter => ""}))
    assert_equal("$1,234,567,890.50", number_to_currency("1234567890.50"))
    assert_equal("1,234,567,890.50 K&#269;", number_to_currency("1234567890.50", {:unit => raw("K&#269;"), :format => "%n %u"}))
    assert_equal "&lt;b&gt;1,234,567,890.50&lt;/b&gt; $", ERB::Util.html_escape(number_to_currency("1234567890.50", :format => "<b>%n</b> %u"))
    #assert_equal("$x.", number_to_currency("x")) # fails due to API consolidation
    assert_equal("$x", number_to_currency("x"))
    assert_nil number_to_currency(nil)
    assert number_to_currency(1234).html_safe?
  end

  def test_number_to_percentage
    assert_equal("100.000%", number_to_percentage(100))
    assert_equal("100%", number_to_percentage(100, {:precision => 0}))
    assert_equal("302.06%", number_to_percentage(302.0574, {:precision => 2}))
    assert_equal("100.000%", number_to_percentage("100"))
    assert_equal("1000.000%", number_to_percentage("1000"))
    assert_equal("x%", number_to_percentage("x"))
    assert_equal("1.000,000%", number_to_percentage(1000, :delimiter => '.', :separator => ','))
    assert_nil number_to_percentage(nil)
  end

  def test_number_with_delimiter
    assert_equal("12,345,678", number_with_delimiter(12345678))
    assert_equal("0", number_with_delimiter(0))
    assert_equal("123", number_with_delimiter(123))
    assert_equal("1,234", number_with_delimiter(1234))
    assert_equal("12,345", number_with_delimiter(12345))
    assert_equal("123,456", number_with_delimiter(123456))
    assert_equal("123,456.78", number_with_delimiter(123456.78))
    assert_equal("123,456.789", number_with_delimiter(123456.789))
    assert_equal("123,456.78901", number_with_delimiter(123456.78901))
    assert_equal("123,456,789.78901", number_with_delimiter(123456789.78901))
    assert_equal("0.78901", number_with_delimiter(0.78901))
    assert_equal("123,456.78", number_with_delimiter("123456.78"))
    assert_equal("x", number_with_delimiter("x"))
    assert_nil number_with_delimiter(nil)
  end

  def test_to_delimited_is_not_vulnerable_to_redos_cve_2026_33169
    evil_string = "1" * 50_000

    Timeout.timeout(1) do
      number_with_delimiter(evil_string)
    end

    assert true, "number_with_delimiter timed out on a large string, indicating possible ReDoS"
  end

  def test_to_delimited_with_decimals_is_not_vulnerable_to_redos
    evil_decimal_string = "1" * 50_000 + "." + "2" * 50_000

    Timeout.timeout(1) do
      number_with_delimiter(evil_decimal_string)
    end

    assert true
  end

  def test_number_with_delimiter_with_options_hash
    assert_equal '12 345 678', number_with_delimiter(12345678, :delimiter => ' ')
    assert_equal '12,345,678-05', number_with_delimiter(12345678.05, :separator => '-')
    assert_equal '12.345.678,05', number_with_delimiter(12345678.05, :separator => ',', :delimiter => '.')
    assert_equal '12.345.678,05', number_with_delimiter(12345678.05, :delimiter => '.', :separator => ',')
  end

  def test_number_with_precision
    assert_equal("111.235", number_with_precision(111.2346))
    assert_equal("31.83", number_with_precision(31.825, :precision => 2))
    assert_equal("111.23", number_with_precision(111.2346, :precision => 2))
    assert_equal("111.00", number_with_precision(111, :precision => 2))
    assert_equal("111.235", number_with_precision("111.2346"))
    assert_equal("31.83", number_with_precision("31.825", :precision => 2))
    assert_equal("112", number_with_precision(111.50, :precision => 0))
    assert_equal("1234567892", number_with_precision(1234567891.50, :precision => 0))

    # Return non-numeric params unchanged.
    assert_equal("x", number_with_precision("x"))
    assert_nil number_with_precision(nil)
  end

  def test_number_with_precision_with_custom_delimiter_and_separator
    assert_equal '31,83',       number_with_precision(31.825, :precision => 2, :separator => ',')
    assert_equal '1.231,83',    number_with_precision(1231.825, :precision => 2, :separator => ',', :delimiter => '.')
  end

  def test_number_to_human_size
    assert_equal '0 Bytes',   number_to_human_size(0)
    assert_equal '1 Byte',    number_to_human_size(1)
    assert_equal '3 Bytes',   number_to_human_size(3.14159265)
    assert_equal '123 Bytes', number_to_human_size(123.0)
    assert_equal '123 Bytes', number_to_human_size(123)
    assert_equal '1.2 KB',    number_to_human_size(1234)
    assert_equal '12.1 KB',   number_to_human_size(12345)
    assert_equal '1.2 MB',    number_to_human_size(1234567)
    assert_equal '1.1 GB',    number_to_human_size(1234567890)
    assert_equal '1.1 TB',    number_to_human_size(1234567890123)
    assert_equal '1025 TB',   number_to_human_size(1025.terabytes)
    assert_equal '444 KB',    number_to_human_size(444.kilobytes)
    assert_equal '1023 MB',   number_to_human_size(1023.megabytes)
    assert_equal '3 TB',      number_to_human_size(3.terabytes)
    assert_equal '1.18 MB',   number_to_human_size(1234567, :precision => 2)
    assert_equal '3 Bytes',   number_to_human_size(3.14159265, :precision => 4)
    assert_equal("123 Bytes", number_to_human_size("123"))
    assert_equal '1.01 KB',   number_to_human_size(1.0123.kilobytes, :precision => 2)
    assert_equal '1.01 KB',   number_to_human_size(1.0100.kilobytes, :precision => 4)
    assert_equal '10 KB',   number_to_human_size(10.000.kilobytes, :precision => 4)
    assert_equal '1 Byte',   number_to_human_size(1.1)
    assert_equal '10 Bytes', number_to_human_size(10)
    #assert_nil number_to_human_size('x') # fails due to API consolidation
    assert_nil number_to_human_size(nil)
  end

  def test_number_to_human_size_with_options_hash
    assert_equal '1.18 MB',   number_to_human_size(1234567, :precision => 2)
    assert_equal '3 Bytes',   number_to_human_size(3.14159265, :precision => 4)
    assert_equal '1.01 KB',   number_to_human_size(1.0123.kilobytes, :precision => 2)
    assert_equal '1.01 KB',   number_to_human_size(1.0100.kilobytes, :precision => 4)
    assert_equal '10 KB',     number_to_human_size(10.000.kilobytes, :precision => 4)
    assert_equal '1 TB', number_to_human_size(1234567890123, :precision => 0)
    assert_equal '500 MB', number_to_human_size(524288000, :precision=>0)
    assert_equal '40 KB', number_to_human_size(41010, :precision => 0)
    assert_equal '40 KB', number_to_human_size(41100, :precision => 0)
  end

  def test_number_to_human_size_with_custom_delimiter_and_separator
    assert_equal '1,01 KB',     number_to_human_size(1.0123.kilobytes, :precision => 2, :separator => ',')
    assert_equal '1,01 KB',     number_to_human_size(1.0100.kilobytes, :precision => 4, :separator => ',')
    assert_equal '1.000,1 TB',  number_to_human_size(1000.1.terabytes, :delimiter => '.', :separator => ',')
  end

  def test_number_helpers_with_scientific_notation
      assert_nothing_raised do
        Timeout.timeout(1) do
          assert_equal "$123481223d98989", number_to_currency("123481223d98989")
          assert_equal "$11288E822220222", number_to_currency("11288E822220222")
          assert_equal "$-888E89789", number_to_currency("-888E89789")

          assert_equal "123481223d98989%", number_to_percentage("123481223d98989")
          assert_equal "11288E822220222%", number_to_percentage("11288E822220222")
          assert_equal "-888E89789%", number_to_percentage("-888E89789")

          assert_equal "123481223d98989", number_with_precision("123481223d98989")
          assert_equal "11288E822220222", number_with_precision("11288E822220222")
          assert_equal "-888E89789", number_with_precision("-888E89789")

          assert_equal "123481223d98989", number_to_human_size("123481223d98989")
          assert_equal "11288E822220222", number_to_human_size("11288E822220222")
          assert_equal "-888E89789", number_to_human_size("-888E89789")

          number_to_phone("123481223d98989")
          number_to_phone("11288E822220222")
          number_to_phone("-888E89789")
        end
      end
  end

end
