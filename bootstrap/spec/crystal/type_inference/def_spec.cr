#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: def" do
  it "types a call with an int" do
    assert_type("def foo; 1; end; foo") { int32 }
  end

  it "types a call with an argument" do
    assert_type("def foo(x); x; end; foo(1)") { int32 }
  end

  it "types a call with an argument uses a new scope" do
    assert_type("x = 2.3; def foo(x); x; end; foo 1; x") { float64 }
  end

  it "assigns def owner" do
    input = parse "class Int32; def foo; 2.5; end; end; 1.foo"
    result = infer_type input
    program, node = result.program, result.node
    assert_type node, Expressions

    a_def = node.last
    assert_type a_def, Call

    a_def.target_def.owner.should eq(program.int32)
  end

  it "allows recursion" do
    assert_type("def foo; foo; end; foo") { |mod| mod.nil }
  end

  it "allows recursion with arg" do
    assert_type("def foo(x); foo(x); end; foo 1") { |mod| mod.nil }
  end

  it "types simple recursion" do
    assert_type("def foo(x); if x > 0; foo(x - 1) + 1; else; 1; end; end; foo(5)") { int32 }
  end

  it "types empty body def" do
    assert_type("def foo; end; foo") { |mod| mod.nil }
  end

  it "types call with union argument" do
    assert_type("def foo(x); x; end; a = 1 || 'a'; foo(a)") { union_of(int32, char) }
  end

  it "defines class method" do
    assert_type("def Int.foo; 2.5; end; Int.foo") { float64 }
  end

  it "defines class method with self" do
    assert_type("class Int; def self.foo; 2.5; end; end; Int.foo") { float64 }
  end

  it "calls with default argument" do
    assert_type("def foo(x = 1); x; end; foo") { int32 }
  end

  # it "do not use body for the def type" do
  #   input = parse 'def foo; if 1 == 2; return 0; end; end; foo'
  #   mod, input = infer_type input
  #   input.last.type.should eq(mod.union_of(mod.int32, mod.nil))
  #   input.last.target_def.body.type.should eq(mod.nil)
  # end

  it "reports undefined method" do
    assert_error "foo()", "undefined method 'foo'"
  end

  it "raises on undefined local variable or method" do
    assert_error "foo", "undefined local variable or method 'foo'"
  end

  it "reports no overload matches" do
    assert_error "
      def foo(x : Int)
      end

      foo 1 || 1.5
      ",
      "no overload matches"
  end

  it "reports no overload matches 2" do
    assert_error "
      def foo(x : Int, y : Int)
      end

      def foo(x : Int, y : Double)
      end

      foo(1 || 'a', 1 || 1.5)
      ",
      "no overload matches"
  end

  it "reports no block given" do
    assert_error "
      def foo
        yield
      end

      foo
      ",
      "'foo' is expected to be invoked with a block, but no block was given"
  end

  it "reports block given" do
    assert_error "
      def foo
      end

      foo {}
      ",
      "'foo' is not expected to be invoked with a block, but a block was given"
  end

  it "errors when calling two functions with nil type" do
    assert_error "
      def bar
      end

      def foo
      end

      foo.bar
      ",
      "undefined method"
  end
end
