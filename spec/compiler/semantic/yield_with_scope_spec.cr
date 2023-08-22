require "../../spec_helper"

describe "Semantic: yield with scope" do
  it "infer type of empty block body" do
    assert_type("
      def foo; with 1 yield; end

      foo do
      end
    ") { nil_type }
  end

  it "infer type of block body" do
    input = parse "
      def foo; with 1 yield; end

      foo do
        x = 1
      end
    "
    result = semantic input
    mod, input = result.program, result.node.as(Expressions)
    call = input.last.as(Call)
    assign = call.block.not_nil!.body.as(Assign)
    assign.target.type.should eq(mod.int32)
  end

  it "infer type of block body with yield scope" do
    input = parse %(
      require "primitives"

      def foo; with 1 yield; end

      foo do
        to_i64
      end
    )
    result = semantic input
    mod, input = result.program, result.node.as(Expressions)
    input.last.as(Call).block.not_nil!.body.type.should eq(mod.int64)
  end

  it "infer type of block body with yield scope and arguments" do
    input = parse %(
      require "primitives"

      def foo; with 1 yield 1.5; end

      foo do |f|
        to_i64 + f
      end
    )
    result = semantic input
    mod, input = result.program, result.node.as(Expressions)
    input.last.as(Call).block.not_nil!.body.type.should eq(mod.float64)
  end

  it "passes #229" do
    assert_type(%(
      class Foo
        def foo
          1
        end
      end

      def a
        with Foo.new yield
      end

      module Bar
        x = a { foo }
      end
      x
      )) { int32 }
  end

  it "invokes nested calls" do
    assert_type(%(
      class Foo
        def x
          with self yield
        end

        def y
          yield
        end
      end

      def bar
        yield
      end

      foo = Foo.new
      foo.x do
        bar do
          y do
            1
          end
        end
      end
      )) { int32 }
  end

  it "finds macro" do
    assert_type(%(
      class Foo
        def x
          with self yield
        end

        macro y
          1
        end
      end

      def bar
        yield
      end

      foo = Foo.new
      foo.x do
        y
      end
      )) { int32 }
  end

  it "errors if using instance variable at top level" do
    assert_error %(
      class Foo
        def foo
          with self yield
        end
      end

      Foo.new.foo do
        @foo
      end
      ),
      "can't use instance variables at the top level"
  end

  it "uses instance variable of enclosing scope" do
    assert_type(%(
      class Foo
        def foo
          with self yield
        end
      end

      class Bar
        def initialize
          @x = 1
        end

        def bar
          Foo.new.foo do
            @x
          end
        end
      end

      Bar.new.bar
      )) { int32 }
  end

  it "uses method of enclosing scope" do
    assert_type(%(
      class Foo
        def foo
          with self yield
        end
      end

      class Bar
        def bar
          Foo.new.foo do
            baz
          end
        end

        def baz
          1
        end
      end

      Bar.new.bar
      )) { int32 }
  end

  it "mentions with yield scope and current scope in error" do
    assert_error %(
      def foo
        with 1 yield
      end

      class Foo
        def bar
          foo do
            baz
          end
        end
      end

      Foo.new.bar
      ),
      "undefined local variable or method 'baz' for Int32 (with ... yield) and Foo (current scope)"
  end
end
