require "../../spec_helper"

describe "Type inference: abstract def" do
  it "errors if using abstract def" do
    assert_error %(
      class Foo
        abstract def foo
      end

      Foo.new.foo
      ), "abstract def Foo#foo must be implemented by Foo"
  end

  it "errors if using abstract def on subclass" do
    assert_error %(
      class Foo
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
      ), "abstract def Foo#foo must be implemented by Baz"
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

  it "doesn't error on abstract def on sub-subclass (bug)" do
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

      p = Pointer(Foo).malloc(1_u64)
      p.value = Baz.new
      p.value.foo
      ), "abstract def Bar#foo must be implemented by Baz"
  end
end
