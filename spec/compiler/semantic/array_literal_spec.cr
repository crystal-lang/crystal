require "../../spec_helper"

describe "array literal" do
  it "empty literal" do
    assert_type("Array(Int32){}") { array_of int32 }
    # An empty array-like literal transforms into a single `.new` call, so it
    # technically works with any type that has an argless `.new` method, even if
    # it does not respond to `#<<`.
    assert_type("String{}") { string }
  end

  it "empty literal missing generic arguments" do
    assert_error("Array{}", "wrong number of type vars for Array(T) (given 0, expected 1)")
  end
end
