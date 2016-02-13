require "../../spec_helper"

describe "Type inference: macro" do
  it "types macro" do
    assert_type(%(
      macro foo
        1
      end

      foo
    )) { int32 }
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

  it "allows subclasses of return type for macro def" do
    run(%{
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          2
        end
      end

      macro def foobar : Foo
        Bar.new
      end

      foobar.foo
    }).to_i.should eq(2)
  end

  it "allows return values that include the return type of the macro def" do
    run(%{
      module Foo
        def foo
          1
        end
      end

      class Bar
        include Foo

        def foo
          2
        end
      end

      macro def foobar : Foo
        Bar.new
      end

      foobar.foo
    }).to_i.should eq(2)
  end

  it "allows generic return types for macro def" do
    run(%{
      class Foo(T)
        def foo
          @foo
        end

        def initialize(@foo : T)
        end
      end

      macro def foobar : Foo(Int32)
        Foo.new(2)
      end

      foobar.foo
    }).to_i.should eq(2)

    assert_error %{
      class Foo(T)
        def initialize(@foo : T)
        end
      end

      macro def bar : Foo(String)
        Foo.new(3)
      end

      bar
    }, "Error in line 7: expected 'bar' to return Foo(String), not Foo(Int32)"
  end

  it "allows union return types for macro def" do
    assert_type(%{
      macro def foo : String | Int32
        1
      end

      foo
    }) { int32 }
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

  it "can specify tuple as return type" do
    assert_type(%(
      macro def foo : {Int32, Int32}
        {1, 2}
      end

      foo
      )) { tuple_of([int32, int32] of Type) }
  end

  it "allows specifying self as macro def return type" do
    assert_type(%(
      class Foo
        macro def foo : self
          self
        end
      end

      Foo.new.foo
      )) { types["Foo"] }
  end

  it "allows specifying self as macro def return type (2)" do
    assert_type(%(
      class Foo
        macro def foo : self
          self
        end
      end

      class Bar < Foo
      end

      Bar.new.foo
      )) { types["Bar"] }
  end

  it "doesn't die on untyped instance var" do
    assert_type(%(
      require "prelude"

      class Foo
        def initialize
          @foo = 1
        end

        def foo
          @foo
        end

        macro def ivars_size : Int32
          {{@type.instance_vars.size}}
        end
      end

      ->(x : Foo) { x.foo; x.ivars_size }
      )) { fun_of(types["Foo"], no_return) }
  end

  it "errors if non-existent named arg" do
    assert_error %(
      macro foo(x = 1)
        {{x}} + 1
      end

      foo y: 2
      ),
      "no argument named 'y'"
  end

  it "errors if named arg already specified" do
    assert_error %(
      macro foo(x = 1)
        {{x}} + 1
      end

      foo 2, x: 2
      ),
      "argument 'x' already specified"
  end

  it "finds macro in included module" do
    assert_type(%(
      module Moo
        macro bar
          1
        end
      end

      class Foo
        include Moo

        def foo
          bar
        end
      end

      Foo.new.foo
      )) { int32 }
  end

  it "errors when trying to define def inside def with macro expansion" do
    assert_error %(
      macro foo
        def bar; end
      end

      def baz
        foo
      end

      baz
      ),
      "can't define def inside def"
  end

  it "uses typeof(self.method) in macro def" do
    assert_type(%(
      class Foo
        macro def foo : typeof(self.bar)
          bar
        end
      end

      class Bar < Foo
        def bar
          1.5
        end
      end

      Bar.new.foo
      )) { float64 }
  end

  it "gives precise location info when doing yield inside macro" do
    assert_error %(
      macro foo
        {{yield}}
      end

      foo do
        1 + 'a'
      end
      ),
      "Error in line 7"
  end

  it "transforms with {{yield}} and call" do
    assert_type(%(
      macro foo
        bar({{yield}})
      end

      def bar(value)
        value
      end

      foo do
        1 + 2
      end
      )) { int32 }
  end

  it "can return class type in macro def" do
    assert_type(%(
      macro def foo : Int32.class
        Int32
      end

      foo
      )) { types["Int32"].metaclass }
  end

  it "can return virtual class type in macro def" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      macro def foo : Foo.class
        1 == 1 ? Foo : Bar
      end

      foo
      )) { types["Foo"].metaclass.virtual_type }
  end

  it "can't define new variables (#466)" do
    nodes = parse(%(
      macro foo
        hello = 1
      end

      foo
      hello
      ))
    begin
      infer_type nodes
    rescue ex : TypeException
      ex.to_s.should_not match(/did you mean/)
    end
  end

  it "finds macro in included generic module" do
    assert_type(%(
      module Moo(T)
        macro moo
          1
        end
      end

      class Foo
        include Moo(Int32)

        def foo
          moo
        end
      end

      Foo.new.foo
      )) { int32 }
  end

  it "finds macro in inherited generic class" do
    assert_type(%(
      class Moo(T)
        macro moo
          1
        end
      end

      class Foo < Moo(Int32)
        def foo
          moo
        end
      end

      Foo.new.foo
      )) { int32 }
  end

  it "doesn't die on && inside if (bug)" do
    assert_type(%(
      macro foo
        1 && 2
      end

      foo ? 3 : 4
      )) { int32 }
  end

  it "checks if macro expansion returns (#821)" do
    assert_type(%(
      macro pass
        return :pass
      end

      def me
        pass
        nil
      end

      me
      )) { symbol }
  end

  it "errors if declares macro inside if" do
    assert_error %(
      if 1 == 2
        macro foo; end
      end
      ),
      "can't declare macro dynamically"
  end

  it "allows declaring class with macro if" do
    assert_type(%(
      {% if true %}
        class Foo; end
      {% end %}

      Foo.new
      )) { types["Foo"] }
  end

  it "allows declaring class with macro for" do
    assert_type(%(
      {% for i in 0..0 %}
        class Foo; end
      {% end %}

      Foo.new
      )) { types["Foo"] }
  end

  it "allows declaring class with macro expression" do
    assert_type(%(
      {{ `echo "class Foo; end"` }}

      Foo.new
      )) { types["Foo"] }
  end

  it "errors if requires inside class through macro expansion" do
    assert_error %(
      macro req
        require "bar"
      end

      class Foo
        req
      end
      ),
      "can't require inside type declarations"
  end

  it "errors if requires inside if through macro expansion" do
    assert_error %(
      macro req
        require "bar"
      end

      if 1 == 2
        req
      end
      ),
      "can't require dynamically"
  end

  it "can define constant via macro included" do
    assert_type(%(
      module Mod
        macro included
          CONST = 1
        end
      end

      include Mod


      CONST
      )) { int32 }
  end

  it "errors if using private on non-top-level macro" do
    assert_error %(
      class Foo
        private macro bar
        end
      end
      ),
      "private macros can only be declared at the top-level"
  end

  it "expands macro with break inside while (#1852)" do
    assert_type(%(
      macro test
        foo = "bar"
        break
      end

      while true
        test
      end
      )) { |mod| mod.nil }
  end

  it "can access variable inside macro expansion (#2057)" do
    assert_type(%(
      macro foo
        x
      end

      def method
        yield 1
      end

      method do |x|
        foo
      end
      )) { int32 }
  end

  it "declares variable for macro with out" do
    assert_type(%(
      lib LibFoo
        fun foo(x : Int32*)
      end

      macro some_macro
        z
      end

      LibFoo.foo(out z)
      some_macro
      )) { int32 }
  end
end
