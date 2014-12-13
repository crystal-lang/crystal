require "../../spec_helper"

describe "Normalize: or" do
  it "normalizes or without variable" do
    assert_normalize "a || b", "if __temp_1 = a\n  __temp_1\nelse\n  b\nend"
  end

  it "normalizes or with variable on the left" do
    assert_normalize "a = 1; a || b", "a = 1\nif a\n  a\nelse\n  b\nend"
  end

  it "normalizes or with assignment on the left" do
    assert_normalize "(a = 1) || b", "if a = 1\n  a\nelse\n  b\nend"
  end
end
