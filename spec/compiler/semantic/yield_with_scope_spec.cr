require "../../spec_helper"

describe "Semantic: yield with scope" do
  it "infer type of empty block body" do
    assert_type(<<-CRYSTAL) { nil_type }
      def foo; with 1 yield; end

      foo do
      end
      CRYSTAL
  end

  it "infer type of block body" do
    input = parse <<-CRYSTAL
      def foo; with 1 yield; end

      foo do
        x = 1
      end
      CRYSTAL
    result = semantic input
    mod, input = result.program, result.node.as(Expressions)
    call = input.last.as(Call)
    assign = call.block.not_nil!.body.as(Assign)
    assign.target.type.should eq(mod.int32)
  end

  it "infer type of block body with yield scope" do
    input = parse <<-CRYSTAL
      require "primitives"

      def foo; with 1 yield; end

      foo do
        to_i64
      end
      CRYSTAL
    result = semantic input
    mod, input = result.program, result.node.as(Expressions)
    input.last.as(Call).block.not_nil!.body.type.should eq(mod.int64)
  end

  it "infer type of block body with yield scope and arguments" do
    input = parse <<-CRYSTAL
      require "primitives"

      def foo; with 1 yield 1.5; end

      foo do |f|
        to_i64 + f
      end
      CRYSTAL
    result = semantic input
    mod, input = result.program, result.node.as(Expressions)
    input.last.as(Call).block.not_nil!.body.type.should eq(mod.float64)
  end

  it "passes #229" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "invokes nested calls" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "finds macro" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "errors if using instance variable at top level" do
    assert_error <<-CRYSTAL, "can't use instance variables at the top level"
      class Foo
        def foo
          with self yield
        end
      end

      Foo.new.foo do
        @foo
      end
      CRYSTAL
  end

  it "uses instance variable of enclosing scope" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "uses method of enclosing scope" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "mentions with yield scope and current scope in error" do
    assert_error <<-CRYSTAL, "undefined local variable or method 'baz' for Int32 (with ... yield) and Foo (current scope)"
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
      CRYSTAL
  end
end
