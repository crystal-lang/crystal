require "../../spec_helper"

describe "Semantic: array" do
  it "types array literal of int" do
    assert_type("require \"prelude\"; [1, 2, 3]") { array_of(int32) }
  end

  it "types array literal of union" do
    assert_type("require \"prelude\"; [1, 2.5]") { array_of(union_of int32, float64) }
  end

  it "types empty typed array literal of int" do
    assert_type("require \"prelude\"; [] of Int32") { array_of(int32) }
  end

  it "types non-empty typed array literal of int" do
    assert_type("require \"prelude\"; [1, 2, 3] of Int32") { array_of(int32) }
  end

  it "types array literal size correctly" do
    assert_type("require \"prelude\"; [1].size") { int32 }
  end
end
