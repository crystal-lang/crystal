require 'spec_helper'

describe 'Type inference: class' do
  it "types Const#allocate" do
    mod, type = assert_type("class Foo; end; Foo.allocate") { types["Foo"] }
    type.should be_class
  end

  it "types Const#new" do
    mod, type = assert_type("class Foo; end; Foo.new") { types["Foo"] }
    type.should be_class
  end

  it "types Const#new#method" do
    assert_type("class Foo; def coco; 1; end; end; Foo.new.coco") { int32 }
  end

  it "types class inside class" do
    assert_type("class Foo; class Bar; end; end; Foo::Bar.allocate") { types["Foo"].types["Bar"] }
  end

  it "types instance variable" do
    mod, type = assert_type(%(
      class Foo(T)
        def set
          @coco = 2
        end
      end

      f = Foo(Int32).new
      f.set
      f
    )) { types["Foo"].instantiate([int32]) }
    type.instance_vars["@coco"].type.should eq(mod.union_of(mod.nil, mod.int32))
  end

  it "types instance variable" do
    input = parse %(
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
    )
    mod, input = infer_type input
    input[1].type.should eq(mod.types["Foo"].instantiate([mod.int32]))
    input[1].type.instance_vars["@coco"].type.should eq(mod.union_of(mod.nil, mod.int32))
    input[3].type.should eq(mod.types["Foo"].instantiate([mod.float64]))
    input[3].type.instance_vars["@coco"].type.should eq(mod.union_of(mod.nil, mod.float64))
  end

  it "types instance variable on getter" do
    input = parse %(
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
    )
    mod, input = infer_type input
    input[3].type.should eq(mod.union_of(mod.nil, mod.int32))
    input.last.type.should eq(mod.union_of(mod.nil, mod.float64))
  end

  it "types recursive type" do
    input = parse %(
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
    )
    mod, input = infer_type input
    node = mod.types["Node"]
    node.lookup_instance_var("@next").type.should eq(mod.union_of(mod.nil, node))
    input.last.type.should eq(node)
  end

  it "types self inside method call without obj" do
    mod, type = assert_type(%(
      class Foo
        def foo
          bar
        end

        def bar
          self
        end
      end

      Foo.new.foo
    )) { types["Foo"] }
  end

  it "types type var union" do
    mod, type = assert_type(%(
      class Foo(T)
      end

      Foo(Int32 | Float64).new
      )) { types["Foo"].instantiate([union_of(int32, float64)]) }
  end

  it "types class and subclass as one type" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      )) { types["Foo"].hierarchy_type }
  end

  it "types class and subclass as one type" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Bar.new || Baz.new
      )) { types["Foo"].hierarchy_type }
  end

  it "types class and subclass as one type" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      a = Foo.new || Bar.new || Baz.new
      )) { types["Foo"].hierarchy_type }
  end

  it "does automatic inference of new for generic types" do
    mod, type = assert_type(%(
      class Box(T)
        def initialize(value : T)
          @value = value
        end
      end

      b = Box.new(10)
      )) { types["Box"].instantiate([int32]) }
    type.type_vars["T"].type.should eq(mod.int32)
    type.instance_vars["@value"].type.should eq(mod.int32)
  end

  it "does automatic type inference of new for generic types 2" do
    mod, type = assert_type(%q(
      class Box(T)
        def initialize(x, value : T)
          @value = value
        end
      end

      b1 = Box.new(1, 10)
      b2 = Box.new(1, false)
      )) { types["Box"].instantiate([bool]) }
    type.type_vars["T"].type.should eq(mod.bool)
    type.instance_vars["@value"].type.should eq(mod.bool)
  end

  it "does automatic type inference of new for nested generic type" do
    nodes = parse %q(
      class Foo
        class Bar(T)
          def initialize(x : T)
            @x = x
          end
        end
      end

      Foo::Bar.new(1)
      )
    mod, nodes = infer_type nodes
    nodes.last.type.type_vars["T"].type.should eq(mod.int32)
    nodes.last.type.instance_vars["@x"].type.should eq(mod.int32)
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
    assert_error %(
      class Foo
        def initialize(x, y)
        end
      end

      f = Foo.new
      ),
      "wrong number of arguments"
  end

  it "reports can't instantiate abstract class on new" do
    assert_error %q(
      abstract class Foo; end
      Foo.new
      ),
      "can't instantiate abstract class Foo"
  end

  it "reports can't instantiate abstract class on allocate" do
    assert_error %q(
      abstract class Foo; end
      Foo.allocate
      ),
      "can't instantiate abstract class Foo"
  end

  it "doesn't lookup new in supermetaclass" do
    assert_type(%q(
      class Foo(T)
      end

      Reference.new
      Foo(Int32).new
      )) { types["Foo"].instantiate([int32]) }
  end

  it "errors when wrong arguments for new" do
    assert_error "Reference.new 1",
      "wrong number of arguments"
  end

  it "types virtual method of generic class" do
    assert_type(%q(
      require "char"

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
      )) { union_of(int32, char) }
  end

  it "types immutable class" do
    input = parse(%q(
      class Foo
      end

      Foo.new
    ))
    mod, input = infer_type input
    input.last.type.immutable.should be_true
  end

  it "types mutable class" do
    input = parse(%q(
      class Foo
        def foo
          @x = 1
          self
        end
      end

      Foo.new.foo
    ))
    mod, input = infer_type input
    input.last.type.immutable.should be_false
  end

  it "types immutable class with instance vars" do
    input = parse(%q(
      class Foo
        def initialize
          @x = 1
        end
      end

      Foo.new
    ))
    mod, input = infer_type input
    input.last.type.immutable.should be_true
  end
end
