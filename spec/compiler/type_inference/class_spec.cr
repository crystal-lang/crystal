#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: class" do
  it "types Const#allocate" do
    result = assert_type("class Foo; end; Foo.allocate") { types["Foo"] }
    node_type = result.node.type
    assert_type node_type, NonGenericClassType
  end

  it "types Const#new" do
    result = assert_type("class Foo; end; Foo.new") { types["Foo"] }
    node_type = result.node.type
    assert_type node_type, NonGenericClassType
  end

  it "types Const#new#method" do
    assert_type("class Foo; def coco; 1; end; end; Foo.new.coco") { int32 }
  end

  it "types class inside class" do
    assert_type("class Foo; class Bar; end; end; Foo::Bar.allocate") { types["Foo"].types["Bar"] }
  end

  it "types instance variable" do
    result = assert_type("
      class Foo(T)
        def set
          @coco = 2
        end
      end

      f = Foo(Int32).new
      f.set
      f
    ") do
      foo = types["Foo"]
      assert_type foo, GenericClassType
      foo.instantiate([int32] of Type)
    end
    mod = result.program
    type = result.node.type
    assert_type type, GenericClassInstanceType

    type.instance_vars["@coco"].type.should eq(mod.union_of(mod.nil, mod.int32))
  end

  it "types instance variable" do
    input = parse "
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
    "
    result = infer_type input
    mod, node = result.program, result.node
    foo = mod.types["Foo"]
    assert_type foo, GenericClassType
    assert_type node, Expressions

    node[1].type.should eq(foo.instantiate([mod.int32] of Type))
    node1type = node[1].type
    assert_type node1type, InstanceVarContainer

    node1type.instance_vars["@coco"].type.should eq(mod.union_of(mod.nil, mod.int32))
    node[3].type.should eq(foo.instantiate([mod.float64] of Type))

    node3type = node[3].type
    assert_type node3type, InstanceVarContainer
    node3type.instance_vars["@coco"].type.should eq(mod.union_of(mod.nil, mod.float64))
  end

  it "types instance variable on getter" do
    input = parse "
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
    "
    result = infer_type input
    mod, node = result.program, result.node
    assert_type node, Expressions
    assert_type input, Expressions

    node[3].type.should eq(mod.union_of(mod.nil, mod.int32))
    input.last.type.should eq(mod.union_of(mod.nil, mod.float64))
  end

  it "types recursive type" do
    input = parse "
      class Node
        def add
          if @next
            @next.add
          else
            @next = Node.new
          end
        end
      end

      n = Node.new
      n.add
      n
    "
    result = infer_type input
    mod, input = result.program, result.node
    node = mod.types["Node"]
    assert_type node, NonGenericClassType
    assert_type input, Expressions

    node.lookup_instance_var("@next").type.should eq(mod.union_of(mod.nil, node))
    input.last.type.should eq(node)
  end

  it "types self inside method call without obj" do
    assert_type("
      class Foo
        def foo
          bar
        end

        def bar
          self
        end
      end

      Foo.new.foo
    ") { types["Foo"] }
  end

  it "types type var union" do
    assert_type("
      class Foo(T)
      end

      Foo(Int32 | Float64).new
      ") do
        foo = types["Foo"]
        assert_type foo, GenericClassType
        foo.instantiate([union_of(int32, float64)] of Type)
      end
  end

  it "types class and subclass as one type" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      ") { types["Foo"].hierarchy_type }
  end

  it "types class and subclass as one type" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Bar.new || Baz.new
      ") { types["Foo"].hierarchy_type }
  end

  it "types class and subclass as one type" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Foo.new || Bar.new || Baz.new
      ") { types["Foo"].hierarchy_type }
  end

  it "does automatic inference of new for generic types" do
    result = assert_type("
      class Box(T)
        def initialize(value : T)
          @value = value
        end
      end

      b = Box.new(10)
      ") do
        box = types["Box"]
        assert_type box, GenericClassType
        box.instantiate([int32] of Type)
      end
    mod = result.program
    type = result.node.type
    assert_type type, GenericClassInstanceType

    type.type_vars["T"].type.should eq(mod.int32)
    type.instance_vars["@value"].type.should eq(mod.int32)
  end

  it "does automatic type inference of new for generic types 2" do
    result = assert_type("
      class Box(T)
        def initialize(x, value : T)
          @value = value
        end
      end

      b1 = Box.new(1, 10)
      b2 = Box.new(1, false)
      ") do
        box = types["Box"]
        assert_type box, GenericClassType
        box.instantiate([bool])
    end
    mod = result.program
    type = result.node.type
    assert_type type, GenericClassInstanceType

    type.type_vars["T"].type.should eq(mod.bool)
    type.instance_vars["@value"].type.should eq(mod.bool)
  end

  it "does automatic type inference of new for nested generic type" do
    nodes = parse "
      class Foo
        class Bar(T)
          def initialize(x : T)
            @x = x
          end
        end
      end

      Foo::Bar.new(1)
      "
    result = infer_type nodes
    mod = result.program
    assert_type nodes, Expressions

    type = nodes.last.type
    assert_type type, GenericClassInstanceType

    type.type_vars["T"].type.should eq(mod.int32)
    type.instance_vars["@x"].type.should eq(mod.int32)
  end

  it "reports uninitialized constant" do
    assert_error "Foo.new",
      "uninitialized constant Foo"
  end

  it "reports undefined method when method inside a class" do
    assert_error "class Int; def foo; 1; end; end; foo",
      "undefined local variable or method 'foo'"
  end

  it "reports undefined instance method" do
    assert_error "1.foo",
      "undefined method 'foo' for Int"
  end

  it "reports unknown class when extending" do
    assert_error "class Foo < Bar; end",
      "uninitialized constant Bar"
  end

  it "reports superclass mismatch" do
    assert_error "class Foo; end; class Bar; end; class Foo < Bar; end",
      "superclass mismatch for class Foo (Bar for Reference)"
  end

  it "reports wrong number of arguments for initialize" do
    assert_error "
      class Foo
        def initialize(x, y)
        end
      end

      f = Foo.new
      ",
      "wrong number of arguments"
  end

  it "reports can't instantiate abstract class on new" do
    assert_error "
      abstract class Foo; end
      Foo.new
      ",
      "can't instantiate abstract class Foo"
  end

  it "reports can't instantiate abstract class on allocate" do
    assert_error "
      abstract class Foo; end
      Foo.allocate
      ",
      "can't instantiate abstract class Foo"
  end

  it "doesn't lookup new in supermetaclass" do
    assert_type("
      class Foo(T)
      end

      Reference.new
      Foo(Int32).new
      ") do
        foo = types["Foo"]
        assert_type foo, GenericClassType
        foo.instantiate([int32] of Type)
      end
  end

  it "errors when wrong arguments for new" do
    assert_error "Reference.new 1",
      "wrong number of arguments"
  end

  it "types virtual method of generic class" do
    assert_type("
      require \"char\"

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

      Foo(Int).new.foo
      ") { int32 }
  end

  # it "types immutable class" do
  #   input = parse("
  #     class Foo
  #     end

  #     Foo.new
  #   ")
  #   mod, input = infer_type input
  #   input.last.type.immutable.should be_true
  # end

  # it "types mutable class" do
  #   input = parse("
  #     class Foo
  #       def foo
  #         @x = 1
  #         self
  #       end
  #     end

  #     Foo.new.foo
  #   ")
  #   mod, input = infer_type input
  #   input.last.type.immutable.should be_false
  # end

  # it "types immutable class with instance vars" do
  #   input = parse(%q(
  #     class Foo
  #       def initialize
  #         @x = 1
  #       end
  #     end

  #     Foo.new
  #   ))
  #   mod, input = infer_type input
  #   input.last.type.immutable.should be_true
  # end

  it "infers types of instance variables to nilable" do
    input = parse("
      def bar
      end

      class Foo
        def initialize
          if true
            @superclass = 1
            bar
          else
            @depth = 0
          end
        end
      end

      f = Foo.new
      ")
    result = infer_type input
    mod = result.program
    foo = mod.types["Foo"]
    assert_type foo, NonGenericClassType

    foo.instance_vars["@superclass"].type.should eq(mod.union_of(mod.nil, mod.int32))
  end

  it "allows defining classes inside modules or classes with ::" do
    input = parse("
      class Foo
      end

      class Foo::Bar
      end
      ")
    result = infer_type input
    mod = result.program
    bar = mod.types["Foo"].types["Bar"]
    assert_type bar, NonGenericClassType
  end

  it "doesn't lookup type in parents' containers, and lookups and in program" do
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

    assert_type("
      #{code}
      Mod::Foo.foo(Mod::Bar.new)
      ") { int32 }

    assert_type("
      #{code}
      Mod::Foo.foo(Bar.new)
      ") { char }
  end

  it "finds in global scope if includes module" do
    assert_type("
      class Baz
      end

      module Foo
        class Bar
          include Foo

          Baz
        end
      end

      1
    ") { int32 }
  end

  it "types instance vars as nilable if doesn't invoke super in initialize" do
    node = parse("
      class Foo
        def initialize
          @baz = Baz.new
          @another = 1
        end
      end

      class Bar < Foo
        def initialize
          @another = 2
        end
      end

      class Baz
      end

      foo = Foo.new
      bar = Bar.new
    ")
    result = infer_type node
    mod = result.program
    foo = mod.types["Foo"]
    assert_type foo, NonGenericClassType

    foo.instance_vars["@baz"].type.should eq(mod.union_of(mod.nil, mod.types["Baz"]))
    foo.instance_vars["@another"].type.should eq(mod.int32)
  end

  it "types instance vars as nilable if doesn't invoke super in initialize with deep subclass" do
    node = parse("
      class Foo
        def initialize
          @baz = Baz.new
          @another = 1
        end
      end

      class Bar < Foo
        def initialize
          super
        end
      end

      class BarBar < Bar
        def initialize
          @another = 2
        end
      end

      class Baz
      end

      foo = Foo.new
      bar = Bar.new
    ")
    result = infer_type node
    mod = result.program
    foo = mod.types["Foo"]
    assert_type foo, NonGenericClassType

    foo.instance_vars["@baz"].type.should eq(mod.union_of(mod.nil, mod.types["Baz"]))
    foo.instance_vars["@another"].type.should eq(mod.int32)
  end

  it "types instance vars as nilable if doesn't invoke super with default arguments" do
    node = parse("
      class Foo
        def initialize
          @baz = Baz.new
          @another = 1
        end
      end

      class Bar < Foo
        def initialize(x = 1)
          super()
        end
      end

      class Baz
      end

      foo = Foo.new
      bar = Bar.new(1)
    ")
    result = infer_type node
    mod = result.program
    foo = mod.types["Foo"]
    assert_type foo, NonGenericClassType

    foo.instance_vars["@baz"].type.should eq(mod.types["Baz"])
    foo.instance_vars["@another"].type.should eq(mod.int32)
  end

  it "checks instance vars of included modules" do
    result = assert_type("
      module Lala
        def lala
          @x = 'a'
        end
      end

      class Foo
        include Lala
      end

      class Bar < Foo
        include Lala

        def initialize
          @x = 1
        end
      end

      b = Bar.new
      f = Foo.new
      f.lala
      ") { char }

    mod = result.program

    foo = mod.types["Foo"]
    assert_type foo, NonGenericClassType

    bar = mod.types["Bar"]
    assert_type bar, NonGenericClassType

    foo.instance_vars["@x"].type.should eq(mod.union_of(mod.nil, mod.int32, mod.char))
    bar.instance_vars.length.should eq(0)
  end

  pending "types instance var as nilable if it appears inside a block" do
    assert_type("
      class Foo
        def initialize
          foo { @var = 1 }
        end

        def foo
          yield
        end

        def var
          @var
        end
      end
      Foo.new.var
      ") { |mod| union_of(mod.nil, int32) }
  end

  it "allows instantiating generic class with number" do
    assert_type("
      class Foo(T)
      end

      Foo(1).new
      ") do
        foo = types["Foo"]
        assert_type foo, GenericClassType
        foo.instantiate([NumberLiteral.new("1", :i32)])
      end
  end

  it "uses number type var in class method" do
    assert_type("
      class Foo(T)
        def self.foo
          T
        end
      end

      Foo(1).foo
      ") { int32 }
  end
end
