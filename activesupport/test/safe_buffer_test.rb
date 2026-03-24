require 'abstract_unit'

class SafeBufferTest < ActiveSupport::TestCase
  def setup
    @buffer = ActiveSupport::SafeBuffer.new
  end

  test "Should look like a string" do
    assert @buffer.is_a?(String)
    assert_equal "", @buffer
  end

  test "Should not escape a raw string unless using rails_xss" do
    @buffer << "<script>"
    assert_equal "<script>", @buffer
  end

  test "Should NOT escape a safe value passed to it" do
    @buffer << "<script>".html_safe
    assert_equal "<script>", @buffer
  end

  test "Should not mess with an innocuous string" do
    @buffer << "Hello"
    assert_equal "Hello", @buffer
  end

  test "Should be considered safe" do
    assert @buffer.html_safe?
  end

  test "Should return a safe buffer when calling to_s" do
    new_buffer = @buffer.to_s
    assert_equal ActiveSupport::SafeBuffer, new_buffer.class
  end

  test "Should become unsafe on interpolation" do
    x = 'foo %s'.html_safe
    assert x.html_safe?, "should be safe"

    # formatting with interpolation
    y = x % '<script>alert("lolpwnd");</script>'

    # interpolation makes the string unsafe
    assert y.include?('<script>'), "should have interpolated"
    assert !y.html_safe?, "should not be safe"
  end

end
