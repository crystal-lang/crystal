#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: macro" do
  it "types macro" do
    input = parse "macro foo; 1; end; foo"
    result = infer_type input
    node = result.node as Expressions
    (node.last as Call).target_macro.should eq(parse "1")
  end

  it "errors if macro uses undefined variable" do
    assert_error "macro foo(x) {{y}} end; foo(1)",
      "undefined macro variable 'y'"
  end

  it "types def macro" do
    assert_type(%(
      def foo : Int32
        1
      end

      foo
      )) { int32 }
  end

  it "errors if def macro type not found" do
    assert_error "def foo : Foo; end; foo",
      "undefined constant Foo"
  end

  it "errors if def macro type doesn't match found" do
    assert_error "def foo : Int32; 'a'; end; foo",
      "expected 'foo' to return Int32, not Char"
  end

  it "types def macro that calls another method" do
    assert_type(%(
      def bar_baz
        1
      end

      def foo : Int32
        bar_{{ "baz".id }}
      end

      foo
      )) { int32 }
  end

  it "types def macro that calls another method inside a class" do
    assert_type(%(
      class Foo
        def bar_baz
          1
        end

        def foo : Int32
          bar_{{ "baz".id }}
        end
      end

      Foo.new.foo
      )) { int32 }
  end

  it "types def macro that calls another method inside a class" do
    assert_type(%(
      class Foo
        def foo : Int32
          bar_{{ "baz".id }}
        end
      end

      class Bar < Foo
        def bar_baz
          1
        end
      end

      Bar.new.foo
      )) { int32 }
  end

  it "types def macro with argument" do
    assert_type(%(
      def foo(x) : Int32
        x
      end

      foo(1)
      )) { int32 }
  end

  it "expands macro with block" do
    assert_type(%(
      macro foo
        {{yield}}
      end

      foo do
        def bar
          1
        end
      end

      bar
      )) { int32 }
  end

  it "expands macro with block and argument to yield" do
    assert_type(%(
      macro foo
        {{yield 1}}
      end

      foo do |value|
        def bar
          {{value}}
        end
      end

      bar
      )) { int32 }
  end
end
