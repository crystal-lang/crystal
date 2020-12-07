require "../../spec_helper"

private def assert_after_cleanup(before, after)
  node = Parser.parse(before)
  result = semantic node
  result.node.to_s.strip.should eq(after.strip)
end

describe "cleanup" do
  it "errors if assigning var to itself" do
    assert_error "a = 1; a = a", "expression has no effect"
  end

  it "errors if assigning instance var to itself" do
    assert_error %(
      class Foo
        def initialize
          @a = 1; @a = @a
        end
      end
      Foo.new
      ), "expression has no effect"
  end

  it "strip tuple elements after unreachable element" do
    assert_after_cleanup "{1, while true; end, 2}", "1\nwhile true\nend"
  end

  it "strip named-tuple elements after unreachable element" do
    assert_after_cleanup "{foo: 1, bar: while true; end, baz: 2}", "1\nwhile true\nend"
  end

  # it "errors comparison of unsigned integer with zero or negative literal" do
  #   error = "comparison of unsigned integer with zero or negative literal will always be false"
  #   assert_error "1_u32 < 0", error
  #   assert_error "1_u32 <= -1", error
  #   assert_error "0 > 1_u32", error
  #   assert_error "-1 >= 1_u32", error
  # end
end
