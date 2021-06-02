require "../../spec_helper"

describe "hash literal" do
  it "empty literal" do
    assert_type("class Hash(K, V); def []=(k : K, v : V); end; end; Hash(Int32, Int32){}") { hash_of int32, int32 }
  end

  it "empty literal missing generic arguments" do
    assert_error("Hash{}", "wrong number of type vars for Hash(K, V) (given 0, expected 2)")
    assert_error("Hash(Int32){}", "wrong number of type vars for Hash(K, V) (given 1, expected 2)")
  end
end
