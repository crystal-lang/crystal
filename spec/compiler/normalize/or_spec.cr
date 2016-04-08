require "../../spec_helper"

describe "Normalize: or" do
  it "normalizes or without variable" do
    assert_expand "a || b", "if __temp_1 = a\n  __temp_1\nelse\n  b\nend"
  end

  it "normalizes or with variable on the left" do
    assert_expand_second "a = 1; a || b", "if a\n  a\nelse\n  b\nend"
  end

  it "normalizes or with assignment on the left" do
    assert_expand "(a = 1) || b", "if a = 1\n  a\nelse\n  b\nend"
  end

  it "normalizes or with is_a? on var" do
    assert_expand_second "a = 1; a.is_a?(Foo) || b", "if a.is_a?(Foo)\n  a.is_a?(Foo)\nelse\n  b\nend"
  end

  it "normalizes or with ! on var" do
    assert_expand_second "a = 1; !a || b", "if !a\n  !a\nelse\n  b\nend"
  end

  it "normalizes or with ! on var.is_a?(...)" do
    assert_expand_second "a = 1; !a.is_a?(Int32) || b", "if !a.is_a?(Int32)\n  !a.is_a?(Int32)\nelse\n  b\nend"
  end
end
