require 'spec_helper'

describe 'Type inference: class' do
  it "types Const#allocate" do
    assert_type("class Foo; end; Foo.allocate") { "Foo".object }
  end

  it "types Const#new" do
    assert_type("class Foo; end; Foo.new") { "Foo".object }
  end

  it "types Const#new#method" do
    assert_type("class Foo; def coco; 1; end; end; Foo.new.coco") { int }
  end

  it "types class inside class" do
    assert_type("class Foo; class Bar; end; end; Foo::Bar.allocate") { "Bar".object }
  end

  it "types instance variable" do
    input = parse %(
      class Foo(T)
        def set
          @coco = 2
        end
      end

      f = Foo(Int).new
      f.set
    )
    mod = infer_type input
    input[1].type.should eq("Foo".generic("T" => mod.int).with_vars("@coco" => mod.union_of(mod.nil, mod.int)))
  end

  it "types instance variable" do
    input = parse %(
      class Foo(T)
        def set(value : T)
          @coco = value
        end
      end

      f = Foo(Int).new
      f.set 2

      g = Foo(Double).new
      g.set 2.5
    )
    mod = infer_type input
    input[1].type.should eq("Foo".generic("T" => mod.int).with_vars("@coco" => mod.union_of(mod.nil, mod.int)))
    input[3].type.should eq(("Foo").generic("T" => mod.double).with_vars("@coco" => mod.union_of(mod.nil, mod.double)))
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

      f = Foo(Int).new
      f.set 2
      f.get

      g = Foo(Double).new
      g.set 2.5
      g.get
    )
    mod = infer_type input
    input[3].type.should eq(mod.union_of(mod.nil, mod.int))
    input.last.type.should eq(mod.union_of(mod.nil, mod.double))
  end

  it "types recursive type" do
    input = parse %(
      require "prelude"

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
    mod = infer_type input
    node = mod.types["Node"]
    node.lookup_instance_var("@next").type.should eq(mod.union_of(mod.nil, node))
    input.last.type.should eq(node)
  end

  it "types self inside method call without obj" do
    assert_type(%(
      class Foo
        def foo
          bar
        end

        def bar
          self
        end
      end

      Foo.new.foo
    )) { "Foo".object }
  end

  it "types type var union" do
    assert_type(%(
      class Foo(T)
      end

      Foo(Int | Double).new
      )) { "Foo".generic("T" => union_of(int, double)) }
  end

  it "types class and subclass as one type" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      )) { "Foo".hierarchy }
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
      )) { "Foo".hierarchy }
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
      )) { "Foo".hierarchy }
  end

  it "does automatic inference of new for generic types" do
    assert_type(%(
      class Box(T)
        def initialize(value : T)
          @value = value
        end
      end

      b = Box.new(10)
      )) { "Box".generic(T: int).with_vars(value: int) }
  end

  it "does automatic type inference of new for generic types 2" do
    assert_type(%q(
      class Box(T)
        def initialize(x, value : T)
          @value = value
        end
      end

      b1 = Box.new(1, 10)
      b2 = Box.new(1, false)
      )) { "Box".generic(T: bool).with_vars(value: bool) }
  end
end
