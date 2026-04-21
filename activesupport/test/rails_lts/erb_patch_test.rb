require 'abstract_unit'

class ErbPatchTest < ActiveSupport::TestCase
  test "ERB.new result still works" do
    assert_equal "hello", ERB.new("hello").result
  end

  test "uninitialized ERB cannot call result (CVE-2026-41316)" do
    erb = ERB.allocate
    erb.instance_variable_set(:@src, '"hello"')
    assert_raises(ArgumentError) { erb.result }
  end

  test "uninitialized ERB cannot call def_method (CVE-2026-41316)" do
    erb = ERB.allocate
    erb.instance_variable_set(:@src, '"hello"')
    assert_raises(ArgumentError) { erb.def_method(Module.new, 'test_method') }
  end
end
