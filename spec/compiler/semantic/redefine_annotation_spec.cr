require "../../spec_helper"

describe "Semantic: redefine annotation" do
  it "uses redefine annotation (no args)" do
    semantic(%(
      class Foo
        def foo
        end
      end

      class Foo
        @[Redefine]
        def foo
        end
      end
      ))
  end

  it "uses redefine annotation (args without restriction)" do
    semantic(%(
      class Foo
        def foo(x)
        end
      end

      class Foo
        @[Redefine]
        def foo(x)
        end
      end
      ))
  end

  it "uses redefine annotation (args with restriction)" do
    semantic(%(
      class Foo
        def foo(x : Int32)
        end
      end

      class Foo
        @[Redefine]
        def foo(x : Int32)
        end
      end
      ))
  end

  it "uses redefine annotation (stricter restriction)" do
    semantic(%(
      class Foo
        def foo(x)
        end
      end

      class Foo
        @[Redefine]
        def foo(x : Int32)
        end
      end
      ))
  end

  it "errors if doesn't redefine (no such method)" do
    assert_error %(
      class Foo
        def foo(x)
        end
      end

      class Foo
        @[Redefine]
        def bar(x)
        end
      end
      ),
      "method has Redefine annotation but doesn't redefine (no such method)"
  end

  it "errors if doesn't redefine (different restriction)" do
    assert_error %(
      class Foo
        def foo(x : Int32)
        end
      end

      class Foo
        @[Redefine]
        def foo(x : String)
        end
      end
      ),
      "method has Redefine annotation but doesn't redefine (type restrictions don't match)"
  end

  it "errors if doesn't redefine (weaker restriction)" do
    assert_error %(
      class Foo
        def foo(x : Int32)
        end
      end

      class Foo
        @[Redefine]
        def foo(x)
        end
      end
      ),
      "method has Redefine annotation but doesn't redefine (type restrictions don't match)"
  end
end
