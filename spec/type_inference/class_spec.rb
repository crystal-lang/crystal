require 'spec_helper'

describe 'Type inference: class' do
  it "types Const#allocate" do
    assert_type("class Foo; end; Foo.allocate") { types['Foo'] }
  end

  it "types Const#new" do
    assert_type("class Foo; end; Foo.new") { types['Foo'] }
  end

  it "types Const#new#method" do
    assert_type("class Foo; def coco; 1; end; end; Foo.new.coco") { int }
  end

  it "types class inside class" do
    assert_type("class Foo; class Bar; end; end; Foo::Bar.allocate") { types['Foo'].types['Bar'] }
  end

  it "types instance variable" do
    input = parse %(
      generic class Foo
        def set
          @coco = 2
        end
      end

      f = Foo.new
      f.set
    )
    mod = infer_type input
    input[1].type.should eq(ObjectType.new("Foo").with_var("@coco", mod.int))
  end

  it "types instance variable" do
    input = parse %(
      generic class Foo
        def set(value)
          @coco = value
        end
      end

      f = Foo.new
      f.set 2

      g = Foo.new
      g.set 2.5
    )
    mod = infer_type input
    input[1].type.should eq(ObjectType.new("Foo").with_var("@coco", mod.int))
    input[3].type.should eq(ObjectType.new("Foo").with_var("@coco", mod.double))
  end

  it "types instance variable on getter" do
    input = parse %(
      generic class Foo
        def set(value)
          @coco = value
        end

        def get
          @coco
        end
      end

      f = Foo.new
      f.set 2
      f.get

      g = Foo.new
      g.set 2.5
      g.get
    )
    mod = infer_type input
    input[3].type.should eq(mod.int)
    input.last.type.should eq(mod.double)
  end

  it "types recursive type" do
    input = parse %(
      require "prelude"

      generic class Node
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
    recursive_type = ObjectType.new('Node')
    recursive_type.generic = true
    recursive_type.with_var("@next", [recursive_type, mod.nil].union)
    input.last.type.should eq(recursive_type)
  end

  it "types separately method calls that create instances" do
    assert_type(%(
      generic class Node
        #{rw :value}
      end

      def gen
        Node.new
      end

      a = gen
      a.value = 1

      b = gen
      b.value = 2.5
      b
    )) { ObjectType.new('Node').with_var("@value", double) }
  end

  it "types separately method calls that create instances with two instance vars" do
    assert_type(%(
      generic class Node
        #{rw :x}
        #{rw :y}
      end

      def gen
        node = Node.new
        node.x = 1
        node
      end

      a = gen
      a.y = 1

      b = gen
      b.y = 2.5
      b
    )) { ObjectType.new('Node').with_var("@x", int).with_var("@y", double) }
  end

  it "types self inside method call without obj" do
    assert_type(%(
      generic class Foo
        def foo
          bar
        end

        def bar
          self
        end
      end

      Foo.new.foo
    )) { ObjectType.new('Foo') }
  end

  it "types with two instance vars" do
    nodes = parse %Q(
      generic class Foo
        #{rw :a}
        #{rw :b}
      end

      f = Foo.new
      f.a = 1
      f.b = 2.3
      )
    mod = infer_type nodes

    # The allocate
    nodes[1].value.target_def.body.type.should eq(ObjectType.new('Foo').with_var('@a', mod.int).with_var('@b', mod.double))
  end

  it "types instance variable as nilable if read before write" do
    assert_type(%(
      generic class Foo
        def initialize
          a = @coco
          @coco = 2
        end
      end

      Foo.new
    )) { ObjectType.new("Foo").with_var("@coco", [int, self.nil].union) }
  end

  it "types instance variable as nilable if inside if" do
    assert_type(%(
      generic class Foo
        def initialize
          if false
            @coco = 2
          end
        end
      end

      Foo.new
    )) { ObjectType.new("Foo").with_var("@coco", [int, self.nil].union) }
  end

  it "doesn't type instance variable as nilable if inside if but had type" do
    assert_type(%(
      generic class Foo
        def initialize
          @coco = 2
          if false
            @coco = 2
          end
        end
      end

      Foo.new
    )) { ObjectType.new("Foo").with_var("@coco", int) }
  end

  it "types instance variable as nilable if inside while" do
    assert_type(%(
      generic class Foo
        def initialize
          while false
            @coco = 2
          end
        end
      end

      Foo.new
    )) { ObjectType.new("Foo").with_var("@coco", [int, self.nil].union) }
  end

  it "types instance variable as nilable in ||=" do
    assert_type(%(
      class Foo
        def initialize
          @coco ||= 1
        end
        def coco
          @coco
        end
      end

      Foo.new.coco
    )) { [int, self.nil].union }
  end
end
