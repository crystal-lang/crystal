require "../../spec_helper"

describe "Semantic: range type" do
  it "types range type in var declaration" do
    assert_type("x = uninitialized Int32..Char; x") { range_of(int32, char) }
  end

  it "types range type in array of" do
    assert_type("x = [] of Int32..Int32; x", inject_primitives: true) { array_of(range_of(int32, int32)) }
  end

  it "types range type in alias" do
    assert_type("alias Foo = Int32..Char?; x = uninitialized Foo; x") { range_of(int32, nilable(char)) }
  end

  it "types range type as proc output" do
    assert_type("alias Foo = Int32 -> Int32..Char; x = uninitialized Foo; x") { proc_of(int32, range_of(int32, char)) }
  end

  it "types static array of range type" do
    assert_type("x = uninitialized (Int32..Char)[2]; x") { static_array_of(range_of(int32, char), 2) }
  end
end
