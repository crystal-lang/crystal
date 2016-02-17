require "../../spec_helper"

describe "Normalize: multi assign" do
  it "normalizes n to n" do
    assert_normalize "a, b, c = 1, 2, 3", "__temp_1 = 1\n__temp_2 = 2\n__temp_3 = 3\na = __temp_1\nb = __temp_2\nc = __temp_3"
  end

  it "normalizes n to n with constants" do
    assert_normalize "a, B, C = 1, 2, 3", "__temp_1 = 1\na = __temp_1\nB = 2\nC = 3"
  end

  it "normalizes 1 to n" do
    assert_normalize "d = 1\na, b, c = d", "d = 1\n__temp_1 = d\na = __temp_1[0]\nb = __temp_1[1]\nc = __temp_1[2]"
  end

  it "normalizes n to 1" do
    assert_normalize "a = 1, 2", "a = [1, 2]"
  end

  it "normalizes n to n with []" do
    assert_normalize "a = 1; b = 2; a[0], b[1] = 2, 3", "a = 1\nb = 2\n__temp_1 = 2\n__temp_2 = 3\na[0] = __temp_1\nb[1] = __temp_2"
  end

  it "normalizes 1 to n with []" do
    assert_normalize "a = 1; b = 2; a[0], b[1] = 2", "a = 1\nb = 2\n__temp_1 = 2\na[0] = __temp_1[0]\nb[1] = __temp_1[1]"
  end

  it "normalizes n to 1 with []" do
    assert_normalize "a = 1; a[0] = 1, 2, 3", "a = 1\na[0] = [1, 2, 3]"
  end

  it "normalizes n to n with call" do
    assert_normalize "a = 1; b = 2; a.foo, b.bar = 2, 3", "a = 1\nb = 2\n__temp_1 = 2\n__temp_2 = 3\na.foo = __temp_1\nb.bar = __temp_2"
  end

  it "normalizes 1 to n with call" do
    assert_normalize "a = 1; b = 2; a.foo, b.bar = 2", "a = 1\nb = 2\n__temp_1 = 2\na.foo = __temp_1[0]\nb.bar = __temp_1[1]"
  end

  it "normalizes n to 1 with call" do
    assert_normalize "a = 1; a.foo = 1, 2, 3", "a = 1\na.foo = [1, 2, 3]"
  end
end
