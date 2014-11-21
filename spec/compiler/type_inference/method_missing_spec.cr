require "../../spec_helper"

describe "Type inference: method_missing" do
  it "does error in method_missing macro with virtual type" do
    assert_error %(
      abstract class Foo
      end

      class Bar < Foo
        macro method_missing(name, args, block)
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
        macro method_missing(name, args)
        end
      end
      ), "macro 'method_missing' expects 3 arguments: name, args, block"
  end

  it "does method missing for generic type" do
    assert_type(%(
      class Foo(T)
        macro method_missing(name, args, block)
          1
        end
      end

      Foo(Int32).new.foo
      )) { int32 }
  end
end
