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
      class Foo(T)
        def set
          @coco = 2
        end
      end

      f = Foo(Int).new
      f.set
    )
    mod = infer_type input
    input[1].type.should eq(ObjectType.new("Foo").with_var("@coco", mod.int))
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
    input[1].type.should eq(ObjectType.new("Foo").with_var("@coco", mod.int))
    input[3].type.should eq(ObjectType.new("Foo").with_var("@coco", mod.double))
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
    input[3].type.should eq(mod.int)
    input.last.type.should eq(mod.double)
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
    node.instance_vars["@next"].type.should eq(mod.union_of(node, mod.nil))
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
    )) { types["Foo"] }
  end

  it "types instance variable as nilable if read before write" do
    assert_type(%(
      class Foo
        def initialize
          a = @coco
          @coco = 2
        end
        def coco
          @coco
        end
      end

      Foo.new.coco
    )) { union_of(int, self.nil) }
  end

  it "types instance variable as nilable if inside if" do
    assert_type(%(
      class Foo
        def initialize
          if false
            @coco = 2
          end
        end
        def coco
          @coco
        end
      end

      Foo.new.coco
    )) { union_of(int, self.nil) }
  end

  it "doesn't type instance variable as nilable if inside if but had type" do
    assert_type(%(
      class Foo
        def initialize
          @coco = 2
          if false
            @coco = 2
          end
        end
        def coco
          @coco
        end
      end

      Foo.new.coco
    )) { int }
  end

  it "types instance variable as nilable if inside while" do
    assert_type(%(
      class Foo
        def initialize
          while false
            @coco = 2
          end
        end
        def coco
          @coco
        end
      end

      Foo.new.coco
    )) { union_of(int, self.nil) }
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
    )) { union_of(int, self.nil) }
  end
end
