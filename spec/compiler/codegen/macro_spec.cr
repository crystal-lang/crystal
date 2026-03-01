require "../../spec_helper"

describe "Code gen: macro" do
  it "expands macro" do
    run("macro foo; 1 &+ 2; end; foo").to_i.should eq(3)
  end

  it "expands macro with arguments" do
    run(<<-CRYSTAL).to_i.should eq(3)
      macro foo(n)
        {{n}} &+ 2
      end

      foo(1)
      CRYSTAL
  end

  it "expands macro that invokes another macro" do
    run(<<-CRYSTAL).to_i.should eq(3)
      macro foo
        def x
          1 &+ 2
        end
      end

      macro bar
        foo
      end

      bar
      x
      CRYSTAL
  end

  it "expands macro defined in class" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        macro foo
          def bar
            1
          end
        end

        foo
      end

      foo = Foo.new
      foo.bar
      CRYSTAL
  end

  it "expands macro defined in base class" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Object
        macro foo
          def bar
            1
          end
        end
      end

      class Foo
        foo
      end

      foo = Foo.new
      foo.bar
      CRYSTAL
  end

  it "expands inline macro" do
    run(<<-CRYSTAL).to_i.should eq(1)
      a = {{ 1 }}
      a
      CRYSTAL
  end

  it "expands inline macro for" do
    run(<<-CRYSTAL).to_i.should eq(6)
      a = 0
      {% for i in [1, 2, 3] %}
        a &+= {{i}}
      {% end %}
      a
      CRYSTAL
  end

  it "expands inline macro if (true)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      a = 0
      {% if 1 == 1 %}
        a &+= 1
      {% end %}
      a
      CRYSTAL
  end

  it "expands inline macro if (false)" do
    run(<<-CRYSTAL).to_i.should eq(0)
      a = 0
      {% if 1 == 2 %}
        a &+= 1
      {% end %}
      a
      CRYSTAL
  end

  it "finds macro in class" do
    run(<<-CRYSTAL).to_i.should eq(3)
      class Foo
        macro foo
          1 &+ 2
        end

        def bar
          foo
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "expands def macro" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def bar_baz
        1
      end

      def foo : Int32
        {% begin %}
          bar_{{ "baz".id }}
        {% end %}
      end

      foo
      CRYSTAL
  end

  it "expands def macro with var" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def foo : Int32
          {{ @type }}
          a = {{ 1 }}
        end
      end

      Foo.new.foo
      CRYSTAL
  end

  it "expands def macro with @type.instance_vars" do
    run(<<-CRYSTAL).to_string.should eq("x")
      class Foo
        def initialize(@x : Int32)
        end

        def to_s : String
          {{ @type.instance_vars.first.stringify }}
        end
      end

      foo = Foo.new(1)
      foo.to_s
      CRYSTAL
  end

  it "expands def macro with @type.instance_vars with subclass" do
    run(<<-CRYSTAL).to_string.should eq("y")
      class Reference
        def to_s : String
          {{ @type.instance_vars.last.stringify }}
        end
      end

      class Foo
        def initialize(@x : Int32)
        end
      end

      class Bar < Foo
        def initialize(@x : Int32, @y : Int32)
        end
      end

      Bar.new(1, 2).to_s
      CRYSTAL
  end

  it "expands def macro with @type.instance_vars with virtual" do
    run(<<-CRYSTAL).to_string.should eq("y")
      class Reference
        def to_s : String
          {{ @type.instance_vars.last.stringify }}
        end
      end

      class Foo
        def initialize(@x : Int32)
        end
      end

      class Bar < Foo
        def initialize(@x : Int32, @y : Int32)
        end
      end

      (Bar.new(1, 2) || Foo.new(1)).to_s
      CRYSTAL
  end

  it "expands def macro with @type.name" do
    run(<<-CRYSTAL).to_string.should eq("Foo")
      class Foo
        def initialize(@x : Int32)
        end

        def to_s : String
          {{@type.name.stringify}}
        end
      end

      foo = Foo.new(1)
      foo.to_s
      CRYSTAL
  end

  it "expands macro and resolves type correctly" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def foo : Int32
          {{ @type }}
          1
        end
      end

      class Bar < Foo
        Int32 = 2
      end

      Bar.new.foo
      CRYSTAL
  end

  it "expands def macro with @type.name with virtual" do
    run(<<-CRYSTAL).to_string.should eq("Bar")
      class Reference
        def to_s : String
          {{ @type.name.stringify }}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      (Bar.new || Foo.new).to_s
      CRYSTAL
  end

  it "expands def macro with @type.name with virtual (2)" do
    run(<<-CRYSTAL).to_string.should eq("Foo")
      class Reference
        def to_s : String
          {{ @type.name.stringify }}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      (Foo.new || Bar.new).to_s
      CRYSTAL
  end

  it "allows overriding macro definition when redefining base class" do
    run(<<-CRYSTAL).to_string.should eq("OH NO")
      class Foo
        def inspect : String
          {{@type.name.stringify}}
        end
      end

      class Bar < Foo
      end

      class Foo
        def inspect
          "OH NO"
        end
      end

      Bar.new.inspect
      CRYSTAL
  end

  it "uses invocation context" do
    run(<<-CRYSTAL).to_string.should eq("Foo")
      macro foo
        def bar
          {{@type.name.stringify}}
        end
      end

      class Foo
        foo
      end

      Foo.new.bar
      CRYSTAL
  end

  it "allows macro with default arguments" do
    run(<<-CRYSTAL).to_i.should eq(3)
      def bar
        2
      end

      macro foo(x, y = :bar)
        {{x}} &+ {{y.id}}
      end

      foo(1)
      CRYSTAL
  end

  it "expands def macro with instance var and method call (bug)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      struct Nil
        def to_i!
          0
        end
      end

      class Foo
        @name : Int32?

        def foo : Int32
          {{ @type }}
          name = 1
          @name = name
        end
      end

      Foo.new.foo.to_i!
      CRYSTAL
  end

  it "expands @type.name in virtual metaclass (1)" do
    run(<<-CRYSTAL).to_string.should eq("Foo")
      class Class
        def to_s : String
          {{ @type.name.stringify }}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      p = Pointer(Foo.class).malloc(1_u64)
      p.value = Bar
      p.value = Foo
      p.value.to_s
      CRYSTAL
  end

  it "expands @type.name in virtual metaclass (2)" do
    run(<<-CRYSTAL).to_string.should eq("Bar")
      class Class
        def to_s : String
          {{ @type.name.stringify }}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      p = Pointer(Foo.class).malloc(1_u64)
      p.value = Foo
      p.value = Bar
      p.value.to_s
      CRYSTAL
  end

  it "doesn't skip abstract classes when defining macro methods" do
    run(<<-CRYSTAL).to_i.should eq(2)
      class Object
        def foo : Int32
          {{ @type }}
          1
        end
      end

      class Type
      end

      class ModuleType < Type
        def foo
          2
        end
      end

      class Type1 < ModuleType
      end

      class Type2 < Type
      end

      t = Type1.new || Type2.new
      t.foo
      CRYSTAL
  end

  it "doesn't reuse macro nodes (bug)" do
    run(<<-CRYSTAL).to_i.should eq(2)
      struct Float
        def &+(other)
          self + other
        end
      end

      def foo(x)
        {% for y in [1, 2] %}
          x &+ 1
        {% end %}
      end

      foo 1
      foo(1.5).to_i!
      CRYSTAL
  end

  it "can use constants" do
    run(<<-CRYSTAL).to_i.should eq(1)
      CONST = 1
      {{ CONST }}
      CRYSTAL
  end

  it "can refer to types" do
    run(<<-CRYSTAL).to_string.should eq("y")
      class Foo
        def initialize(@x : Int32, @y : Int32)
        end

        def foo : String
          {{ @type }}
          {{ Foo.instance_vars.last.name.stringify }}
        end

      end

      Foo.new(1, 2).foo
      CRYSTAL
  end

  it "runs macro with splat" do
    run(<<-CRYSTAL).to_i.should eq(3)
      macro foo(*args)
        {{args.size}}
      end

      foo 1, 1, 1
      CRYSTAL
  end

  it "runs macro with arg and splat" do
    run(<<-CRYSTAL).to_i.should eq(3)
      macro foo(name, *args)
        {{args.size}}
      end

      foo bar, 1, 1, 1
      CRYSTAL
  end

  it "expands macro that yields" do
    run(<<-CRYSTAL).to_i.should eq(3)
      def foo
        {% for i in 0 .. 2 %}
          yield {{i}}
        {% end %}
      end

      a = 0
      foo do |x|
        a &+= x
      end
      a
      CRYSTAL
  end

  it "can refer to abstract (1)" do
    run(<<-CRYSTAL).to_b.should be_false
      class Foo
      end

      {{ Foo.abstract? }}
      CRYSTAL
  end

  it "can refer to abstract (2)" do
    run(<<-CRYSTAL).to_b.should be_true
      abstract class Foo
      end

      {{ Foo.abstract? }}
      CRYSTAL
  end

  it "can refer to @type" do
    run(<<-CRYSTAL).to_string.should eq("Foo")
      class Foo
        def foo : String
          {{@type.name.stringify}}
        end
      end

      Foo.new.foo
      CRYSTAL
  end

  it "can refer to union (1)" do
    run(<<-CRYSTAL).to_b.should be_false
      {{Int32.union?}}
      CRYSTAL
  end

  it "can refer to union (2)" do
    run(<<-CRYSTAL).to_b.should be_true
      class Foo
        def initialize
          @x = 1; @x = 1.1
        end
        def foo
          {{ @type.instance_vars.first.type.union? }}
        end
      end
      Foo.new.foo
      CRYSTAL
  end

  it "can iterate union types" do
    run(<<-CRYSTAL).to_string.should eq("Float64-Int32")
      class Foo
        def initialize
          @x = 1; @x = 1.1
        end
        def foo
          {{ @type.instance_vars.first.type.union_types.map(&.name).sort.join("-") }}
        end
      end
      Foo.new.foo
      CRYSTAL
  end

  it "can access type variables" do
    run(<<-CRYSTAL).to_string.should eq("Int32")
      class Foo(T)
        def foo
          {{ @type.type_vars.first.name.stringify }}
        end
      end
      Foo(Int32).new.foo
      CRYSTAL
  end

  it "can access type variables of a module" do
    run(<<-CRYSTAL).to_string.should eq("Int32")
      module Foo(T)
        def self.foo
          {{ @type.type_vars.first.name.stringify }}
        end
      end
      Foo(Int32).foo
      CRYSTAL
  end

  it "can access type variables that are not types" do
    run(<<-CRYSTAL).to_b.should be_true
      class Foo(T)
        def foo
          {{ @type.type_vars.first.is_a?(NumberLiteral) }}
        end
      end
      Foo(1).new.foo
      CRYSTAL
  end

  it "can access type variables of a tuple" do
    run(<<-CRYSTAL).to_string.should eq("Int32")
      struct Tuple
        def foo
          {{ @type.type_vars.first.name.stringify }}
        end
      end
      {1, 2, 3}.foo
      CRYSTAL
  end

  it "can access type variables of a generic type" do
    run(<<-CRYSTAL).to_string.should eq("T-K")
      class Foo(T, K)
        def self.foo : String
          {{ @type.type_vars.map(&.stringify).join("-") }}
        end
      end
      Foo.foo
      CRYSTAL
  end

  it "receives &block" do
    run(<<-CRYSTAL).to_i.should eq(2)
      macro foo(&block)
        bar {{block}}
      end

      def bar
        yield 1
      end

      foo do |x|
        x &+ 1
      end
      CRYSTAL
  end

  it "executes with named arguments" do
    run(<<-CRYSTAL).to_i.should eq(3)
      macro foo(x = 1)
        {{x}} &+ 1
      end

      foo x: 2
      CRYSTAL
  end

  it "gets correct class name when there are classes in the middle" do
    run(<<-CRYSTAL).to_string.should eq("Qux")
      class Foo
        def class_desc : String
          {{@type.name.stringify}}
        end
      end

      class Bar < Foo
      end

      class Baz < Bar
      end

      class Qux < Bar
      end

      a = Pointer(Foo).malloc(1_u64)
      a.value = Qux.new
      a.value.class_desc
      CRYSTAL
  end

  it "transforms hooks (bug)" do
    codegen(<<-CRYSTAL)
      require "prelude"

      module GC
        def self.add_finalizer(object : T)
          object.responds_to?(:finalize)
        end
      end

      abstract class Foo
        ALL = Pointer(Foo).malloc(1_u64)

        macro inherited
          ALL.value = new
        end
      end

      class Bar < Foo
      end
      CRYSTAL
  end

  it "executes subclasses" do
    run(<<-CRYSTAL).to_string.should eq("Bar-Baz")
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      class Qux < Baz
      end

      {{ Foo.subclasses.map(&.name).join("-") }}
      CRYSTAL
  end

  it "executes all_subclasses" do
    run(<<-CRYSTAL).to_string.should eq("Bar-Baz")
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Bar
      end

      {{ Foo.all_subclasses.map(&.name).join("-") }}
      CRYSTAL
  end

  it "gets enum members with @type.constants" do
    run(<<-CRYSTAL).to_i.should eq(0 + 1 + 2)
      enum Color
        Red
        Green
        Blue

        def self.red
          {{@type.constants[0]}}
        end

        def self.green
          {{@type.constants[1]}}
        end

        def self.blue
          {{@type.constants[2]}}
        end
      end

      Color.red.value &+ Color.green.value &+ Color.blue.value
      CRYSTAL
  end

  it "gets enum members as constants" do
    run(<<-CRYSTAL).to_string.should eq("Green")
      enum Color
        Red
        Green
        Blue
      end

      {{Color.constants[1].stringify}}
      CRYSTAL
  end

  it "says that enum has Flags annotation" do
    run(<<-CRYSTAL).to_b.should be_true
      @[Flags]
      enum Color
        Red
        Green
        Blue
      end

      {{Color.annotation(Flags) ? true : false}}
      CRYSTAL
  end

  it "says that enum doesn't have Flags annotation" do
    run(<<-CRYSTAL).to_b.should be_false
      enum Color
        Red
        Green
        Blue
      end

      {{Color.annotation(Flags) ? true : false}}
      CRYSTAL
  end

  it "gets methods" do
    run(<<-CRYSTAL).to_string.should eq("bar")
      class Foo
        def bar
          1
        end

        def first_method_name : String
          {{ @type.methods.map(&.name.stringify).first }}
        end
      end

      Foo.new.first_method_name
      CRYSTAL
  end

  it "copies base macro def to sub-subtype even after it was copied to a subtype (#448)" do
    run(<<-CRYSTAL).to_string.should eq("Baz")
      class Object
        def class_name : String
          {{@type.name.stringify}}
        end
      end

      class Foo
        @@children : Pointer(Foo)
        @@children = Pointer(Foo).malloc(1_u64)

        def self.children
          @@children
        end
      end

      Foo.children.value = Foo.new
      Foo.children.value.class_name

      class Bar < Foo; end

      Foo.children.value = Bar.new
      Foo.children.value.class_name

      class Baz < Bar; end
      Foo.children.value = Baz.new
      Foo.children.value.class_name
      CRYSTAL
  end

  it "recalculates method when virtual metaclass type is added" do
    run(<<-CRYSTAL).to_string.should eq("Test, RunnableTest")
      require "prelude"

      class Global
        @@x = [] of String
        @@runnables = [] of Runnable.class

        def self.x=(@@x)
        end

        def self.x
          @@x
        end

        def self.runnables
          @@runnables
        end
      end

      def run
        Global.runnables.each &.run
      end

      class Runnable
      end

      class Runnable
        macro inherited
          Global.runnables << self
        end

        def self.run : Nil
          Global.x << {{@type.name.stringify}}
          nil
        end
      end

      class Test < Runnable
      end

      run
      Global.x.clear

      class RunnableTest < Test
      end

      run
      Global.x.join(", ")
      CRYSTAL
  end

  it "correctly recomputes call (bug)" do
    run(<<-CRYSTAL).to_string.should eq("Baz")
      class Object
        def in_object
          in_class(1)
        end
      end

      class Class
        def in_class(x)
          bar
        end

        def bar : String
          {{@type.name.stringify}}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      f = Bar.new || Foo.new
      f.class.in_object

      class Baz < Foo
      end

      f2 = Baz.new || Foo.new
      f2.class.in_object
      CRYSTAL
  end

  it "doesn't override local variable when using macro variable" do
    run(<<-CRYSTAL).to_i.should eq(1)
      macro foo(x)
        %a = {{x}}
        %a
      end

      a = 1
      foo(2)
      foo(3)
      a
      CRYSTAL
  end

  it "doesn't override local variable when using macro variable (2)" do
    run(<<-CRYSTAL).to_i.should eq(26)
      macro foo(x)
        %a = {{x}} &+ 10
        %a
      end

      a = 1
      z = foo(2)
      w = foo(3)
      a &+ z &+ w
      CRYSTAL
  end

  it "uses indexed macro variable" do
    run(<<-CRYSTAL).to_i.should eq(4 + 5 + 6 + 40 + 50 + 60)
      macro foo(*elems)
        {% for elem, i in elems %}
          %var{i} = {{elem}}
        {% end %}

        %total = 0
        {% for elem, i in elems %}
          %total &+= %var{i}
        {% end %}
        %total
      end

      z = 0
      z &+= foo 4, 5, 6
      z &+= foo 40, 50, 60
      z
      CRYSTAL
  end

  it "uses indexed macro variable with many keys" do
    run(<<-CRYSTAL).to_i.should eq(4 + 5 + 6)
      macro foo(*elems)
        {% for elem, i in elems %}
          %var{elem, i} = {{elem}}
        {% end %}

        %total = 0
        {% for elem, i in elems %}
          %total &+= %var{elem, i}
        {% end %}
        %total
      end

      z = foo 4, 5, 6
      z
      CRYSTAL
  end

  it "codegens macro def with splat (#496)" do
    run(<<-CRYSTAL).to_i.should eq(6)
      class Foo
        def bar(*args) : Int32
          {{ @type }}
          args[0] &+ args[1] &+ args[2]
        end
      end

      Foo.new.bar(1, 2, 3)
      CRYSTAL
  end

  it "codegens macro def with default arg (similar to #496)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      class Foo
        def bar(foo = 1) : Int32
          {{ @type }}
          foo &+ 2
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "expands macro with default arg and splat (#784)" do
    run(<<-CRYSTAL).to_string.should eq("5")
      macro some_macro(a=5, *args)
        {{a.stringify}}
      end

      some_macro
      CRYSTAL
  end

  it "expands macro with default arg and splat (2) (#784)" do
    run(<<-CRYSTAL).to_string.should eq("1")
      macro some_macro(a=5, *args)
        {{a.stringify}}
      end

      some_macro 1, 2, 3, 4
      CRYSTAL
  end

  it "expands macro with default arg and splat (3) (#784)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      macro some_macro(a=5, *args)
        {{args.size}}
      end

      some_macro 1, 2, 3, 4
      CRYSTAL
  end

  it "checks if macro expansion returns (#821)" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(123)
      macro pass
        return 123
      end

      def me
        pass
        nil
      end

      me || 0
      CRYSTAL
  end

  it "passes #826" do
    run(<<-CRYSTAL).to_i.should eq(123)
      macro foo
        macro bar
          {{yield}}
        end
      end

      foo do
        123
      end

      bar
      CRYSTAL
  end

  it "declares constant in macro (#838)" do
    run(<<-CRYSTAL).to_i.should eq(123)
      macro foo
        {{yield}}
      end

      foo do
        CONST = 123
      end

      CONST
      CRYSTAL
  end

  it "errors if dynamic constant assignment after macro expansion" do
    assert_error <<-CRYSTAL, "dynamic constant assignment. Constants can only be declared at the top level or inside other types."
      macro foo
        X = 123
      end

      def bar
        foo
      end

      bar
      CRYSTAL
  end

  it "finds macro from virtual type" do
    run(<<-CRYSTAL).to_i.should eq(123)
      class Foo
        macro foo
          123
        end

        def bar
          foo
        end
      end

      class Bar < Foo
      end

      a = Pointer(Foo).malloc(1_u64)
      a.value = Foo.new
      a.value.bar
      CRYSTAL
  end

  it "expands macro with escaped quotes (#895)" do
    run(<<-CRYSTAL).to_string.should eq(%(hello"))
      macro foo(x)
        "{{x}}\\""
      end

      foo hello
      CRYSTAL
  end

  it "expands macro def with return (#1040)" do
    run(<<-CRYSTAL).to_i.should eq(123)
      class Foo
        def a : Int32
          {{ @type }}
          return 123
        end
      end

      Foo.new.a
      CRYSTAL
  end

  it "fixes empty types of macro expansions (#1379)" do
    run(<<-CRYSTAL).to_i.should eq(123)
      macro lala(exp)
        {{exp}}
      end

      def foo
        bar do
          return 123
        end
      end

      def bar
        return yield
      end

      lala foo
      CRYSTAL
  end

  it "expands macro as class method" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        macro bar
          1
        end
      end

      Foo.bar
      CRYSTAL
  end

  it "expands macro as class method and accesses @type" do
    run(<<-CRYSTAL).to_string.should eq("Foo")
      class Foo
        macro bar
          {{@type.stringify}}
        end
      end

      Foo.bar
      CRYSTAL
  end

  it "codegens macro with comment (bug) (#1396)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      macro my_macro
        # {{ 1 }}
        {{ 1 }}
      end

      my_macro
      CRYSTAL
  end

  it "correctly resolves constant inside block in macro def" do
    run(<<-CRYSTAL).to_i.should eq(123)
      def foo
        yield
      end

      class Foo
        Const = 123

        def self.bar : Int32
          {{ @type }}
          foo { Const }
        end
      end

      Foo.bar
      CRYSTAL
  end

  it "can access free variables" do
    run(<<-CRYSTAL).to_string.should eq("Int32")
      def foo(x : T) forall T
        {{ T.stringify }}
      end

      foo(1)
      CRYSTAL
  end

  it "types macro expansion bug (#1734)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def foo : Int32
          {{ @type }}
          1 || 2
        end
      end

      class Bar < Foo
      end

      x = true ? Foo.new : Bar.new
      x.foo
      CRYSTAL
  end

  it "expands Path with resolve method" do
    run(<<-CRYSTAL).to_i.should eq(1)
      CONST = 1

      macro id(path)
        {{path.resolve}}
      end

      id(CONST)
      CRYSTAL
  end

  it "can use macro inside array literal" do
    run(<<-CRYSTAL).to_i.should eq(42)
      require "prelude"

      macro foo
        42
      end

      ary = [foo]
      ary[0]
      CRYSTAL
  end

  it "can use macro inside hash literal" do
    run(<<-CRYSTAL).to_i.should eq(42)
      require "prelude"

      macro foo
        42
      end

      hash = {foo => foo}
      hash[foo]
      CRYSTAL
  end

  it "executes with named arguments for positional arg (1)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      macro foo(x)
        {{x}} &+ 1
      end

      foo x: 2
      CRYSTAL
  end

  it "executes with named arguments for positional arg (2)" do
    run(<<-CRYSTAL).to_i.should eq(6)
      macro foo(x, y)
        {{x}} &+ {{y}} &+ 1
      end

      foo x: 2, y: 3
      CRYSTAL
  end

  it "executes with named arguments for positional arg (3)" do
    run(<<-CRYSTAL).to_i.should eq(6)
      class String
        def bytesize
          @bytesize
        end
      end

      macro foo(x, y)
        {{x}} &+ {{y}}.bytesize &+ 1
      end

      foo y: "foo", x: 2
      CRYSTAL
  end

  it "stringifies type without virtual marker" do
    run(<<-CRYSTAL).to_i.should eq(2)
      class Foo
        def foo_m : Int32
          {{ @type }}.foo
        end

        def self.foo
          1
        end
      end

      class Bar < Foo
        def self.foo
          2
        end
      end

      (Bar.new || Foo.new).foo_m
      CRYSTAL
  end

  it "uses tuple T in method with free vars" do
    run(<<-CRYSTAL).to_i.should eq(2)
      struct Tuple
        def foo(x : U) forall U
          {{T.size}}
        end
      end

      {1, 3}.foo(1)
      CRYSTAL
  end

  it "implicitly marks method as macro def when using @type" do
    run(<<-CRYSTAL).to_string.should eq("Bar")
      class Foo
        def method
          {{@type.stringify}}
        end
      end

      class Bar < Foo
      end

      Bar.new.as(Foo).method
      CRYSTAL
  end

  it "doesn't replace %s in string (#2178)" do
    run(<<-CRYSTAL).to_string.should eq("hello %s")
      {% begin %}
        "hello %s"
      {% end %}
      CRYSTAL
  end

  it "doesn't replace %q() (#2178)" do
    run(<<-CRYSTAL).to_string.should eq("hello")
      {% begin %}
        %q(hello)
      {% end %}
      CRYSTAL
  end

  it "replaces %s inside string inside interpolation (#2178)" do
    run(<<-CRYSTAL).to_string.should eq("hello world")
      require "prelude"

      {% begin %}
        %a = "world"
        "hello \#{ %a }"
      {% end %}
      CRYSTAL
  end

  it "replaces %s inside string inside interpolation, with braces (#2178)" do
    run(<<-CRYSTAL).to_string.should eq(%(hello [{"world", "world"}, "world"]))
      require "prelude"

      {% begin %}
        %a = "world"
        "hello \#{ [{ %a, %a }, %a] }"
      {% end %}
      CRYSTAL
  end

  it "retains original yield expression (#2923)" do
    run(<<-CRYSTAL).to_string.should eq("hi")
      macro foo
        def bar(baz)
          {{yield}}
        end
      end

      foo do
        baz
      end

      bar("hi")
      CRYSTAL
  end

  it "surrounds {{yield}} with begin/end" do
    run(<<-CRYSTAL).to_i.should eq(2)
      macro foo
        a = {{yield}}
      end

      a = 0
      foo do
        1
        2
      end
      a
      CRYSTAL
  end

  it "initializes instance var in macro" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(1)
      class Foo
        {% begin %}
          @x = 1
        {% end %}
      end

      Foo.new.@x
      CRYSTAL
  end

  it "initializes class var in macro" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(1)
      class Foo
        {% begin %}
          @@x = 1
        {% end %}

        def self.x
          @@x
        end
      end

      Foo.x
      CRYSTAL
  end

  it "expands @def in inline macro" do
    run(<<-CRYSTAL).to_string.should eq("foo")
      def foo
        {{@def.name.stringify}}
      end

      foo
      CRYSTAL
  end

  it "expands @def in macro" do
    run(<<-CRYSTAL).to_string.should eq("bar")
      macro foo
        {{@def.name.stringify}}
      end

      def bar
        foo
      end

      bar
      CRYSTAL
  end

  it "gets constant" do
    run(<<-CRYSTAL).to_i.should eq(42)
      class Foo
        Bar = 42
      end

      {{ Foo.constant("Bar") }}
      CRYSTAL
  end

  it "determines if overrides (false)" do
    run(<<-CRYSTAL).to_b.should be_false
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
      end

      {{ Bar.overrides?(Foo, "foo") }}
      CRYSTAL
  end

  it "determines if overrides (true)" do
    run(<<-CRYSTAL).to_b.should be_true
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

      {{ Bar.overrides?(Foo, "foo") }}
      CRYSTAL
  end

  it "determines if overrides, through another class (true)" do
    run(<<-CRYSTAL).to_b.should be_true
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

      class Baz < Bar
      end

      {{ Baz.overrides?(Foo, "foo") }}
      CRYSTAL
  end

  it "determines if overrides, through module (true)" do
    run(<<-CRYSTAL).to_b.should be_true
      class Foo
        def foo
          1
        end
      end

      module Moo
        def foo
          2
        end
      end

      class Bar < Foo
        include Moo
      end

      class Baz < Bar
      end

      {{ Baz.overrides?(Foo, "foo") }}
      CRYSTAL
  end

  it "determines if overrides, with macro method (false)" do
    run(<<-CRYSTAL).to_b.should be_false
      class Foo
        def foo
          {{ @type }}
        end
      end

      class Bar < Foo
      end

      (Foo.new || Bar.new).foo

      def x
        {{ Bar.overrides?(Foo, "foo") }}
      end

      x
      CRYSTAL
  end

  it "determines if method exists (true)" do
    run(<<-CRYSTAL).to_b.should be_true
      class Foo
        def foo
          42
        end
      end

      {{ Foo.has_method?(:foo) }}
      CRYSTAL
  end

  it "determines if method exists (false)" do
    run(<<-CRYSTAL).to_b.should be_false
      class Foo
        def foo
          42
        end
      end

      {{ Foo.has_method?(:bar) }}
      CRYSTAL
  end

  it "forwards file location" do
    run(<<-CRYSTAL, filename: "bar.cr").to_string.should eq("bar.cr")
      macro foo
        bar
      end

      macro bar(file = __FILE__)
        {{file}}
      end

      foo
      CRYSTAL
  end

  it "forwards dir location" do
    run(<<-CRYSTAL, filename: "somedir/bar.cr").to_string.should eq("somedir")
      macro foo
        bar
      end

      macro bar(dir = __DIR__)
        {{dir}}
      end

      foo
      CRYSTAL
  end

  it "forwards line number" do
    run(<<-CRYSTAL, filename: "somedir/bar.cr", inject_primitives: false).to_i.should eq(9)
      macro foo
        bar
      end

      macro bar(line = __LINE__)
        {{line}}
      end

      foo
      CRYSTAL
  end

  it "keeps line number with no block" do
    run(<<-CRYSTAL, filename: "somedir/bar.cr", inject_primitives: false).to_i.should eq(6)
      macro foo
        {{ yield }}
        __LINE__
      end

      foo
      CRYSTAL
  end

  it "keeps line number with a block" do
    run(<<-CRYSTAL, filename: "somedir/bar.cr", inject_primitives: false).to_i.should eq(6)
      macro foo
        {{ yield }}
        __LINE__
      end

      foo do
        1
      end
      CRYSTAL
  end

  it "resolves alias in macro" do
    run(<<-CRYSTAL).to_i.should eq(2)
      alias Foo = Int32 | String

      {{ Foo.union_types.size }}
      CRYSTAL
  end

  it "gets default value of instance variable" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        @x = 1

        def default
          {{@type.instance_vars.first.default_value}}
        end
      end

      Foo.new.default
      CRYSTAL
  end

  it "gets default value of instance variable of generic type" do
    run(<<-CRYSTAL).to_i.should eq(10)
      require "prelude"

      struct Int32
        def self.foo
          10
        end
      end

      class Foo(T)
        @x : T = T.foo

        def default
          {{@type.instance_vars.first.default_value}}
        end
      end

      Foo(Int32).new.default
      CRYSTAL
  end

  it "gets default value of instance variable of inherited type that also includes module" do
    run(<<-CRYSTAL).to_i.should eq(10)
      module Moo
        @moo = 10
      end

      class Foo
        include Moo

        def foo
          {{ @type.instance_vars.first.default_value }}
        end
      end

      class Bar < Foo
      end

      Bar.new.foo
      CRYSTAL
  end

  it "determines if variable has default value" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        @x = 1
        @y : Int32

        def initialize(@y)
        end

        def defaults
          {
            {{ @type.instance_vars.find { |i| i.name == "x" }.has_default_value? }},
            {{ @type.instance_vars.find { |i| i.name == "y" }.has_default_value? }},
          }
        end
      end

      x, y = Foo.new(2).defaults
      a = 0
      a &+= 1 if x
      a &+= 2 if y
      a
      CRYSTAL
  end

  it "expands macro with op assign inside assign (#5568)" do
    run(<<-CRYSTAL).to_string.chomp.should eq("2")
      require "prelude"

      macro expand
        {{ yield }}
      end

      def foo
        {:foo => 1}
      end

      expand do
        x = foo[:foo] += 1
        puts x
      end
      CRYSTAL
  end

  it "devirtualizes @type" do
    run(<<-CRYSTAL).to_string.should eq("Foo")
      class Foo
        def foo
          {{@type.id.stringify}}
        end
      end

      class Bar < Foo
      end

      (Foo.new || Bar.new).foo
      CRYSTAL
  end

  it "keeps heredoc contents inside macro" do
    run(<<-CRYSTAL).to_string.should eq("  %foo")
      macro foo
        <<-FOO
          %foo
        FOO
      end

      foo
      CRYSTAL
  end

  it "keeps heredoc contents with interpolation inside macro" do
    run(<<-CRYSTAL).to_string.should eq("  42")
      require "prelude"

      macro foo
        %foo = 42
        <<-FOO
          \#{ %foo }
        FOO
      end

      foo
      CRYSTAL
  end

  it "access to the program with @top_level" do
    run(<<-CRYSTAL).to_string.should eq("main")
      class Foo
        def bar
          {{@top_level.name.stringify}}
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "responds correctly to has_constant? with @top_level" do
    run(<<-CRYSTAL).to_b.should be_true
      FOO = 1
      class Foo
        def bar
          {{@top_level.has_constant?("FOO")}}
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "does block unpacking inside macro expression (#13707)" do
    run(<<-CRYSTAL).to_i.should eq(10)
      {% begin %}
        {%
          data = [{1, 2}, {3, 4}]
          value = 0
          data.each do |(k, v)|
            value += k
            value += v
          end
        %}
        {{ value }}
      {% end %}
      CRYSTAL
  end

  it "accepts compile-time flags" do
    run("{{ flag?(:foo) ? 1 : 0 }}", flags: %w(foo)).to_i.should eq(1)
    run("{{ flag?(:foo) ? 1 : 0 }}", Int32, flags: %w(foo)).should eq(1)
  end

  it "expands record macro with comments during wants_doc=true (#16074)" do
    semantic(<<-CRYSTAL, wants_doc: true)
    require "macros"
    require "object/properties"

    record TestRecord,
      # This is a comment
      test : String?

    TestRecord.new("test").test
    CRYSTAL
  end
end
