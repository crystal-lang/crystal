require "../../spec_helper"

describe "Semantic: abstract def" do
  it "errors if using abstract def on subclass" do
    assert_error %(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
          1
        end
      end

      class Baz < Foo
      end

      (Bar.new || Baz.new).foo
      ), "abstract `def Foo#foo()` must be implemented by Baz"
  end

  it "works on abstract method on abstract class" do
    assert_type %(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
          1
        end
      end

      class Baz < Foo
        def foo
          2
        end
      end

      b = Bar.new || Baz.new
      b.foo
      ) { int32 }
  end

  it "works on abstract def on sub-subclass" do
    assert_type(%(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
          1
        end
      end

      class Baz < Bar
      end

      p = Pointer(Foo).malloc(1_u64)
      p.value = Bar.new
      p.value = Baz.new
      p.value.foo
      )) { int32 }
  end

  it "errors if using abstract def on subclass that also defines it as abstract" do
    assert_error %(
      abstract class Foo
        abstract def foo
      end

      abstract class Bar < Foo
        abstract def foo
      end

      class Baz < Bar
      end
      ), "abstract `def Foo#foo()` must be implemented by Baz"
  end

  it "gives correct error when no overload matches, when an abstract method is implemented (#1406)" do
    assert_error %(
      abstract class Foo
        abstract def foo(x : Int32)
      end

      class Bar < Foo
        def foo(x : Int32)
          1
        end
      end

      Bar.new.foo(1 || 'a')
      ),
      "no overload matches"
  end

  it "errors if using abstract def on non-abstract class" do
    assert_error %(
      class Foo
        abstract def foo
      end
      ),
      "can't define abstract def on non-abstract class"
  end

  it "errors if using abstract def on metaclass" do
    assert_error %(
      class Foo
        abstract def self.foo
      end
      ),
      "can't define abstract def on metaclass"
  end

  it "errors if abstract method is not implemented by subclass" do
    assert_error %(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
      end
      ),
      "abstract `def Foo#foo()` must be implemented by Bar"
  end

  it "errors if abstract method with arguments is not implemented by subclass" do
    assert_error %(
      abstract class Foo
        abstract def foo(x, y)
      end

      class Bar < Foo
      end
      ),
      "abstract `def Foo#foo(x, y)` must be implemented by Bar"
  end

  it "errors if abstract method with arguments is not implemented by subclass (wrong number of arguments)" do
    assert_error %(
      abstract class Foo
        abstract def foo(x)
      end

      class Bar < Foo
        def foo(x, y)
        end
      end
      ),
      "abstract `def Foo#foo(x)` must be implemented by Bar"
  end

  it "errors if abstract method with arguments is not implemented by subclass (wrong type)" do
    assert_error %(
      abstract class Foo
        abstract def foo(x, y : Int32)
      end

      class Bar < Foo
        def foo(x, y : Float64)
        end
      end
      ),
      "abstract `def Foo#foo(x, y : Int32)` must be implemented by Bar"
  end

  it "errors if abstract method with arguments is not implemented by subclass (block difference)" do
    assert_error %(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
          yield
        end
      end
      ),
      "abstract `def Foo#foo()` must be implemented by Bar"
  end

  it "doesn't error if abstract method is implemented by subclass" do
    semantic %(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
        end
      end
      )
  end

  it "doesn't error if abstract method with args is implemented by subclass" do
    semantic %(
      abstract class Foo
        abstract def foo(x, y)
      end

      class Bar < Foo
        def foo(x, y)
        end
      end
      )
  end

  it "doesn't error if abstract method with args is implemented by subclass (restriction -> no restriction)" do
    semantic %(
      abstract class Foo
        abstract def foo(x, y : Int32)
      end

      class Bar < Foo
        def foo(x, y)
        end
      end
      )
  end

  it "doesn't error if abstract method with args is implemented by subclass (don't check subclasses)" do
    semantic %(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
        end
      end

      class Baz < Bar
      end
      )
  end

  it "errors if abstract method is not implemented by subclass of subclass" do
    assert_error %(
      abstract class Foo
        abstract def foo
      end

      abstract class Bar < Foo
      end

      class Baz < Bar
      end
      ),
      "abstract `def Foo#foo()` must be implemented by Baz"
  end

  it "doesn't error if abstract method is implemented by subclass via module inclusion" do
    semantic %(
      abstract class Foo
        abstract def foo
      end

      module Moo
        def foo
        end
      end

      class Bar < Foo
        include Moo
      end
      )
  end

  it "errors if abstract method is not implemented by including class" do
    assert_error %(
      module Foo
        abstract def foo
      end

      class Bar
        include Foo
      end
      ),
      "abstract `def Foo#foo()` must be implemented by Bar"
  end

  it "doesn't error if abstract method is implemented by including class" do
    semantic %(
      module Foo
        abstract def foo
      end

      class Bar
        include Foo

        def foo
        end
      end
      )
  end

  it "doesn't error if abstract method is not implemented by including module" do
    semantic %(
      module Foo
        abstract def foo
      end

      module Bar
        include Foo
      end
      )
  end

  it "errors if abstract method is not implemented by subclass (nested in module)" do
    assert_error %(
      module Moo
        abstract class Foo
          abstract def foo
        end
      end

      class Bar < Moo::Foo
      end
      ),
      "abstract `def Moo::Foo#foo()` must be implemented by Bar"
  end

  it "doesn't error if abstract method with args is implemented by subclass (with one default arg)" do
    semantic %(
      abstract class Foo
        abstract def foo(x)
      end

      class Bar < Foo
        def foo(x, y = 1)
        end
      end
      )
  end

  it "doesn't error if implements with parent class" do
    semantic %(
      class Parent; end
      class Child < Parent; end

      abstract class Foo
        abstract def foo(x : Child)
      end

      class Bar < Foo
        def foo(x : Parent)
        end
      end
      )
  end

  it "doesn't error if implements with parent module" do
    semantic %(
      module Moo
      end

      module Moo2
        include Moo
      end

      class Child
        include Moo2
      end

      abstract class Foo
        abstract def foo(x : Child)
      end

      class Bar < Foo
        def foo(x : Moo)
        end
      end
      )
  end

  it "finds implements in included module in disorder (#4052)" do
    semantic %(
      module B
        abstract def x
      end

      module C
        def x
          :x
        end
      end

      class A
        include C
        include B
      end
      )
  end
end
