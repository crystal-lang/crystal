require "../../spec_helper"

describe "Normalize: chained comparisons" do
  it "normalizes one comparison with literal" do
    assert_normalize "1 <= 2 <= 3", "1 <= 2 && 2 <= 3"
  end

  it "normalizes one comparison with var" do
    assert_normalize "b = 1; 1 <= b <= 3", "b = 1\n1 <= b && b <= 3"
  end

  it "normalizes one comparison with call" do
    assert_normalize "1 <= b <= 3", "1 <= (__temp_1 = b) && __temp_1 <= 3"
  end

  it "normalizes two comparisons with literal" do
    assert_normalize "1 <= 2 <= 3 <= 4", "(1 <= 2 && 2 <= 3) && 3 <= 4"
  end

  it "normalizes two comparisons with calls" do
    assert_normalize "1 <= a <= b <= 4", "(1 <= (__temp_2 = a) && __temp_2 <= (__temp_1 = b)) && __temp_1 <= 4"
  end
end
