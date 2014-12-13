require "../../spec_helper"

describe "Normalize: and" do
  it "normalizes and without variable" do
    assert_normalize "a && b", "if __temp_1 = a\n  b\nelse\n  __temp_1\nend"
  end

  it "normalizes and with variable on the left" do
    assert_normalize "a = 1; a && b", "a = 1\nif a\n  b\nelse\n  a\nend"
  end

  it "normalizes and with is_a? on var" do
    assert_normalize "a = 1; a.is_a?(Foo) && b", "a = 1\nif a.is_a?(Foo)\n  b\nelse\n  a.is_a?(Foo)\nend"
  end

  it "normalizes and with is_a? on exp" do
    assert_normalize "a = 1; 1.is_a?(Foo) && b", "a = 1\nif __temp_1 = 1.is_a?(Foo)\n  b\nelse\n  __temp_1\nend"
  end

  it "normalizes and with assignment" do
    assert_normalize "(a = 1) && b", "if a = 1\n  b\nelse\n  a\nend"
  end
end
