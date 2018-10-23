require "../../spec_helper"

describe "Semantic: override annotation" do
  it "uses override annotation (no args)" do
    semantic(%(
      class Foo
        def foo
        end
      end

      class Bar < Foo
        @[Override]
        def foo
        end
      end
      ))
  end

  it "uses override annotation (args without restriction)" do
    semantic(%(
      class Foo
        def foo(x)
        end
      end

      class Bar < Foo
        @[Override]
        def foo(x)
        end
      end
      ))
  end

  it "uses override annotation (args with restriction)" do
    semantic(%(
      class Foo
        def foo(x : Int32)
        end
      end

      class Bar < Foo
        @[Override]
        def foo(x : Int32)
        end
      end
      ))
  end

  it "uses override annotation (stricter restriction)" do
    semantic(%(
      class Foo
        def foo(x)
        end
      end

      class Bar < Foo
        @[Override]
        def foo(x : Int32)
        end
      end
      ))
  end

  it "uses override annotation (weaker restriction)" do
    semantic(%(
      class Foo
        def foo(x : Int32)
        end
      end

      class Bar < Foo
        @[Override]
        def foo(x)
        end
      end
      ))
  end

  it "uses override annotation (middle type in hierarchy)" do
    semantic(%(
      class Foo
        def foo(x : Int32)
        end
      end

      class Bar < Foo
      end

      class Baz < Bar
        @[Override]
        def foo(x : Int32)
        end
      end
      ))
  end

  it "uses override annotation (abstract type)" do
    semantic(%(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        @[Override]
        def foo
        end
      end
      ))
  end

  it "uses override annotation (module)" do
    semantic(%(
      module Foo
        abstract def foo
      end

      class Bar
        include Foo

        @[Override]
        def foo
        end
      end
      ))
  end

  it "errors if doesn't override (no such method)" do
    assert_error %(
      class Foo
        def foo(x)
        end
      end

      class Bar < Foo
        @[Override]
        def bar(x)
        end
      end
      ),
      "method has Override annotation but doesn't override (no such method)"
  end

  it "errors if doesn't override (different restriction)" do
    assert_error %(
      class Foo
        def foo(x : Int32)
        end
      end

      class Bar < Foo
        @[Override]
        def foo(x : String)
        end
      end
      ),
      "method has Override annotation but doesn't override (type restrictions don't match)"
  end
end
