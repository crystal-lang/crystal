require 'spec_helper'

describe 'Type inference: class' do
  it "types Const#alloc" do
    assert_type("class Foo; end; Foo.alloc") { types['Foo'] }
  end

  it "types Const#new" do
    assert_type("class Foo; end; Foo.new") { types['Foo'] }
  end

  it "types Const#new#method" do
    assert_type("class Foo; def coco; 1; end; end; Foo.new.coco") { int }
  end

  it "types instance variable" do
    input = parse %(
      class Foo
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
      class Foo
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
    input[3].type.should eq(ObjectType.new("Foo").with_var("@coco", mod.float))
  end

  it "types instance variable on getter" do
    input = parse %(
      class Foo
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
    input.last.type.should eq(mod.float)
  end

  it "types recursive type" do
    input = parse %(
      class Node
        def init
          @has_next = false
          self
        end

        def add
          if @has_next
            @next.add
          else
            @next = Node.new
            @next.init
            @has_next = true
          end
        end
      end

      n = Node.new.init
      n.add
      n
    )
    mod = infer_type input
    recursive_type = ObjectType.new('Node').with_var("@has_next", mod.bool)
    recursive_type.with_var("@next", recursive_type)
    input.last.type.should eq(recursive_type)
  end

  it "types separately method calls that create instances" do
    assert_type(%(
      class Node
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
    )) { ObjectType.new('Node').with_var("@value", float) }
  end

  it "types separately method calls that create instances with two instance vars" do
    assert_type(%(
      class Node
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
    )) { ObjectType.new('Node').with_var("@x", int).with_var("@y", float) }
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
    )) { ObjectType.new('Foo') }
  end
end
