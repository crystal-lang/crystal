require "../../spec_helper"

describe "Semantic: type" do
  it "can call methods of original type" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { uint64 }
      lib Lib
        type X = Void*
        fun foo : X
      end

      Lib.foo.address
      CRYSTAL
  end

  it "can call methods of parent type" do
    assert_error(<<-CRYSTAL, "undefined method 'baz'")
      lib Lib
        type X = Void*
        fun foo : X
      end

      Lib.foo.baz
      CRYSTAL
  end

  it "can access instance variables of original type" do
    assert_type(<<-CRYSTAL) { int32 }
      lib Lib
        struct X
          x : Int32
        end

        type Y = X
        fun foo : Y
      end

      Lib.foo.@x
      CRYSTAL
  end

  it "errors if original type doesn't support instance variables" do
    assert_error(<<-CRYSTAL, "can't use instance variables inside primitive types (at Int32)")
      lib Lib
        type X = Int32
        fun foo : X
      end

      Lib.foo.@x
      CRYSTAL
  end
end
