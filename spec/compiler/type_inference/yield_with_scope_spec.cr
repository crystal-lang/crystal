require "../../spec_helper"

describe "Type inference: yield with scope" do
  it "infer type of empty block body" do
    assert_type("
      def foo; with 1 yield; end

      foo do
      end
    ") { |mod| mod.nil }
  end

  it "infer type of block body" do
    input = parse "
      def foo; with 1 yield; end

      foo do
        x = 1
      end
    "
    result = infer_type input
    mod, input = result.program, result.node as Expressions
    call = input.last as Call
    assign = call.block.not_nil!.body as Assign
    assign.target.type.should eq(mod.int32)
  end

  it "infer type of block body with yield scope" do
    input = parse "
      def foo; with 1 yield; end

      foo do
        to_i64
      end
    "
    result = infer_type input
    mod, input = result.program, result.node as Expressions
    (input.last as Call).block.not_nil!.body.type.should eq(mod.int64)
  end

  it "infer type of block body with yield scope and arguments" do
    input = parse "
      def foo; with 1 yield 1.5; end

      foo do |f|
        to_i64 + f
      end
    "
    result = infer_type input
    mod, input = result.program, result.node as Expressions
    (input.last as Call).block.not_nil!.body.type.should eq(mod.float64)
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
end
