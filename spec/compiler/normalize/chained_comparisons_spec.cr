require "../../spec_helper"

describe "Normalize: chained comparisons" do
  it "normalizes one comparison with literal" do
    assert_normalize "1 <= 2 <= 3", "if __temp_1 = 1 <= 2\n  2 <= 3\nelse\n  __temp_1\nend"
  end

  it "normalizes one comparison with var" do
    assert_normalize "b = 1; 1 <= b <= 3", "b = 1\nif __temp_1 = 1 <= b\n  b <= 3\nelse\n  __temp_1\nend"
  end

  it "normalizes one comparison with call" do
    assert_normalize "1 <= b <= 3", "if __temp_2 = 1 <= __temp_1 = b\n  __temp_1 <= 3\nelse\n  __temp_2\nend"
  end

  it "normalizes two comparisons with literal" do
    assert_normalize "1 <= 2 <= 3 <= 4", "if __temp_1 = if __temp_2 = 1 <= 2\n  2 <= 3\nelse\n  __temp_2\nend\n  3 <= 4\nelse\n  __temp_1\nend"
  end

  it "normalizes two comparisons with calls" do
    assert_normalize "1 <= a <= b <= 4", "if __temp_2 = if __temp_4 = 1 <= __temp_3 = a\n  __temp_3 <= __temp_1 = b\nelse\n  __temp_4\nend\n  __temp_1 <= 4\nelse\n  __temp_2\nend"
  end
end
