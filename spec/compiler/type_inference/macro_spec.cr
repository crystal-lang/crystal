#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: macro" do
  it "types macro" do
    input = parse "macro foo; 1; end; foo"
    result = infer_type input
    node = result.node as Expressions
    (node.last as Call).expanded.should eq(parse "1")
  end

  it "errors if macro uses undefined variable" do
    assert_error "macro foo(x) {{y}} end; foo(1)",
      "undefined macro variable 'y'"
  end

  it "types macro def" do
    assert_type(%(
      macro def foo : Int32
        1
      end

      foo
      )) { int32 }
  end

  it "errors if macro def type not found" do
    assert_error "macro def foo : Foo; end; foo",
      "undefined constant Foo"
  end

  it "errors if macro def type doesn't match found" do
    assert_error "macro def foo : Int32; 'a'; end; foo",
      "expected 'foo' to return Int32, not Char"
  end

  it "types macro def that calls another method" do
    assert_type(%(
      def bar_baz
        1
      end

      macro def foo : Int32
        bar_{{ "baz".id }}
      end

      foo
      )) { int32 }
  end

  it "types macro def that calls another method inside a class" do
    assert_type(%(
      class Foo
        def bar_baz
          1
        end

        macro def foo : Int32
          bar_{{ "baz".id }}
        end
      end

      Foo.new.foo
      )) { int32 }
  end

  it "types macro def that calls another method inside a class" do
    assert_type(%(
      class Foo
        macro def foo : Int32
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

  it "types macro def with argument" do
    assert_type(%(
      macro def foo(x) : Int32
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

  it "errors if find macros but wrong arguments" do
    assert_error %(
      macro foo
        1
      end

      foo(1)
      ), "wrong number of arguments for macro 'foo' (1 for 0)"
  end

  it "executs raise inside macro" do
    assert_error %(
      macro foo
        {{ raise "OH NO" }}
      end

      foo
      ), "OH NO"
  end
end
