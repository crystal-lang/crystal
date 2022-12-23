require "../../spec_helper"

describe "Normalize: hash literal" do
  it "normalizes empty with of" do
    assert_expand "{} of Int => Float", "::Hash(Int, Float).new"
  end

  it "normalizes non-empty with of" do
    assert_expand "{1 => 2, 3 => 4} of Int => Float", <<-CRYSTAL
      __temp_1 = ::Hash(Int, Float).new
      __temp_1[1] = 2
      __temp_1[3] = 4
      __temp_1
      CRYSTAL
  end

  it "normalizes non-empty without of" do
    assert_expand "{1 => 2, 3 => 4}", <<-CRYSTAL
      __temp_1 = ::Hash(typeof(1, 3), typeof(2, 4)).new
      __temp_1[1] = 2
      __temp_1[3] = 4
      __temp_1
      CRYSTAL
  end

  it "hoists complex element expressions" do
    assert_expand "{[1] => 2, 3 => [4]}", <<-CRYSTAL
      __temp_1 = [1]
      __temp_2 = [4]
      __temp_3 = ::Hash(typeof(__temp_1, 3), typeof(2, __temp_2)).new
      __temp_3[__temp_1] = 2
      __temp_3[3] = __temp_2
      __temp_3
      CRYSTAL
  end

  it "hoists complex element expressions, hash-like" do
    assert_expand_named "Foo{[1] => 2, 3 => [4]}", <<-CRYSTAL
      __temp_1 = [1]
      __temp_2 = [4]
      __temp_3 = Foo.new
      __temp_3[__temp_1] = 2
      __temp_3[3] = __temp_2
      __temp_3
      CRYSTAL
  end

  it "hoists complex element expressions, hash-like generic" do
    assert_expand_named "Foo{[1] => 2, 3 => [4]}", <<-CRYSTAL, generic: "Foo"
      __temp_1 = [1]
      __temp_2 = [4]
      __temp_3 = Foo(typeof(__temp_1, 3), typeof(2, __temp_2)).new
      __temp_3[__temp_1] = 2
      __temp_3[3] = __temp_2
      __temp_3
      CRYSTAL
  end
end
