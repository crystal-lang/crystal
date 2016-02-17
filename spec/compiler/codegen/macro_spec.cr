require "../../spec_helper"

describe "Code gen: macro" do
  it "expands macro" do
    run("macro foo; 1 + 2; end; foo").to_i.should eq(3)
  end

  it "expands macro with arguments" do
    run(%(
      macro foo(n)
        {{n}} + 2
      end

      foo(1)
      )).to_i.should eq(3)
  end

  it "expands macro that invokes another macro" do
    run(%(
      macro foo
        def x
          1 + 2
        end
      end

      macro bar
        foo
      end

      bar
      x
      )).to_i.should eq(3)
  end

  it "expands macro defined in class" do
    run(%(
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
    )).to_i.should eq(1)
  end

  it "expands macro defined in base class" do
    run(%(
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
    )).to_i.should eq(1)
  end

  it "expands inline macro" do
    run(%(
      a = {{ 1 }}
      a
      )).to_i.should eq(1)
  end

  it "expands inline macro for" do
    run(%(
      a = 0
      {% for i in [1, 2, 3] %}
        a += {{i}}
      {% end %}
      a
      )).to_i.should eq(6)
  end

  it "expands inline macro if (true)" do
    run(%(
      a = 0
      {% if 1 == 1 %}
        a += 1
      {% end %}
      a
      )).to_i.should eq(1)
  end

  it "expands inline macro if (false)" do
    run(%(
      a = 0
      {% if 1 == 2 %}
        a += 1
      {% end %}
      a
      )).to_i.should eq(0)
  end

  it "finds macro in class" do
    run(%(
      class Foo
        macro foo
          1 + 2
        end

        def bar
          foo
        end
      end

      Foo.new.bar
      )).to_i.should eq(3)
  end

  it "expands def macro" do
    run(%(
      def bar_baz
        1
      end

      macro def foo : Int32
        bar_{{ "baz".id }}
      end

      foo
      )).to_i.should eq(1)
  end

  it "expands def macro with var" do
    run(%(
      macro def foo : Int32
        a = {{ 1 }}
      end

      foo
      )).to_i.should eq(1)
  end

  it "expands def macro with @type.instance_vars" do
    run(%(
      class Foo
        def initialize(@x)
        end

        macro def to_s : String
          {{ @type.instance_vars.first.stringify }}
        end
      end

      foo = Foo.new(1)
      foo.to_s
      )).to_string.should eq("x")
  end

  it "expands def macro with @type.instance_vars with subclass" do
    run(%(
      class Reference
        macro def to_s : String
          {{ @type.instance_vars.last.stringify }}
        end
      end

      class Foo
        def initialize(@x)
        end
      end

      class Bar < Foo
        def initialize(@x, @y)
        end
      end

      Bar.new(1, 2).to_s
      )).to_string.should eq("y")
  end

  it "expands def macro with @type.instance_vars with virtual" do
    run(%(
      class Reference
        macro def to_s : String
          {{ @type.instance_vars.last.stringify }}
        end
      end

      class Foo
        def initialize(@x)
        end
      end

      class Bar < Foo
        def initialize(@x, @y)
        end
      end

      (Bar.new(1, 2) || Foo.new(1)).to_s
      )).to_string.should eq("y")
  end

  it "expands def macro with @type.name" do
    run(%(
      class Foo
        def initialize(@x)
        end

        macro def to_s : String
          {{@type.name.stringify}}
        end
      end

      foo = Foo.new(1)
      foo.to_s
      )).to_string.should eq("Foo")
  end

  it "expands macro and resolves type correctly" do
    run(%(
      class Foo
        macro def foo : Int32
          1
        end
      end

      class Bar < Foo
        Int32 = 2
      end

      Bar.new.foo
      )).to_i.should eq(1)
  end

  it "expands def macro with @type.name with virtual" do
    run(%(
      class Reference
        macro def to_s : String
          {{ @type.name.stringify }}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      (Bar.new || Foo.new).to_s
      )).to_string.should eq("Bar")
  end

  it "expands def macro with @type.name with virtual (2)" do
    run(%(
      class Reference
        macro def to_s : String
          {{ @type.name.stringify }}
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      (Foo.new || Bar.new).to_s
      )).to_string.should eq("Foo")
  end

  it "allows overriding macro definition when redefining base class" do
    run(%(
      class Foo
        macro def inspect : String
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
      )).to_string.should eq("OH NO")
  end

  it "uses invocation context" do
    run(%(
      macro foo
        def bar
          {{@type.name.stringify}}
        end
      end

      class Foo
        foo
      end

      Foo.new.bar
      )).to_string.should eq("Foo")
  end

  it "allows macro with default arguments" do
    run(%(
      def bar
        2
      end

      macro foo(x, y = :bar)
        {{x}} + {{y.id}}
      end

      foo(1)
      )).to_i.should eq(3)
  end

  it "expands def macro with instance var and method call (bug)" do
    run(%(
      struct Nil
        def to_i
          0
        end
      end

      class Foo
        macro def foo : Int32
          name = 1
          @name = name
        end
      end

      Foo.new.foo.to_i
      )).to_i.should eq(1)
  end

  it "expands @type.name in virtual metaclass (1)" do
    run(%(
      class Class
        macro def to_s : String
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
      )).to_string.should eq("Foo")
  end

  it "expands @type.name in virtual metaclass (2)" do
    run(%(
      class Class
        macro def to_s : String
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
      )).to_string.should eq("Bar")
  end

  it "doesn't skip abstract classes when defining macro methods" do
    run(%(
      class Object
        macro def foo : Int32
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
      )).to_i.should eq(2)
  end

  it "doesn't reuse macro nodes (bug)" do
    run(%(
      def foo(x)
        {% for y in [1, 2] %}
          x + 1
        {% end %}
      end

      foo 1
      foo(1.5).to_i
      )).to_i.should eq(2)
  end

  it "can use constants" do
    run(%(
      A = 1
      {{ A }}
      )).to_i.should eq(1)
  end

  it "can refer to types" do
    run(%(
      class Foo
        def initialize(@x, @y)
        end

        macro def foo : String
          {{ Foo.instance_vars.last.name.stringify }}
        end

      end

      Foo.new(1, 2).foo
      )).to_string.should eq("y")
  end

  it "runs macro with splat" do
    run(%(
      macro foo(*args)
        {{args.size}}
      end

      foo 1, 1, 1
      )).to_i.should eq(3)
  end

  it "runs macro with arg and splat" do
    run(%(
      macro foo(name, *args)
        {{args.size}}
      end

      foo bar, 1, 1, 1
      )).to_i.should eq(3)
  end

  it "runs macro with arg and splat in first position (1)" do
    run(%(
      macro foo(*args, name)
        {{args.size}}
      end

      foo 1, 1, 1, bar
      )).to_i.should eq(3)
  end

  it "runs macro with arg and splat in first position (2)" do
    run(%(
      macro foo(*args, name)
        {{name}}
      end

      foo 1, 1, 1, "hello"
      )).to_string.should eq("hello")
  end

  it "runs macro with arg and splat in the middle (1)" do
    run(%(
      macro foo(foo, *args, name)
        {{args.size}}
      end

      foo x, 1, 1, 1, bar
      )).to_i.should eq(3)
  end

  it "runs macro with arg and splat in the middle (2)" do
    run(%(
      macro foo(foo, *args, name)
        {{foo}}
      end

      foo "yellow", 1, 1, 1, bar
      )).to_string.should eq("yellow")
  end

  it "runs macro with arg and splat in the middle (3)" do
    run(%(
      macro foo(foo, *args, name)
        {{name}}
      end

      foo "yellow", 1, 1, 1, "cool"
      )).to_string.should eq("cool")
  end

  it "expands macro that yields" do
    run(%(
      def foo
        {% for i in 0 .. 2 %}
          yield {{i}}
        {% end %}
      end

      a = 0
      foo do |x|
        a += x
      end
      a
      )).to_i.should eq(3)
  end

  it "can refer to abstract (1)" do
    run(%(
      class Foo
      end

      {{ Foo.abstract? }}
      )).to_b.should be_false
  end

  it "can refer to abstract (2)" do
    run(%(
      abstract class Foo
      end

      {{ Foo.abstract? }}
      )).to_b.should be_true
  end

  it "can refer to @type" do
    run(%(
      class Foo
        macro def foo : String
          {{@type.name.stringify}}
        end
      end

      Foo.new.foo
      )).to_string.should eq("Foo")
  end

  it "can refer to union (1)" do
    run(%(
      {{Int32.union?}}
    )).to_b.should be_false
  end

  it "can refer to union (2)" do
    run(%(
      class Foo
        def initialize
          @x = 1; @x = 1.1
        end
        def foo
          {{ @type.instance_vars.first.type.union? }}
        end
      end
      Foo.new.foo
    )).to_b.should be_true
  end

  it "can iterate union types" do
    run(%(
      require "prelude"
      class Foo
        def initialize
          @x = 1; @x = 1.1
        end
        def foo
          {{ @type.instance_vars.first.type.union_types.map(&.name).sort }}.join("-")
        end
      end
      Foo.new.foo
    )).to_string.should eq("Float64-Int32")
  end

  it "can access type variables" do
    run(%(
      class Foo(T)
        def foo
          {{ @type.type_vars.first.name.stringify }}
        end
      end
      Foo(Int32).new.foo
    )).to_string.should eq("Int32")
  end

  it "can acccess type variables that are not types" do
    run(%(
      class Foo(T)
        def foo
          {{ @type.type_vars.first.is_a?(NumberLiteral) }}
        end
      end
      Foo(1).new.foo
    )).to_b.should eq(true)
  end

  it "can acccess type variables of a tuple" do
    run(%(
      struct Tuple
        def foo
          {{ @type.type_vars.first.name.stringify }}
        end
      end
      {1, 2, 3}.foo
    )).to_string.should eq("Int32")
  end

  it "can access type variables of a generic type" do
    run(%(
      require "prelude"
      class Foo(T, K)
        macro def self.foo : String
          {{ @type.type_vars.map(&.stringify) }}.join("-")
        end
      end
      Foo.foo
    )).to_string.should eq("T-K")
  end

  it "receives &block" do
    run(%(
      macro foo(&block)
        bar {{block}}
      end

      def bar
        yield 1
      end

      foo do |x|
        x + 1
      end
      )).to_i.should eq(2)
  end

  it "executes with named arguments" do
    run(%(
      macro foo(x = 1)
        {{x}} + 1
      end

      foo x: 2
      )).to_i.should eq(3)
  end

  it "gets correct class name when there are classes in the middle" do
    run(%(
      class Foo
        macro def class_desc : String
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
      )).to_string.should eq("Qux")
  end

  it "transforms hooks (bug)" do
    codegen(%(
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
      ))
  end

  it "executs subclasses" do
    run(%(
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      class Qux < Baz
      end

      names = {{ Foo.subclasses.map &.name }}
      names.join("-")
      )).to_string.should eq("Bar-Baz")
  end

  it "executs all_subclasses" do
    run(%(
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      class Baz < Bar
      end

      names = {{ Foo.all_subclasses.map &.name }}
      names.join("-")
      )).to_string.should eq("Bar-Baz")
  end

  it "gets enum members with @type.constants" do
    run(%(
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

      Color.red.value + Color.green.value + Color.blue.value
      )).to_i.should eq(0 + 1 + 2)
  end

  it "gets enum members as constants" do
    run(%(
      enum Color
        Red
        Green
        Blue
      end

      {{Color.constants[1].stringify}}
      )).to_string.should eq("Green")
  end

  it "says that enum has Flags attribute" do
    run(%(
      @[Flags]
      enum Color
        Red
        Green
        Blue
      end

      {{Color.has_attribute?("Flags")}}
      )).to_b.should be_true
  end

  it "says that enum doesn't have Flags attribute" do
    run(%(
      enum Color
        Red
        Green
        Blue
      end

      {{Color.has_attribute?("Flags")}}
      )).to_b.should be_false
  end

  it "gets methods" do
    run(%(
      class Foo
        def bar
          1
        end

        macro def first_method_name : String
          {{ @type.methods.map(&.name.stringify).first }}
        end
      end

      Foo.new.first_method_name
      )).to_string.should eq("bar")
  end

  it "copies base macro def to sub-subtype even after it was copied to a subtype (#448)" do
    run(%(
      class Object
        macro def class_name : String
          {{@type.name.stringify}}
        end
      end

      class A
        @@children = Pointer(A).malloc(1_u64)

        def self.children
          @@children
        end
      end

      A.children.value = A.new
      A.children.value.class_name

      class B < A; end

      A.children.value = B.new
      A.children.value.class_name

      class C < B; end
      A.children.value = C.new
      A.children.value.class_name
      )).to_string.should eq("C")
  end

  it "recalculates method when virtual metaclass type is added" do
    run(%(
      require "prelude"

      $x = [] of String

      def run
        $runnables.each &.run
      end

      class Runnable
      end

      $runnables = [] of Runnable.class

      class Runnable
        macro inherited
          $runnables << self
        end

        macro def self.run : Nil
          $x << {{@type.name.stringify}}
          nil
        end
      end

      class Test < Runnable
      end

      run
      $x.clear

      class RunnableTest < Test
      end

      run
      $x.join(", ")
      )).to_string.should eq("Test, RunnableTest")
  end

  it "correctly recomputes call (bug)" do
    run(%(
      class Object
        def in_object
          in_class(1)
        end
      end

      class Class
        def in_class(x)
          bar
        end

        macro def bar : String
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
      )).to_string.should eq("Baz")
  end

  it "doesn't override local variable when using macro variable" do
    run(%(
      macro foo(x)
        %a = {{x}}
        %a
      end

      a = 1
      foo(2)
      foo(3)
      a
      )).to_i.should eq(1)
  end

  it "doesn't override local variable when using macro variable (2)" do
    run(%(
      macro foo(x)
        %a = {{x}} + 10
        %a
      end

      a = 1
      z = foo(2)
      w = foo(3)
      a + z + w
      )).to_i.should eq(26)
  end

  it "uses indexed macro variable" do
    run(%(
      macro foo(*elems)
        {% for elem, i in elems %}
          %var{i} = {{elem}}
        {% end %}

        %total = 0
        {% for elem, i in elems %}
          %total += %var{i}
        {% end %}
        %total
      end

      z = 0
      z += foo 4, 5, 6
      z += foo 40, 50, 60
      z
      )).to_i.should eq(4 + 5 + 6 + 40 + 50 + 60)
  end

  it "uses indexed macro variable with many keys" do
    run(%(
      macro foo(*elems)
        {% for elem, i in elems %}
          %var{elem, i} = {{elem}}
        {% end %}

        %total = 0
        {% for elem, i in elems %}
          %total += %var{elem, i}
        {% end %}
        %total
      end

      z = foo 4, 5, 6
      z
      )).to_i.should eq(4 + 5 + 6)
  end

  it "codegens macro def with splat (#496)" do
    run(%(
      class Foo
        macro def bar(*args) : Int32
          args[0] + args[1] + args[2]
        end
      end

      Foo.new.bar(1, 2, 3)
      )).to_i.should eq(6)
  end

  it "codegens macro def with default arg (similar to #496)" do
    run(%(
      class Foo
        macro def bar(foo = 1) : Int32
          foo + 2
        end
      end

      Foo.new.bar
      )).to_i.should eq(3)
  end

  it "expands macro with default arg and splat (#784)" do
    run(%(
      macro some_macro(a=5, *args)
        {{a.stringify}}
      end

      some_macro
      )).to_string.should eq("5")
  end

  it "expands macro with default arg and splat (2) (#784)" do
    run(%(
      macro some_macro(a=5, *args)
        {{a.stringify}}
      end

      some_macro 1, 2, 3, 4
      )).to_string.should eq("1")
  end

  it "expands macro with default arg and splat (3) (#784)" do
    run(%(
      macro some_macro(a=5, *args)
        {{args.size}}
      end

      some_macro 1, 2, 3, 4
      )).to_i.should eq(3)
  end

  it "checks if macro expansion returns (#821)" do
    run(%(
      macro pass
        return 123
      end

      def me
        pass
        nil
      end

      me
      )).to_i.should eq(123)
  end

  it "passes #826" do
    run(%(
      macro foo
        macro bar
          {{yield}}
        end
      end

      foo do
        123
      end

      bar
      )).to_i.should eq(123)
  end

  it "declares constant in macro (#838)" do
    run(%(
      macro foo
        {{yield}}
      end

      foo do
        X = 123
      end

      X
      )).to_i.should eq(123)
  end

  it "errors if dynamic constant assignment after macro expansion" do
    assert_error %(
      macro foo
        X = 123
      end

      def bar
        foo
      end

      bar
      ),
      "dynamic constant assignment"
  end

  it "finds macro from virtual type" do
    run(%(
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
      )).to_i.should eq(123)
  end

  it "expands macro with escaped quotes (#895)" do
    run(%(
      macro foo(x)
        "{{x}}\\""
      end

      foo hello
      )).to_string.should eq(%(hello"))
  end

  it "expands macro def with return (#1040)" do
    run(%(
      macro def a : Int32
        return 123
      end

      a
      )).to_i.should eq(123)
  end

  it "fixes empty types of macro expansions (#1379)" do
    run(%(
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
      )).to_i.should eq(123)
  end

  it "expands macro as class method" do
    run(%(
      class Foo
        macro bar
          1
        end
      end

      Foo.bar
      )).to_i.should eq(1)
  end

  it "expands macro as class method and accesses @type" do
    run(%(
      class Foo
        macro bar
          {{@type.stringify}}
        end
      end

      Foo.bar
      )).to_string.should eq("Foo")
  end

  it "codegens macro with comment (bug) (#1396)" do
    run(%(
      macro my_macro
        # {{ 1 }}
        {{ 1 }}
      end

      my_macro
      )).to_i.should eq(1)
  end

  it "correctly resolves constant inside block in macro def" do
    run(%(
      def foo
        yield
      end

      class Foo
        Const = 123

        macro def self.bar : Int32
          foo { Const }
        end
      end

      Foo.bar
      )).to_i.should eq(123)
  end

  it "can access free variables" do
    run(%(
      def foo(x : T)
        {{ T.stringify }}
      end

      foo(1)
      )).to_string.should eq("Int32")
  end

  it "types macro expansion bug (#1734)" do
    run(%(
      class Foo
        macro def foo : Int32
          1 || 2
        end
      end

      class Bar < Foo
      end

      x = true ? Foo.new : Bar.new
      x.foo
      )).to_i.should eq(1)
  end
end
