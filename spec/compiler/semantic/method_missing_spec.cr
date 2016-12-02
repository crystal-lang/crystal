require "../../spec_helper"

describe "Semantic: method_missing" do
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

  it "errors if method_missing expands to an incorrect method" do
    assert_error %(
      class Foo
        macro method_missing(call)
          def baz
            1
          end
        end
      end

      Foo.new.bar
      ),
      "wrong method_missing expansion"
  end

  it "errors if method_missing expands to multiple methods" do
    assert_error %(
      class Foo
        macro method_missing(call)
          def bar
            1
          end

          def qux
          end
        end
      end

      Foo.new.bar
      ),
      "wrong method_missing expansion"
  end
end
