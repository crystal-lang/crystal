require "../../spec_helper"

describe "array literal" do
  it "empty literal" do
    assert_type("class Array(T); def <<(t : T); end; end; Array(Int32){}") { array_of int32 }
  end

  it "non-supported type" do
    assert_error("String{}", "Type String does not support array-like or hash-like literal")
    assert_error("class Foo(T); end; Foo(Int32){}", "Type Foo(Int32) does not support array-like or hash-like literal")
  end

  it "empty literal missing generic arguments" do
    assert_error("Array{}", "wrong number of type vars for Array(T) (given 0, expected 1)")
  end
end
