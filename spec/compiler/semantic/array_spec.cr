require "../../spec_helper"

describe "Semantic: array" do
  it "types array literal of int" do
    assert_type("require \"prelude\"; [1, 2, 3]") { array_of(int32) }
  end

  it "types array literal of union" do
    assert_type("require \"prelude\"; [1, 2.5]") { array_of(union_of int32, float64) }
  end

  it "types empty typed array literal of int32" do
    assert_type("require \"prelude\"; [] of Int32") { array_of(int32) }
  end

  it "types non-empty typed array literal of int" do
    assert_type("require \"prelude\"; [1, 2, 3] of Int32") { array_of(int32) }
  end

  it "types non-empty typed array literal of int" do
    assert_type("require \"prelude\"; [1, 2, 3] of Int8") { array_of(int8) }
  end

  it "types array literal size correctly" do
    assert_type("require \"prelude\"; [1].size") { int32 }
  end

  it "assignment in array literal works (#3195)" do
    assert_type("require \"prelude\"; [a = 1]; a") { int32 }
  end

  it "types array literal with splats" do
    assert_type("require \"prelude\"; [1, *{'a', 1}, 2.5]") { array_of(union_of int32, char, float64) }
  end

  it "types array literal with splats (2)" do
    assert_type("require \"prelude\"; [1, *{1, 'a'}, 2.5]") { array_of(union_of int32, char, float64) }
  end

  it "types array literal of int with splats" do
    assert_type("require \"prelude\"; [1, *{2_i8, 3_i8}, 4] of Int8") { array_of(int8) }
  end
end
