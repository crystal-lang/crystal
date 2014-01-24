#!/usr/bin/env bin/crystal --run
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

  # it "errors if calling method on no return" do
  #   assert_error %(require "prelude"; exit.foo),
  #     "undefined method 'foo' for NoReturn"
  # end

  it "errors if one argument is no return" do
    assert_error "
      lib C
        fun exit : NoReturn
      end

      def foo(x)
        1
      end

      foo(C.exit)
      ",
        "can't call 'foo' with an argument that never returns"
  end
end
