require "../../spec_helper"

describe "Type inference: type" do
  it "can call methods of original type" do
    assert_type("
      lib Lib
        type X = Void*
        fun foo : X
      end

      Lib.foo.address
    ") { uint64 }
  end

  it "can call methods of parent type" do
    assert_error("
      lib Lib
        type X = Void*
        fun foo : X
      end

      Lib.foo.baz
    ", "undefined method 'baz'")
  end
end
