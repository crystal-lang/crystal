require "../../spec_helper"

describe "Semantic: macro" do
  it "types macro" do
    assert_type(<<-CR) { int32 }
      macro foo
        1
      end

      foo
      CR
  end

  it "errors if macro uses undefined variable" do
    assert_error "macro foo(x) {{y}} end; foo(1)",
      "undefined macro variable 'y'"
  end

  it "types macro def" do
    assert_type(<<-CR) { int32 }
      class Foo
        def foo : Int32
          {{ @type }}
          1
        end
      end

      Foo.new.foo
      CR
  end

  it "errors if macro def type not found" do
    assert_error <<-CR, "undefined constant Foo"
      class Baz
        def foo : Foo
          {{ @type }}
        end
      end

      Baz.new.foo
      CR
  end

  it "errors if macro def type doesn't match found" do
    assert_error <<-CR, "method Foo#foo must return Int32 but it is returning Char"
      class Foo
        def foo : Int32
          {{ @type}}
          'a'
        end
      end

      Foo.new.foo
      CR
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

      class Baz
        def foobar : Foo
          {{ @type }}
          Bar.new
        end
      end

      Baz.new.foobar.foo
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

      class Baz
        def foobar : Foo
          {{ @type }}
          Bar.new
        end
      end

      Baz.new.foobar.foo
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

      class Baz
        def foobar : Foo(Int32)
          {{ @type }}
          Foo.new(2)
        end
      end

      Baz.new.foobar.foo
    }).to_i.should eq(2)

    assert_error(<<-CR, "method Bar#bar must return Foo(String) but it is returning Foo(Int32)")
      class Foo(T)
        def initialize(@foo : T)
        end
      end

      class Bar
        def bar : Foo(String)
          {{ @type }}
          Foo.new(3)
        end
      end

      Bar.new.bar
      CR
  end

  it "allows union return types for macro def" do
    assert_type(<<-CR) { int32 }
      class Foo
        def foo : String | Int32
          {{ @type }}
          1
        end
      end

      Foo.new.foo
      CR
  end

  it "types macro def that calls another method" do
    assert_type(<<-CR) { int32 }
      def bar_baz
        1
      end

      class Foo
        def foo : Int32
          {{ @type }}
          {% begin %}
            bar_{{ "baz".id }}
          {% end %}
        end
      end

      Foo.new.foo
      CR
  end

  it "types macro def that calls another method inside a class" do
    assert_type(<<-CR) { int32 }
      class Foo
        def bar_baz
          1
        end

        def foo : Int32
          {{ @type }}
          {% begin %}
            bar_{{ "baz".id }}
          {% end %}
        end
      end

      Foo.new.foo
      CR
  end

  it "types macro def that calls another method inside a class" do
    assert_type(<<-CR) { int32 }
      class Foo
        def foo : Int32
          {{ @type }}
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
      CR
  end

  it "types macro def with argument" do
    assert_type(<<-CR) { int32 }
      class Foo
        def foo(x) : Int32
          {{ @type }}
          x
        end
      end

      Foo.new.foo(1)
      CR
  end

  it "expands macro with block" do
    assert_type(<<-CR) { int32 }
      macro foo
        {{yield}}
      end

      foo do
        def bar
          1
        end
      end

      bar
      CR
  end

  describe "yield" do
    it "expands macro expression in def body in block" do
      assert_type(<<-CR) { int32 }
        macro foo
          {{yield 1}}
        end

        foo do |value|
          def bar
            {{value}}
          end
        end

        bar
        CR
    end

    it "expands macro expression with call" do
      assert_type <<-CR { string }
        macro foo
          {{ yield "foo" }}
        end

        foo {|x| {{ x.upcase }} }
        CR
    end

    it "returns ASTNode" do
      assert_type <<-CR { string }
        macro foo
          {{ (yield "foo").downcase }}
        end

        foo {|x| {{ x.upcase }} }
        CR
    end

    it "return value gets assigned to macro variable" do
      assert_type <<-CR { uint8 }
        macro foo
          {% x = yield "1" %}
          {{ x }}
        end

        # FIXME: The macro begin...end is a general workaround, not related to yield
        foo {|x| {% begin %}{{ x.id }}_u8{% end %} }
        CR
    end

    it "parses regex with string interpolation in macro literal" do
      assert_type <<-'CR' { string }
        macro filter
          {{ yield.stringify }}
        end

        foo = ""

        filter do
          /#{foo}/
        end
        CR
    end

    it "assigns to macro var" do
      assert_type <<-CR { int32 }
        macro foo
          {% x = yield "1" %}
          {{ x }}
        end

        foo {|x| {{ x.id }} }
        CR
    end

    it "assign block argument to macro var" do
      assert_type <<-CR { int32 }
        macro foo
          {% x = yield "1" %}
          {{ x }}
        end

        foo do |x|
          {% y = x %}
          {{ y.to_i }}
        end
        CR
    end

    it "block arguments stay in scope" do
      assert_type <<-CR { int32 }
        macro foo
          {% x = 1 %}
          {{ yield "foo" }}
          {{ x }}
        end

        foo {|x| }
        CR
    end

    it "inner macro vars stay in scope" do
      assert_type <<-CR { int32 }
        macro foo
          {% x = 1 %}
          {{ yield }}
          {{ x }}
        end

        foo { {% x = "" %} }
        CR
    end

    it "does not have access to outer macro vars" do
      assert_error <<-CR, "undefined macro variable 'x'"
        macro foo
          {% x = 1 %}
          {{ yield }}
        end

        foo { {{ x }} }
        CR
    end

    it "doesn't get confused by potential macro end token" do
      assert_type <<-CR { int32 }
        macro foo
          {{ yield }}
        end

        def bar(end a)
          a
        end

        foo do
          bar(
            end: 1
          )
        end
        CR
    end
  end

  it "errors if find macros but wrong arguments" do
    assert_error(<<-CR, "wrong number of arguments for macro 'foo' (given 1, expected 0)", inject_primitives: true)
      macro foo
        1
      end

      foo(1)
      CR
  end

  it "executes raise inside macro" do
    ex = assert_error(<<-CR, "OH NO")
      macro foo
        {{ raise "OH NO" }}
      end

      foo
      CR

    ex.to_s.should_not contain("expanding macro")
  end

  it "executes raise inside macro, with node (#5669)" do
    ex = assert_error(<<-CR, "OH")
      macro foo(x)
        {{ x.raise "OH\nNO" }}
      end

      foo(1)
      CR

    ex.to_s.should contain "NO"
    ex.to_s.should_not contain("expanding macro")
  end

  it "executes raise inside macro, with empty message (#8631)" do
    assert_error(<<-CR, "")
      macro foo
        {{ raise "" }}
      end

      foo
      CR
  end

  it "can specify tuple as return type" do
    assert_type(<<-CR) { tuple_of([int32, int32] of Type) }
      class Foo
        def foo : {Int32, Int32}
          {{ @type }}
          {1, 2}
        end
      end

      Foo.new.foo
      CR
  end

  it "allows specifying self as macro def return type" do
    assert_type(<<-CR) { types["Foo"] }
      class Foo
        def foo : self
          {{ @type }}
          self
        end
      end

      Foo.new.foo
      CR
  end

  it "allows specifying self as macro def return type (2)" do
    assert_type(<<-CR) { types["Bar"] }
      class Foo
        def foo : self
          {{ @type }}
          self
        end
      end

      class Bar < Foo
      end

      Bar.new.foo
      CR
  end

  it "errors if non-existent named arg" do
    assert_error(<<-CR, "no parameter named 'y'")
      macro foo(x = 1)
        {{x}} + 1
      end

      foo y: 2
      CR
  end

  it "errors if named arg already specified" do
    assert_error(<<-CR, "argument for parameter 'x' already specified")
      macro foo(x = 1)
        {{x}} + 1
      end

      foo 2, x: 2
      CR
  end

  it "finds macro in included module" do
    assert_type(<<-CR) { int32 }
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
      CR
  end

  it "errors when trying to define def inside def with macro expansion" do
    assert_error(<<-CR, "can't define def inside def")
      macro foo
        def bar; end
      end

      def baz
        foo
      end

      baz
      CR
  end

  it "gives precise location info when doing yield inside macro" do
    assert_error(<<-CR, "in line 6")
      macro foo
        {{yield}}
      end

      foo do
        1 + 'a'
      end
      CR
  end

  it "transforms with {{yield}} and call" do
    assert_type(<<-CR) { int32 }
      macro foo
        bar({{yield}})
      end

      def bar(value)
        value
      end

      def baz
        1
      end

      foo do
        baz
      end
      CR
  end

  it "can return class type in macro def" do
    assert_type(<<-CR) { types["Int32"].metaclass }
      class Foo
        def foo : Int32.class
          {{ @type }}
          Int32
        end
      end

      Foo.new.foo
      CR
  end

  it "can return virtual class type in macro def" do
    assert_type(<<-CR, inject_primitives: true) { types["Foo"].metaclass.virtual_type }
      class Foo
      end

      class Bar < Foo
      end

      class Foo
        def foo : Foo.class
          {{ @type }}
          1 == 1 ? Foo : Bar
        end
      end

      Foo.new.foo
      CR
  end

  it "can't define new variables (#466)" do
    error = assert_error <<-CR
      macro foo
        hello = 1
      end

      foo
      hello
      CR

    error.to_s.should_not contain("did you mean")
  end

  it "finds macro in included generic module" do
    assert_type(<<-CR) { int32 }
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
      CR
  end

  it "finds macro in inherited generic class" do
    assert_type(<<-CR) { int32 }
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
      CR
  end

  it "doesn't die on && inside if (bug)" do
    assert_type(<<-CR) { int32 }
      macro foo
        1 && 2
      end

      foo ? 3 : 4
      CR
  end

  it "checks if macro expansion returns (#821)" do
    assert_type(<<-CR) { nilable symbol }
      macro pass
        return :pass
      end

      def me
        pass
        nil
      end

      me
      CR
  end

  it "errors if declares macro inside if" do
    assert_error(<<-CR, "can't declare macro dynamically")
      if 1 == 2
        macro foo; end
      end
      CR
  end

  it "allows declaring class with macro if" do
    assert_type(<<-CR) { types["Foo"] }
      {% if true %}
        class Foo; end
      {% end %}

      Foo.new
      CR
  end

  it "allows declaring class with macro for" do
    assert_type(<<-CR) { types["Foo"] }
      {% for i in 0..0 %}
        class Foo; end
      {% end %}

      Foo.new
      CR
  end

  it "allows declaring class with inline macro expression (#1333)" do
    assert_type(<<-CR) { types["Foo"] }
      {{ "class Foo; end".id }}

      Foo.new
      CR
  end

  it "errors if requires inside class through macro expansion" do
    str = %(
      macro req
        require "bar"
      end

      class Foo
        req
      end
    )
    expect_raises SyntaxException, "can't require inside type declarations" do
      semantic parse str
    end
  end

  it "errors if requires inside if through macro expansion" do
    assert_error(<<-CR, "can't require dynamically")
      macro req
        require "bar"
      end

      if 1 == 2
        req
      end
      CR
  end

  it "can define constant via macro included" do
    assert_type(<<-CR) { int32 }
      module Mod
        macro included
          CONST = 1
        end
      end

      include Mod

      CONST
      CR
  end

  it "errors if applying protected modifier to macro" do
    assert_error(<<-CR, "can only use 'private' for macros")
      class Foo
        protected macro foo
          1
        end
      end

      Foo.foo
      CR
  end

  it "expands macro with break inside while (#1852)" do
    assert_type(<<-CR) { nil_type }
      macro test
        foo = "bar"
        break
      end

      while true
        test
      end
      CR
  end

  it "can access variable inside macro expansion (#2057)" do
    assert_type(<<-CR) { int32 }
      macro foo
        x
      end

      def method
        yield 1
      end

      method do |x|
        foo
      end
      CR
  end

  it "declares variable for macro with out" do
    assert_type(<<-CR) { int32 }
      lib LibFoo
        fun foo(x : Int32*)
      end

      macro some_macro
        z
      end

      LibFoo.foo(out z)
      some_macro
      CR
  end

  it "show macro trace in errors (1)" do
    ex = assert_error(<<-CR, "Error: expanding macro")
      macro foo
        Bar
      end

      foo
      CR

    ex.to_s.should contain "error in line 5"
  end

  it "show macro trace in errors (2)" do
    ex = assert_error(<<-CR, "Error: expanding macro")
      {% begin %}
        Bar
      {% end %}
      CR

    ex.to_s.should contain "error in line 1"
  end

  it "errors if using macro that is defined later" do
    assert_error(<<-CR, "macro 'foo' must be defined before this point but is defined later")
      class Bar
        foo
      end

      macro foo
      end
      CR
  end

  it "looks up argument types in macro owner, not in subclass (#2395)" do
    assert_type(<<-CR) { int32 }
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
      CR
  end

  it "doesn't error when adding macro call to constant (#2457)" do
    assert_type(<<-CR) { int32 }
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
      CR
  end

  it "errors if named arg matches single splat parameter" do
    assert_error(<<-CR, "no parameter named 'x'")
      macro foo(*y)
      end

      foo x: 1, y: 2
      CR
  end

  it "errors if named arg matches splat parameter" do
    assert_error(<<-CR, "wrong number of arguments for macro 'foo' (given 0, expected 1+)")
      macro foo(x, *y)
      end

      foo x: 1, y: 2
      CR
  end

  it "says missing argument because positional args don't match past splat" do
    assert_error(<<-CR, "missing argument: z")
      macro foo(x, *y, z)
      end

      foo 1, 2
      CR
  end

  it "allows named args after splat" do
    assert_type(<<-CR) { tuple_of([tuple_of([int32]), char]) }
      macro foo(*y, x)
        { {{y}}, {{x}} }
      end

      foo 1, x: 'a'
      CR
  end

  it "errors if missing one argument" do
    assert_error(<<-CR, "missing argument: z")
      macro foo(x, y, z)
      end

      foo x: 1, y: 2
      CR
  end

  it "errors if missing two arguments" do
    assert_error(<<-CR, "missing arguments: x, z")
      macro foo(x, y, z)
      end

      foo y: 2
      CR
  end

  it "doesn't include parameters with default values in missing arguments error" do
    assert_error(<<-CR, "missing argument: z")
      macro foo(x, z, y = 1)
      end

      foo(x: 1)
      CR
  end

  it "solves macro expression arguments before macro expansion (type)" do
    assert_type(<<-CR) { int32 }
      macro foo(x)
        {% if x.is_a?(TypeNode) && x.name == "String" %}
          1
        {% else %}
          'a'
        {% end %}
      end

      foo({{ String }})
      CR
  end

  it "solves macro expression arguments before macro expansion (constant)" do
    assert_type(<<-CR) { int32 }
      macro foo(x)
        {% if x.is_a?(NumberLiteral) && x == 1 %}
          1
        {% else %}
          'a'
        {% end %}
      end

      CONST = 1
      foo({{ CONST }})
      CR
  end

  it "solves named macro expression arguments before macro expansion (type) (#2423)" do
    assert_type(<<-CR) { int32 }
      macro foo(x)
        {% if x.is_a?(TypeNode) && x.name == "String" %}
          1
        {% else %}
          'a'
        {% end %}
      end

      foo(x: {{ String }})
      CR
  end

  it "solves named macro expression arguments before macro expansion (constant) (#2423)" do
    assert_type(<<-CR) { int32 }
      macro foo(x)
        {% if x.is_a?(NumberLiteral) && x == 1 %}
          1
        {% else %}
          'a'
        {% end %}
      end

      CONST = 1
      foo(x: {{ CONST }})
      CR
  end

  it "finds generic type argument of included module" do
    assert_type(<<-CR) { int32.metaclass }
      module Bar(T)
        def t
          {{ T }}
        end
      end

      class Foo(U)
        include Bar(U)
      end

      Foo(Int32).new.t
      CR
  end

  it "finds generic type argument of included module with self" do
    assert_type(<<-CR) { generic_class("Foo", int32).metaclass }
      module Bar(T)
        def t
          {{ T }}
        end
      end

      class Foo(U)
        include Bar(self)
      end

      Foo(Int32).new.t
      CR
  end

  it "finds free type vars" do
    assert_type(<<-CR) { tuple_of([int32.metaclass, string.metaclass]) }
      module Foo(T)
        def self.foo(foo : U) forall U
          { {{ T }}, {{ U }} }
        end
      end

      Foo(Int32).foo("foo")
      CR
  end

  it "gets named arguments in double splat" do
    assert_type(<<-CR) { named_tuple_of({"x": string, "y": bool}) }
      macro foo(**options)
        {{options}}
      end

      foo x: "foo", y: true
      CR
  end

  it "uses splat and double splat" do
    assert_type(<<-CR) { tuple_of([tuple_of([int32, char]), named_tuple_of({"x": string, "y": bool})]) }
      macro foo(*args, **options)
        { {{args}}, {{options}} }
      end

      foo 1, 'a', x: "foo", y: true
      CR
  end

  it "double splat and regular args" do
    assert_type(<<-CR) { tuple_of([int32, bool, named_tuple_of({"w": char, "z": string})]) }
      macro foo(x, y, **options)
        { {{x}}, {{y}}, {{options}} }
      end

      foo 1, w: 'a', y: true, z: "z"
      CR
  end

  it "declares multi-assign vars for macro" do
    assert_type(<<-CR) { int32 }
      macro id(x, y)
        {{x}}
        {{y}}
      end

      a, b = 1, 2
      id(a, b)
      1
      CR
  end

  it "declares rescue variable inside for macro" do
    assert_type(<<-CR) { int32 }
      macro id(x)
        {{x}}
      end

      begin
      rescue ex
        id(ex)
      end

      1
      CR
  end

  it "matches with default value after splat" do
    assert_type(<<-CR) { tuple_of([int32, tuple_of([char]), bool]) }
      macro foo(x, *y, z = true)
        { {{x}}, {{y}}, {{z}} }
      end

      foo 1, 'a'
      CR
  end

  it "uses bare *" do
    assert_type(<<-CR) { tuple_of([int32, char]) }
      macro foo(x, *, y)
        { {{x}}, {{y}} }
      end

      foo 10, y: 'a'
      CR
  end

  it "uses bare *, doesn't let more args" do
    assert_error(<<-CR, "wrong number of arguments for macro 'foo' (given 2, expected 1)")
      macro foo(x, *, y)
      end

      foo 10, 20, y: 30
      CR
  end

  it "uses bare *, doesn't let more args" do
    assert_error(<<-CR, "no overload matches")
      def foo(x, *, y)
      end

      foo 10, 20, y: 30
      CR
  end

  it "finds macro through alias (#2706)" do
    assert_type(<<-CR) { int32 }
      module Moo
        macro bar
          1
        end
      end

      alias Foo = Moo

      Foo.bar
      CR
  end

  it "can override macro (#2773)" do
    assert_type(<<-CR) { char }
      macro foo
        1
      end

      macro foo
        'a'
      end

      foo
      CR
  end

  it "works inside proc literal (#2984)" do
    assert_type(<<-CR, inject_primitives: true) { int32 }
      macro foo
        1
      end

      ->{ foo }.call
      CR
  end

  it "finds var in proc for macros" do
    assert_type(<<-CR, inject_primitives: true) { int32 }
      macro foo(x)
        {{x}}
      end

      ->(x : Int32) { foo(x) }.call(1)
      CR
  end

  it "applies visibility modifier only to first level" do
    assert_type(<<-CR) { int32 }
      macro foo
        class Foo
          def self.foo
            1
          end
        end
      end

      private foo

      Foo.foo
      CR
  end

  it "gives correct error when method is invoked but macro exists at the same scope" do
    assert_error(<<-CR, "undefined method 'foo'")
      macro foo(x)
      end

      class Foo
      end

      Foo.new.foo
      CR
  end

  it "uses uninitialized variable with macros" do
    assert_type(<<-CR) { int32 }
      macro foo(x)
        {{x}}
      end

      a = uninitialized Int32
      foo(a)
      CR
  end

  describe "skip_file macro directive" do
    it "skips expanding the rest of the current file" do
      res = semantic(<<-CR)
        class A
        end

        {% skip_file %}

        class B
        end
        CR

      res.program.types.has_key?("A").should be_true
      res.program.types.has_key?("B").should be_false
    end

    it "skips file inside an if macro expression" do
      res = semantic(<<-CR)
        class A
        end

        {% if true %}
          class C; end
          {% skip_file %}
          class D; end
        {% end %}

        class B
        end
        CR

      res.program.types.has_key?("A").should be_true
      res.program.types.has_key?("B").should be_false
      res.program.types.has_key?("C").should be_true
      res.program.types.has_key?("D").should be_false
    end
  end

  it "finds method before macro (#236)" do
    assert_type(<<-CR) { char }
      macro global
        1
      end

      class Foo
        def global
          'a'
        end

        def bar
          global
        end
      end

      Foo.new.bar
      CR
  end

  it "finds macro and method at the same scope" do
    assert_type(<<-CR) { tuple_of [int32, char] }
      macro global(x)
        1
      end

      def global(x, y)
        'a'
      end

      {global(1), global(1, 2)}
      CR
  end

  it "finds macro and method at the same scope inside included module" do
    assert_type(<<-CR) { tuple_of [int32, char] }
      module Moo
        macro global(x)
          1
        end

        def global(x, y)
          'a'
        end
      end

      class Foo
        include Moo

        def main
          {global(1), global(1, 2)}
        end
      end

      Foo.new.main
      CR
  end

  it "finds macro in included module at class level (#4639)" do
    assert_type(<<-CR) { int32 }
      module Moo
        macro foo
          def self.bar
            2
          end
        end
      end

      class Foo
        include Moo

        foo
      end

      Foo.bar
      CR
  end

  it "finds macro in module in Object" do
    assert_type(<<-CR) { int32 }
      class Object
        macro foo
          def self.bar
            2
          end
        end
      end

      module Moo
        foo
      end

      Moo.bar
      CR
  end

  it "finds metaclass instance of instance method (#4739)" do
    assert_type(<<-CR) { int32 }
      class Parent
        macro foo
          def self.bar
            1
          end
        end
      end

      class Child < Parent
        def foo
        end
      end

      class GrandChild < Child
        foo
      end

      GrandChild.bar
      CR
  end

  it "finds metaclass instance of instance method (#4639)" do
    assert_type(<<-CR) { int32 }
      module Include
        macro foo
          def foo
            1
          end
        end
      end

      class Parent
        include Include

        foo
      end

      class Foo < Parent
        foo
      end

      Foo.new.foo
      CR
  end

  it "can lookup type parameter when macro is called inside class (#5343)" do
    assert_type(<<-CR) { int32.metaclass }
      class Foo(T)
        macro foo
          {{T}}
        end
      end

      alias FooInt32 = Foo(Int32)

      class Bar
        def self.foo
          FooInt32.foo
        end
      end

      Bar.foo
      CR
  end

  it "cannot lookup type defined in caller class" do
    assert_error(<<-CR, "undefined constant Baz")
      class Foo
        macro foo
          {{Baz}}
        end
      end

      class Bar
        def self.foo
          Foo.foo
        end

        class Baz
        end
      end

      Bar.foo
      CR
  end

  it "clones default value before expanding" do
    assert_type(<<-CR) { nil_type }
      FOO = {} of String => String?

      macro foo(x = {} of String => String)
        {% FOO["foo"] = x["foo"] %}
        {% x["foo"] = "foo" %}
      end

      foo
      foo
      {{ FOO["foo"] }}
      CR
  end

  it "does macro verbatim inside macro" do
    assert_type(<<-CR) { types["Bar"].metaclass }
      class Foo
        macro inherited
          {% verbatim do %}
            def foo
              {{ @type }}
            end
          {% end %}
        end
      end

      class Bar < Foo
      end

      Bar.new.foo
      CR
  end

  it "does macro verbatim outside macro" do
    assert_type(<<-CR) { int32 }
      {% verbatim do %}
        1
      {% end %}
      CR
  end

  it "evaluates yield expression (#2924)" do
    assert_type(<<-CR) { string }
      macro a(b)
        {{yield b}}
      end

      a("foo") do |c|
        {{c}}
      end
      CR
  end

  it "finds generic in macro code" do
    assert_type(<<-CR) { array_of(string).metaclass }
      {% begin %}
        {{ Array(String) }}
      {% end %}
      CR
  end

  it "finds generic in macro code using free var" do
    assert_type(<<-CR) { array_of(int32).metaclass }
      class Foo(T)
        def self.foo
          {% begin %}
            {{ Array(T) }}
          {% end %}
        end
      end

      Foo(Int32).foo
      CR
  end

  it "expands multiline macro expression in verbatim (#6643)" do
    assert_type(<<-CR) { int32 }
      {% verbatim do %}
        {{
          if true
            1
            "2"
            3
          end
        }}
      {% end %}
      CR
  end

  it "can use macro in instance var initializer (#7666)" do
    assert_type(<<-CR) { string }
      class Foo
        macro m
          "test"
        end

        @x : String = m

        def x
          @x
        end
      end

      Foo.new.x
      CR
  end

  it "can use macro in instance var initializer (just assignment) (#7666)" do
    assert_type(<<-CR) { string }
      class Foo
        macro m
          "test"
        end

        @x = m

        def x
          @x
        end
      end

      Foo.new.x
      CR
  end

  it "shows correct error message in macro expansion (#7083)" do
    assert_error(<<-CR, "can't instantiate abstract class Foo")
      abstract class Foo
        {% begin %}
          def self.new
            allocate
          end
        {% end %}
      end

      Foo.new
      CR
  end

  it "doesn't crash on syntax error inside macro (regression, #8038)" do
    expect_raises(Crystal::SyntaxException, "unterminated array literal") do
      semantic(<<-CR)
        {% begin %}[{% end %}
        CR
    end
  end

  it "has correct location after expanding assignment after instance var" do
    result = semantic <<-CR
      macro foo(x)       #  1
        @{{x}}           #  2
                         #  3
        def bar          #  4
        end              #  5
      end                #  6
                         #  7
      class Foo          #  8
        foo(x = 1)       #  9
      end
      CR

    method = result.program.types["Foo"].lookup_first_def("bar", false).not_nil!
    method.location.not_nil!.expanded_location.not_nil!.line_number.should eq(9)
  end

  it "executes OpAssign (#9356)" do
    assert_type(<<-CR) { int32 }
      {% begin %}
        {% a = nil %}
        {% a ||= 1 %}
        {% if a %}
          1
        {% else %}
          'a'
        {% end %}
      {% end %}
      CR
  end

  it "executes MultiAssign" do
    assert_type(<<-CR) { tuple_of([int32, int32] of Type) }
      {% begin %}
        {% a, b = 1, 2 %}
        { {{a}}, {{b}} }
      {% end %}
      CR
  end

  it "executes MultiAssign with ArrayLiteral value" do
    assert_type(<<-CR) { tuple_of([int32, int32] of Type) }
      {% begin %}
        {% xs = [1, 2] %}
        {% a, b = xs %}
        { {{a}}, {{b}} }
      {% end %}
      CR
  end
end
