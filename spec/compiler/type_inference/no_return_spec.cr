require "../../spec_helper"

describe "Type inference: NoReturn" do
  it "types call to C.exit as NoReturn" do
    assert_type("lib C; fun exit : NoReturn; end; C.exit") { no_return }
  end

  it "types raise as NoReturn" do
    assert_type("require \"prelude\"; raise \"foo\"") { no_return }
  end

  it "types union of NoReturn and something else" do
    assert_type("lib C; fun exit : NoReturn; end; 1 == 1 ? C.exit : 1") { int32 }
  end

  it "types union of NoReturns" do
    assert_type("lib C; fun exit : NoReturn; end; 1 == 2 ? C.exit : C.exit") { no_return }
  end

  it "types with no return even if code follows" do
    assert_type("lib C; fun exit : NoReturn; end; C.exit; 1") { no_return }
  end

  it "assumes if condition's type filters when else is no return" do
    assert_type("
      lib C
        fun exit : NoReturn
      end

      class Foo
        def foo
          1
        end
      end

      foo = Foo.new || nil
      C.exit unless foo

      foo.foo
    ") { int32 }
  end
end
