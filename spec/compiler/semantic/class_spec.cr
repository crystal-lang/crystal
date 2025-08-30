require "../../spec_helper"

describe "Semantic: class" do
  it "types Const#allocate" do
    assert_type("class Foo; end; Foo.allocate") { types["Foo"].as(NonGenericClassType) }
  end

  it "types Const#new" do
    assert_type("class Foo; end; Foo.new") { types["Foo"].as(NonGenericClassType) }
  end

  it "types Const#new#method" do
    assert_type("class Foo; def coco; 1; end; end; Foo.new.coco") { int32 }
  end

  it "types class inside class" do
    assert_type("class Foo; class Bar; end; end; Foo::Bar.allocate") { types["Foo"].types["Bar"] }
  end

  it "types instance variable" do
    result = assert_type(<<-CRYSTAL) { generic_class "Foo", int32 }
      class Foo(T)
        def set
          @coco = 2
        end
      end

      f = Foo(Int32).new
      f.set
      f
      CRYSTAL
    mod = result.program
    type = result.node.type.as(GenericClassInstanceType)
    type.instance_vars["@coco"].type.should eq(mod.nilable(mod.int32))
  end

  it "types generic of generic type" do
    assert_type(<<-CRYSTAL
      class Foo(T)
        def set
          @coco = 2
        end
      end

      f = Foo(Foo(Int32)).new
      f.set
      f
      CRYSTAL
    ) do
      foo = types["Foo"].as(GenericClassType)
      foo_i32 = foo.instantiate([int32] of TypeVar)
      _foo_foo_i32 = foo.instantiate([foo_i32] of TypeVar)
    end
  end

  it "types instance variable" do
    input = parse <<-CRYSTAL
      class Foo(T)
        def set(value : T)
          @coco = value
        end
      end

      f = Foo(Int32).new
      f.set 2

      g = Foo(Float64).new
      g.set 2.5
      g
      CRYSTAL
    result = semantic input
    mod, node = result.program, result.node.as(Expressions)
    foo = mod.types["Foo"].as(GenericClassType)

    node[1].type.should eq(foo.instantiate([mod.int32] of TypeVar))
    node[1].type.instance_vars["@coco"].type.should eq(mod.nilable(mod.int32))

    node[3].type.should eq(foo.instantiate([mod.float64] of TypeVar))
    node[3].type.instance_vars["@coco"].type.should eq(mod.nilable(mod.float64))
  end

  it "types instance variable on getter" do
    input = parse(<<-CRYSTAL).as(Expressions)
      class Foo(T)
        def set(value : T)
          @coco = value
        end

        def get
          @coco
        end
      end

      f = Foo(Int32).new
      f.set 2
      f.get

      g = Foo(Float64).new
      g.set 2.5
      g.get
      CRYSTAL
    result = semantic input
    mod, node = result.program, result.node.as(Expressions)

    node[3].type.should eq(mod.nilable(mod.int32))
    input.last.type.should eq(mod.nilable(mod.float64))
  end

  it "types recursive type" do
    input = parse(<<-CRYSTAL).as(Expressions)
      class Node
        def add
          if next_node = @next
            next_node.add
          else
            @next = Node.new
          end
        end
      end

      n = Node.new
      n.add
      n
      CRYSTAL
    result = semantic input
    mod, input = result.program, result.node.as(Expressions)
    node = mod.types["Node"].as(NonGenericClassType)

    node.lookup_instance_var("@next").type.should eq(mod.nilable(node))
    input.last.type.should eq(node)
  end

  it "types self inside method call without obj" do
    assert_type(<<-CRYSTAL) { types["Foo"] }
      class Foo
        def foo
          bar
        end

        def bar
          self
        end
      end

      Foo.new.foo
      CRYSTAL
  end

  it "types type var union" do
    assert_type(<<-CRYSTAL) { generic_class "Foo", union_of(int32, float64) }
      class Foo(T)
      end

      Foo(Int32 | Float64).new
      CRYSTAL
  end

  it "types class and subclass as one type" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type }
      class Foo
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      CRYSTAL
  end

  it "types class and subclass as one type" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type }
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Bar.new || Baz.new
      CRYSTAL
  end

  it "types class and subclass as one type" do
    assert_type(<<-CRYSTAL) { types["Foo"].virtual_type }
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Foo.new || Bar.new || Baz.new
      CRYSTAL
  end

  it "does automatic inference of new for generic types" do
    result = assert_type(<<-CRYSTAL) { generic_class "Box", int32 }
      class Box(T)
        def initialize(value : T)
          @value = value
        end
      end

      b = Box.new(10)
      CRYSTAL
    mod = result.program
    type = result.node.type.as(GenericClassInstanceType)
    type.type_vars["T"].type.should eq(mod.int32)
    type.instance_vars["@value"].type.should eq(mod.int32)
  end

  it "does automatic type inference of new for generic types 2" do
    result = assert_type(<<-CRYSTAL) { generic_class "Box", bool }
      class Box(T)
        def initialize(x, value : T)
          @value = value
        end
      end

      b1 = Box.new(1, 10)
      b2 = Box.new(1, false)
      CRYSTAL
    mod = result.program
    type = result.node.type.as(GenericClassInstanceType)
    type.type_vars["T"].type.should eq(mod.bool)
    type.instance_vars["@value"].type.should eq(mod.bool)
  end

  it "does automatic type inference of new for nested generic type" do
    nodes = parse(<<-CRYSTAL).as(Expressions)
      class Foo
        class Bar(T)
          def initialize(x : T)
            @x = x
          end
        end
      end

      Foo::Bar.new(1)
      CRYSTAL
    result = semantic nodes
    mod = result.program
    type = nodes.last.type.as(GenericClassInstanceType)
    type.type_vars["T"].type.should eq(mod.int32)
    type.instance_vars["@x"].type.should eq(mod.int32)
  end

  it "reports uninitialized constant" do
    assert_error "Foo.new",
      "undefined constant Foo"
  end

  it "reports undefined method when method inside a class" do
    assert_error "struct Int; def foo; 1; end; end; foo",
      "undefined local variable or method 'foo'"
  end

  it "reports undefined instance method" do
    assert_error "1.foo",
      "undefined method 'foo' for Int"
  end

  it "reports unknown class when extending" do
    assert_error "class Foo < Bar; end",
      "undefined constant Bar"
  end

  it "reports superclass mismatch" do
    assert_error "class Foo; end; class Bar; end; class Foo < Bar; end",
      "superclass mismatch for class Foo (Bar for Reference)"
  end

  it "reports wrong number of arguments for initialize" do
    assert_error <<-CRYSTAL, "wrong number of arguments"
      class Foo
        def initialize(x, y)
        end
      end

      f = Foo.new
      CRYSTAL
  end

  it "reports can't instantiate abstract class on new" do
    assert_error <<-CRYSTAL, "can't instantiate abstract class Foo"
      abstract class Foo; end
      Foo.new
      CRYSTAL
  end

  it "reports can't instantiate abstract class on allocate" do
    assert_error <<-CRYSTAL, "can't instantiate abstract class Foo"
      abstract class Foo; end
      Foo.allocate
      CRYSTAL
  end

  it "doesn't lookup new in supermetaclass" do
    assert_type(<<-CRYSTAL) { generic_class "Foo", int32 }
      class Foo(T)
      end

      Reference.new
      Foo(Int32).new
      CRYSTAL
  end

  it "errors when wrong arguments for new" do
    assert_error "Reference.new 1",
      "wrong number of arguments"
  end

  it "types virtual method of generic class" do
    assert_type(<<-CRYSTAL) { int32 }
      class Object
        def foo
          bar
        end

        def bar
          'a'
        end
      end

      class Foo(T)
        def bar
          1
        end
      end

      Foo(Int32).new.foo
      CRYSTAL
  end

  it "allows defining classes inside modules or classes with ::" do
    input = parse(<<-CRYSTAL)
      class Foo
      end

      class Foo::Bar
      end
      CRYSTAL
    result = semantic input
    mod = result.program
    mod.types["Foo"].types["Bar"].as(NonGenericClassType)
  end

  it "doesn't lookup type in parents' namespaces, and lookups and in program" do
    code = "
      class Bar
      end

      module Mod
        class Bar
        end

        class Foo
          def self.foo(x : Bar)
            1
          end

          def self.foo(x : ::Bar)
            'a'
          end
        end
      end
      "

    assert_type(<<-CRYSTAL) { int32 }
      #{code}
      Mod::Foo.foo(Mod::Bar.new)
      CRYSTAL

    assert_type(<<-CRYSTAL) { char }
      #{code}
      Mod::Foo.foo(Bar.new)
      CRYSTAL
  end

  it "type def does not reopen type from parent namespace (#11181)" do
    assert_type <<-CRYSTAL, inject_primitives: false { types["Baz"].types["Foo"].types["Bar"].metaclass }
      class Foo::Bar
      end

      module Baz
        class Foo::Bar
        end
      end

      Baz::Foo::Bar
      CRYSTAL
  end

  it "finds in global scope if includes module" do
    assert_type(<<-CRYSTAL) { int32 }
      class Baz
      end

      module Foo
        class Bar
          include Foo

          Baz
        end
      end

      1
      CRYSTAL
  end

  it "allows instantiating generic class with number" do
    assert_type(<<-CRYSTAL) { generic_class "Foo", 1.int32 }
      class Foo(T)
      end

      Foo(1).new
      CRYSTAL
  end

  it "uses number type var in class method" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo(T)
        def self.foo
          T
        end
      end

      Foo(1).foo
      CRYSTAL
  end

  it "uses self as type var" do
    assert_type(<<-CRYSTAL) { generic_class "Foo", types["Bar"] }
      class Foo(T)
      end

      class Bar
        def self.coco
          Foo(self)
        end
      end

      Bar.coco.new
      CRYSTAL
  end

  it "uses self as type var" do
    assert_type(<<-CRYSTAL) { generic_class "Foo", types["Baz"] }
      class Foo(T)
      end

      class Bar
        def self.coco
          Foo(self)
        end
      end

      class Baz < Bar
      end

      Baz.coco.new
      CRYSTAL
  end

  it "infers generic type after instance was created with explicit type" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo(T)
        def initialize(@x : T)
        end

        def x
          @x
        end
      end

      foo1 = Foo(Bool).new(true)
      foo2 = Foo.new(1)
      foo2.x
      CRYSTAL
  end

  it "errors when creating Value" do
    assert_error "Value.allocate", "can't instantiate abstract struct Value"
  end

  it "errors when creating Number" do
    assert_error "Number.allocate", "can't instantiate abstract struct Number"
  end

  it "reads an object instance var" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def initialize(@x : Int32)
        end
      end

      foo = Foo.new(1)
      foo.@x
      CRYSTAL
  end

  it "reads a virtual type instance var" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def initialize(@x : Int32)
        end
      end

      class Bar < Foo
      end

      foo = Foo.new(1) || Bar.new(2)
      foo.@x
      CRYSTAL
  end

  it "errors if reading non-existent ivar" do
    assert_error <<-CRYSTAL, "can't infer the type of instance variable '@y' of Foo"
      class Foo
      end

      foo = Foo.new
      foo.@y
      CRYSTAL
  end

  it "errors if reading ivar from non-ivar container" do
    assert_error <<-CRYSTAL, "can't use instance variables inside primitive types (at Int32)"
      1.@y
      CRYSTAL
  end

  it "reads an object instance var from a union type" do
    assert_type(<<-CRYSTAL) { union_of(int32, char) }
      class Foo
        def initialize(@x : Int32)
        end
      end

      class Bar
        def initialize(@y : Int32, @x : Char)
        end
      end

      foo = Foo.new(1)
      bar = Bar.new(2, 'a')
      union = foo || bar
      union.@x
      CRYSTAL
  end

  it "says that instance vars are not allowed in metaclass" do
    assert_error <<-CRYSTAL, "@instance_vars are not yet allowed in metaclasses: use @@class_vars instead"
      module Foo
        def self.foo
          @foo
        end
      end

      Foo.foo
      CRYSTAL
  end

  it "doesn't use initialize from base class" do
    assert_error <<-CRYSTAL, "wrong number of arguments for 'Bar.new' (given 1, expected 2)"
      class Foo
        def initialize(x)
        end
      end

      class Bar < Foo
        def initialize(x, y)
        end
      end

      Bar.new(1)
      CRYSTAL
  end

  it "doesn't use initialize from base class with virtual type" do
    assert_error <<-CRYSTAL, "wrong number of arguments for 'Bar#initialize' (given 1, expected 2)", inject_primitives: true
      class Foo
        def initialize(x)
        end
      end

      class Bar < Foo
        def initialize(x, y)
        end
      end

      klass = 1 == 1 ? Foo : Bar
      klass.new(1)
      CRYSTAL
  end

  it "errors if using underscore in generic class" do
    assert_error <<-CRYSTAL, "can't use underscore as generic type argument"
      class Foo(T)
      end

      Foo(_).new
      CRYSTAL
  end

  it "types bug #168 (it inherits instance var even if not mentioned in initialize)" do
    assert_error <<-CRYSTAL, "can't infer the type of instance variable '@x' of Foo"
      class Foo
        def foo
          x = @x
          if x
            x.foo
          else
            1
          end
        end
      end

      class Bar < Foo
        def initialize(@x : Foo)
        end
      end

      Bar.new(Foo.new).foo
      CRYSTAL
  end

  it "doesn't mark instance variable as nilable if calling another initialize" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def initialize(x, y)
          initialize(x)
        end

        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      foo = Foo.new(1, 2)
      foo.x
      CRYSTAL
  end

  it "says wrong number of arguments for abstract class new" do
    assert_error <<-CRYSTAL, "wrong number of arguments for 'Foo.new' (given 1, expected 0)"
      abstract class Foo
      end

      Foo.new(1)
      CRYSTAL
  end

  it "says wrong number of arguments for abstract class new (2)" do
    assert_error <<-CRYSTAL, "wrong number of arguments for 'Foo.new' (given 0, expected 1)"
      abstract class Foo
        def initialize(x)
        end
      end

      Foo.new
      CRYSTAL
  end

  it "can't reopen as struct" do
    assert_error <<-CRYSTAL, "Foo is not a struct, it's a class"
      class Foo
      end

      struct Foo
      end
      CRYSTAL
  end

  it "can't reopen as module" do
    assert_error <<-CRYSTAL, "Foo is not a module, it's a class"
      class Foo
      end

      module Foo
      end
      CRYSTAL
  end

  it "errors if reopening non-generic class as generic" do
    assert_error <<-CRYSTAL, "Foo is not a generic class"
      class Foo
      end

      class Foo(T)
      end
      CRYSTAL
  end

  it "errors if reopening generic class with different type vars" do
    assert_error <<-CRYSTAL, "type var must be T, not U"
      class Foo(T)
      end

      class Foo(U)
      end
      CRYSTAL
  end

  it "errors if reopening generic class with different type vars (2)" do
    assert_error <<-CRYSTAL, "type vars must be A, B, not C"
      class Foo(A, B)
      end

      class Foo(C)
      end
      CRYSTAL
  end

  it "errors if reopening generic class with different splat index" do
    assert_error <<-CRYSTAL, "type var must be A, not *A"
      class Foo(A)
      end

      class Foo(*A)
      end
      CRYSTAL
  end

  it "errors if reopening generic class with different splat index (2)" do
    assert_error <<-CRYSTAL, "type var must be *A, not A"
      class Foo(*A)
      end

      class Foo(A)
      end
      CRYSTAL
  end

  it "errors if reopening generic class with different splat index (3)" do
    assert_error <<-CRYSTAL, "type vars must be *A, B, not A, *B"
      class Foo(*A, B)
      end

      class Foo(A, *B)
      end
      CRYSTAL
  end

  it "allows declaring a variable in an initialize and using it" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      class Foo
        def initialize
          @x = uninitialized Int32
          @x + 1
        end

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "allows using self in class scope" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def self.foo
          1
        end

        @@x = self.foo.as(Int32)

        def self.x
          @@x
        end
      end

      Foo.x
      CRYSTAL
  end

  it "can't use implicit initialize if defined in parent" do
    assert_error <<-CRYSTAL, "wrong number of arguments for 'Bar.new' (given 0, expected 1)"
      class Foo
        def initialize(x)
        end
      end

      class Bar < Foo
      end

      Bar.new
      CRYSTAL
  end

  it "doesn't error on new on abstract virtual type class" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      abstract class Foo
      end

      class Bar < Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      ptr = Pointer(Foo.class).malloc(1_u64)
      ptr.value = Bar
      bar = ptr.value.new(1)
      bar.x
      CRYSTAL
  end

  it "says no overload matches for class new" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'Foo.new' to be Int32, not Char"
      class Foo
        def self.new(x : Int32)
        end
      end

      Foo.new 'a'
      CRYSTAL
  end

  it "correctly types #680" do
    assert_type(<<-CRYSTAL) { nilable int32 }
      class Foo
        def initialize(@method : Int32?)
        end

        def method
          @method
        end
      end

      class Bar < Foo
        def initialize
          super(method)
        end
      end

      Bar.new.method
      CRYSTAL
  end

  it "correctly types #680 (2)" do
    assert_error <<-CRYSTAL, "instance variable '@method' of Foo must be Int32, not Nil"
      class Foo
        def initialize(@method : Int32)
        end

        def method
          @method
        end
      end

      class Bar < Foo
        def initialize
          super(method)
        end
      end

      Bar.new.method
      CRYSTAL
  end

  it "can invoke method on abstract type without subclasses nor instances" do
    assert_type(<<-CRYSTAL) { int32 }
      require "prelude"

      abstract class Foo
      end

      a = [] of Foo
      a.each &.foo
      1
      CRYSTAL
  end

  it "can invoke method on abstract generic type without subclasses nor instances" do
    assert_type(<<-CRYSTAL) { int32 }
      require "prelude"

      abstract class Foo(T)
      end

      a = [] of Foo(Int32)
      a.each &.foo
      1
      CRYSTAL
  end

  it "can invoke method on abstract generic type with subclasses but no instances" do
    assert_type(<<-CRYSTAL) { int32 }
      require "prelude"

      abstract class Foo(T)
      end

      class Bar(T) < Foo(T)
        def foo
        end
      end

      a = [] of Foo(Int32)
      a.each &.foo
      1
      CRYSTAL
  end

  it "doesn't crash on instance variable assigned a proc, and never instantiated (#923)" do
    assert_type(<<-CRYSTAL) { nil_type }
      class Klass
        def self.f(arg)
        end

        @a  : Proc(String, Nil) = ->f(String)
      end
      CRYSTAL
  end

  it "errors if declares class inside if" do
    assert_error <<-CRYSTAL, "can't declare class dynamically"
      if 1 == 2
        class Foo; end
      end
      CRYSTAL
  end

  it "can mark initialize as private" do
    assert_error <<-CRYSTAL, "private method 'new' called for Foo"
      class Foo
        private def initialize
        end
      end

      Foo.new
      CRYSTAL
  end

  it "errors if creating instance before typing instance variable" do
    assert_error <<-CRYSTAL, "instance variable '@x' of Foo must be Int32"
      class Foo
        Foo.new

        @x : Int32

        def initialize
          @x = false
        end
      end
      CRYSTAL
  end

  it "errors if assigning superclass to declared instance var" do
    assert_error <<-CRYSTAL, "instance variable '@bar' of Main must be Bar"
      class Foo
      end

      class Bar < Foo
      end

      class Main
        @bar : Bar

        def initialize
          @bar = Foo.new
        end
      end

      Main.new
      CRYSTAL
  end

  it "hoists instance variable initializer" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      a = Foo.new.bar + 1

      class Foo
        @bar = 1

        def bar
          @bar
        end
      end

      a
      CRYSTAL
  end

  it "doesn't mix classes on definition (#2352)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Baz
      end

      class Moo::Baz::B
        def self.foo
          1
        end
      end

      Moo::Baz::B.foo
      CRYSTAL
  end

  it "errors if using read-instance-var with non-typed variable" do
    assert_error <<-CRYSTAL, "can't infer the type of instance variable '@foo' of Foo"
      class Foo
        def foo
          @foo
        end
      end

      f = Foo.new
      f.@foo
      CRYSTAL
  end

  it "doesn't crash with top-level initialize (#2601)" do
    assert_type(<<-CRYSTAL) { int32 }
      def initialize
        1
      end

      initialize
      CRYSTAL
  end

  it "inherits self (#2890)" do
    assert_type(<<-CRYSTAL) { types["Foo"].metaclass }
      class Foo
        class Bar < self
        end
      end

      {{Foo::Bar.superclass}}
      CRYSTAL
  end

  it "inherits Gen(self) (#2890)" do
    assert_type(<<-CRYSTAL) { types["Foo"].metaclass }
      class Gen(T)
        def self.t
          T
        end
      end

      class Foo
        class Bar < Gen(self)
        end
      end

      Foo::Bar.t
      CRYSTAL
  end

  it "errors if inheriting Gen(self) and there's no self (#2890)" do
    assert_error <<-CRYSTAL, "there's no self in this scope"
      class Gen(T)
        def self.t
          T
        end
      end

      class Bar < Gen(self)
      end

      Bar.t
      CRYSTAL
  end

  it "preserves order of instance vars (#3050)" do
    result = semantic(<<-CRYSTAL)
      class Foo
        @x = uninitialized Int32
        @y : Int32

        def initialize(@y)
        end
      end
      CRYSTAL
    instance_vars = result.program.types["Foo"].instance_vars.to_a.map(&.[0])
    instance_vars.should eq(%w(@x @y))
  end

  it "errors if inherits from module" do
    assert_error <<-CRYSTAL, "Moo is not a class, it's a module"
      module Moo
      end

      class Foo < Moo
      end
      CRYSTAL
  end

  it "errors if inherits from metaclass" do
    assert_error <<-CRYSTAL, "Foo.class is not a class, it's a metaclass"
      class Foo
      end

      alias FooClass = Foo.class

      class Bar < FooClass
      end
      CRYSTAL
  end

  it "can use short name for top-level type" do
    assert_type(<<-CRYSTAL) { types["T"] }
      class T
      end

      T.new
      CRYSTAL
  end

  it "errors on no method found on abstract class, class method (#2241)" do
    assert_error <<-CRYSTAL, "undefined method 'bar' for Foo.class"
      abstract class Foo
      end

      Foo.bar
      CRYSTAL
  end

  it "inherits self twice (#5495)" do
    assert_type(<<-CRYSTAL) { tuple_of [types["Foo"].metaclass, types["Foo"].metaclass] }
      class Foo
        class Bar < self
        end

        class Baz < self
        end
      end

      { {{ Foo::Bar.superclass }}, {{ Foo::Baz.superclass }} }
      CRYSTAL
  end

  it "types as no return if calling method on abstract class with all abstract subclasses (#6996)" do
    assert_type(<<-CRYSTAL) { no_return }
      require "prelude"

      abstract class Foo
        abstract def foo?
      end

      abstract class Bar < Foo
      end

      Pointer(Foo).malloc(1_u64).value.foo?
      CRYSTAL
  end

  it "types as no return if calling method on abstract class with generic subclasses but no instances (#6996)" do
    assert_type(<<-CRYSTAL) { no_return }
      require "prelude"

      abstract class Foo
        abstract def foo?
      end

      class Bar(T) < Foo
        def foo?
          true
        end
      end

      Pointer(Foo).malloc(1_u64).value.foo?
      CRYSTAL
  end

  it "types as no return if calling method on abstract generic class (#6996)" do
    assert_type(<<-CRYSTAL) { no_return }
      require "prelude"

      abstract class Foo(T)
        abstract def foo?
      end

      Pointer(Foo(Int32)).malloc(1_u64).value.foo?
      CRYSTAL
  end

  it "types as no return if calling method on generic class with subclasses (#6996)" do
    assert_type(<<-CRYSTAL) { no_return }
      require "prelude"

      abstract class Foo(T)
        abstract def foo?
      end

      abstract class Bar(T) < Foo(T)
      end

      Bar(Int32)

      Pointer(Foo(Int32)).malloc(1_u64).value.foo?
      CRYSTAL
  end
end
