require "../../spec_helper"

describe "Type inference: method_missing" do
  it "does error in method_missing macro with virtual type" do
    assert_error %(
      abstract class Foo
      end

      class Bar < Foo
        macro method_missing(call)
          2
        end
      end

      class Baz < Foo
      end

      foo = Baz.new || Bar.new
      foo.lala
      ), "undefined method 'lala' for Baz"
  end

  it "does error in method_missing if wrong number of args" do
    assert_error %(
      class Foo
        macro method_missing(call, foo)
        end
      end
      ), "macro 'method_missing' expects 1 argument (call)"
  end

  it "does method missing for generic type" do
    assert_type(%(
      class Foo(T)
        macro method_missing(call)
          1
        end
      end

      Foo(Int32).new.foo
      )) { int32 }
  end
end
