require "../../spec_helper"

describe "Semantic: macro" do
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
      "type must be Int32, not Char"
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
    }, "type must be Foo(String), not Foo(Int32)",
      inject_primitives: false
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
        {% begin %}
          bar_{{ "baz".id }}
        {% end %}
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
          {% begin %}
            bar_{{ "baz".id }}
          {% end %}
        end
      end

      Foo.new.foo
      )) { int32 }
  end

  it "types macro def that calls another method inside a class" do
    assert_type(%(
      class Foo
        macro def foo : Int32
          {% begin %}
            bar_{{ "baz".id }}
          {% end %}
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
      ), "wrong number of arguments for macro 'foo' (given 1, expected 0)"
  end

  it "executes raise inside macro" do
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

  it "gives precise location info when doing yield inside macro" do
    assert_error %(
      macro foo
        {{yield}}
      end

      foo do
        1 + 'a'
      end
      ),
      "in line 7"
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
      semantic nodes
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
      )) { nilable symbol }
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
      )) { nil_type }
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

  it "show macro trace in errors (1)" do
    assert_error %(
      macro foo
        Bar
      end

      foo
    ),
      "Error in line 6: expanding macro",
      inject_primitives: false
  end

  it "show macro trace in errors (2)" do
    assert_error %(
      {% begin %}
        Bar
      {% end %}
    ),
      "Error in line 2: expanding macro",
      inject_primitives: false
  end

  it "errors if using macro that is defined later" do
    assert_error %(
      class Bar
        foo
      end

      macro foo
      end
      ),
      "macro 'foo' must be defined before this point but is defined later"
  end

  it "looks up argument types in macro owner, not in subclass (#2395)" do
    assert_type(%(
      struct Nil
        def method(x : Problem)
          0
        end
      end

      class Foo
        def method(x : Problem) : Int32
          {% for ivar in @type.instance_vars %}
            @{{ivar.id}}.method(x)
          {% end %}
          42
        end
      end

      class Problem
      end

      module Moo
        class Problem
        end

        class Bar < Foo
          @foo : Foo?
        end
      end

      Moo::Bar.new.method(Problem.new)
      )) { int32 }
  end

  it "doesn't error when adding macro call to constant (#2457)" do
    assert_type(%(
      macro foo
      end

      ITS = {} of String => String

      macro coco
        {% ITS["foo"] = yield %}
        1
      end

      coco do
        foo
      end
      )) { int32 }
  end

  it "errors if named arg matches single splat argument" do
    assert_error %(
      macro foo(*y)
      end

      foo x: 1, y: 2
      ),
      "no argument named 'x'"
  end

  it "errors if named arg matches splat argument" do
    assert_error %(
      macro foo(x, *y)
      end

      foo x: 1, y: 2
      ),
      "wrong number of arguments for macro 'foo' (given 0, expected 1+)"
  end

  it "says missing argument because positional args don't match past splat" do
    assert_error %(
      macro foo(x, *y, z)
      end

      foo 1, 2
      ),
      "missing argument: z"
  end

  it "allows named args after splat" do
    assert_type(%(
      macro foo(*y, x)
        { {{y}}, {{x}} }
      end

      foo 1, x: 'a'
      )) { tuple_of([tuple_of([int32]), char]) }
  end

  it "errors if missing one argument" do
    assert_error %(
      macro foo(x, y, z)
      end

      foo x: 1, y: 2
      ),
      "missing argument: z"
  end

  it "errors if missing two arguments" do
    assert_error %(
      macro foo(x, y, z)
      end

      foo y: 2
      ),
      "missing arguments: x, z"
  end

  it "doesn't include arguments with default values in missing arguments error" do
    assert_error %(

      macro foo(x, z, y = 1)
      end

      foo(x: 1)
      ),
      "missing argument: z"
  end

  it "finds generic type argument of included module" do
    assert_type(%(
      module Bar(T)
        def t
          {{ T }}
        end
      end

      class Foo(U)
        include Bar(U)
      end

      Foo(Int32).new.t
      )) { int32.metaclass }
  end

  it "gets named arguments in double splat" do
    assert_type(%(
      macro foo(**options)
        {{options}}
      end

      foo x: "foo", y: true
      )) { named_tuple_of({"x": string, "y": bool}) }
  end

  it "uses splat and double splat" do
    assert_type(%(
      macro foo(*args, **options)
        { {{args}}, {{options}} }
      end

      foo 1, 'a', x: "foo", y: true
      )) { tuple_of([tuple_of([int32, char]), named_tuple_of({"x": string, "y": bool})]) }
  end

  it "double splat and regular args" do
    assert_type(%(
      macro foo(x, y, **options)
        { {{x}}, {{y}}, {{options}} }
      end

      foo 1, w: 'a', y: true, z: "z"
      )) { tuple_of([int32, bool, named_tuple_of({"w": char, "z": string})]) }
  end

  it "declares multi-assign vars for macro" do
    assert_type(%(
      macro id(x, y)
        {{x}}
        {{y}}
      end

      a, b = 1, 2
      id(a, b)
      1
      )) { int32 }
  end

  it "declares rescue variable inside for macro" do
    assert_type(%(
      macro id(x)
        {{x}}
      end

      begin
      rescue ex
        id(ex)
      end

      1
      )) { int32 }
  end

  it "matches with default value after splat" do
    assert_type(%(
      macro foo(x, *y, z = true)
        { {{x}}, {{y}}, {{z}} }
      end

      foo 1, 'a'
      )) { tuple_of([int32, tuple_of([char]), bool]) }
  end

  it "uses bare *" do
    assert_type(%(
      macro foo(x, *, y)
        { {{x}}, {{y}} }
      end

      foo 10, y: 'a'
      )) { tuple_of([int32, char]) }
  end

  it "uses bare *, doesn't let more args" do
    assert_error %(
      macro foo(x, *, y)
      end

      foo 10, 20, y: 30
      ),
      "wrong number of arguments for macro 'foo' (given 2, expected 1)"
  end

  it "uses bare *, doesn't let more args" do
    assert_error %(
      def foo(x, *, y)
      end

      foo 10, 20, y: 30
      ),
      "no overload matches"
  end

  it "finds macro through alias (#2706)" do
    assert_type(%(
      module Moo
        macro bar
          1
        end
      end

      alias Foo = Moo

      Foo.bar
      )) { int32 }
  end

  it "can override macro (#2773)" do
    assert_type(%(
      macro foo
        1
      end

      macro foo
        'a'
      end

      foo
      )) { char }
  end

  it "works inside proc literal (#2984)" do
    assert_type(%(
      macro foo
        1
      end

      ->{ foo }.call
      )) { int32 }
  end

  it "finds var in proc for macros" do
    assert_type(%(
      macro foo(x)
        {{x}}
      end

      ->(x : Int32) { foo(x) }.call(1)
      )) { int32 }
  end

  it "applies visibility modifier only to first level" do
    assert_type(%(
      macro foo
        class Foo
          def self.foo
            1
          end
        end
      end

      private foo

      Foo.foo
      ), inject_primitives: false) { int32 }
  end

  it "gives correct error when method is invoked but macro exists at the same scope" do
    assert_error %(
      macro foo(x)
      end

      class Foo
      end

      Foo.new.foo
      ),
      "undefined method 'foo'"
  end

  it "uses uninitialized variable with macros" do
    assert_type(%(
      macro foo(x)
        {{x}}
      end

      a = uninitialized Int32
      foo(a)
      )) { int32 }
  end
end
