require 'spec_helper'

describe 'Type inference: def instance' do
  test_type = "class Foo; #{rw :value}; end"

  it "reuses type mutation" do
    assert_type(%Q(
      #{test_type}

      def foo(x)
        x.value = 1
      end

      f = Foo.new
      foo(f)

      g = Foo.new
      foo(g)
      g
      )
    ) { ObjectType.new("Foo").with_var("@value", int) }
  end

  it "reuses path mutation" do
    assert_type(%Q(
      #{test_type}

      class Bar
        #{rw :value}
      end

      def foo(x, y)
        x.value = y
      end

      f1 = Foo.new
      b1 = Bar.new
      foo(f1, b1)

      f2 = Foo.new
      b2 = Bar.new
      foo(f2, b2)

      b2.value = 1
      f2
      )
    ) { ObjectType.new("Foo").with_var("@value", ObjectType.new("Bar").with_var("@value", int)) }
  end

  it "repoints new to correct type" do
    input = parse %Q(
      #{test_type}
      f = Foo.new
      f.value = 1
      )
    mod = infer_type input
    input[1].value.target_def.body.type.should eq(ObjectType.new('Foo').with_var('@value', mod.int))
  end

  it "repoints target defs to correct types" do
    input = parse %Q(
      #{test_type}
      class Foo
        def foo
          self.value.value
        end
      end

      x = Foo.new
      x.value = Foo.new
      x.value.value = Object.new
      x.foo)
    mod = infer_type input

    sub = ObjectType.new('Foo').with_var('@value', ObjectType.new('Object'))
    obj = ObjectType.new('Foo').with_var('@value', sub)
    input[2].value.target_def.body.type.should eq(obj)
    input[3].target_def.owner.should eq(obj)
    input[3].args[0].type.should eq(sub)
    input[3].target_def.args[0].type.should eq(sub)
    input[4].target_def.owner.should eq(sub)
  end

  it "applies all mutations to target def body type" do
    input = parse %Q(
      #{test_type}
      f = Foo.new
      f.value = Foo.new
      f.value.value = "hola")
    mod = infer_type input

    input.last.obj.target_def.body.type.should eq(input.last.obj.type)
  end

  it "applies all mutations to target_def body type with recursive type" do
    input = parse %Q(
      class Node
        def add(x)
          @left = Node.alloc
          @left.add(x)
          @right = Node.alloc
          @right.add(x)
        end
      end

      root = Node.alloc
      root.add 'c'
      )
    mod = infer_type input
    input[2].target_def.body[2].value.target_def.body.type.should eq(input[1].type)
  end

  it "applies all mutations to target_def body type with recursive type 2" do
    input = parse %Q(
      class Node
        def add(x)
          @left = Node.new
          @left.add(x)
          @right = Node.new
          @right.add(x)
        end
      end

      root = Node.new
      root.add 'c'
      )
    mod = infer_type input
    input[2].target_def.body[2].value.target_def.body.type.should eq(input[1].type)
  end

  it "doesn't infect other vars" do
    input = parse %Q(
      class Node
        def add(x)
          @left = Node.new
          @left.add(x)
          @right = Node.new
          @right.add(x)
        end
      end

      root = Node.new
      root.add 'c'

      other = Node.new
      )
    mod = infer_type input
    input[3].type.should eq(ObjectType.new('Node'))
  end

  it "types new when modifiying in place" do
    input = parse %Q(
      class A
        def foo
          @value = 1
        end
      end

      A.new.foo
      )
    mod = infer_type input
    input[1].obj.target_def.body.type.should eq(input[1].obj.type)
  end

  it "do not try to compute parent path of new instance" do
    nodes = parse %Q(
      def foo
        [[]][0].push 1
      end

      foo
    )
    mod = infer_type nodes
  end

  it "" do
    nodes = parse %Q(
      class Foo
        def bar
          @value = 1
        end
      end

      class Hash
        def initialize
          @a = Foo.new
        end

        def foo
          @a.bar
        end
      end

      Hash.new.foo
      )
    mod = infer_type nodes

    type = ObjectType.new('Hash').with_var('@a', ObjectType.new('Foo').with_var('@value', mod.int))
    nodes.last.obj.type.should eq(type)
  end

  it "" do
    nodes = parse %Q(
      class Foo
        def value=(value)
          @value = value
        end

        def value
          @value + 2.3
        end
      end

      f = Foo.new
      f.value = 1
      f.value
      f.value = 2.3
      )
    mod = infer_type nodes
    nodes[3].target_def.body.target_def.should be_a_kind_of(Dispatch)
  end

  it "" do
    nodes = parse %Q(
      class Foo
        def value=(value)
          @value = value
        end

        def value
          a = @value + 1
          a + 2.3
        end
      end

      f = Foo.new
      f.value = 1
      f.value
      f.value = 2.3
      )
    mod = infer_type nodes
    nodes[3].target_def.body[0].target.type.should eq(UnionType.new(mod.int, mod.float))
  end

  it "" do
    nodes = parse %Q(
      class Hash
        def initialize
          @buckets = [[], []]
        end

        def foo
          @buckets[0].push 1
        end
      end

      Hash.new.foo
      )
    mod = infer_type nodes
    nodes[1].obj.target_def.body[1].target_def.body.value.type.should eq(ArrayType.of(ArrayType.of(mod.int)))
  end

  it "clone dispatch" do
    nodes = parse %Q(
      class Foo
        def foo(a)
          @buckets = [a]
        end

        def bar
          @buckets.push 1
        end
      end

      a = 1

      h = Foo.new
      h.foo(a)
      h.bar

      a = 2.3
    )
    mod = infer_type nodes
  end

  it "doesn't reuse new object" do
    nodes = parse %Q(
      #{test_type}

      def foo(x)
        x.value = Foo.new
      end

      f = Foo.new
      foo(f)

      g = Foo.new
      foo(g)
      g.value.value = 1
    )
    mod = infer_type nodes
    nodes[2].target.type.should eq(ObjectType.new('Foo').with_var('@value', ObjectType.new('Foo')))
    nodes[4].target.type.should eq(ObjectType.new('Foo').with_var('@value', ObjectType.new('Foo').with_var('@value', mod.int)))
  end

  it "applies return mutation" do
    nodes = parse %Q(
      #{test_type}

      def foo(x)
        r = Foo.new
        r.value = x
        r
      end

      bar = Foo.new
      r1 = foo(bar)
      r1.value.value = 1
    )

    mod = infer_type nodes
    nodes[2].value.type.should eq(ObjectType.new('Foo').with_var('@value', mod.int))
  end

  it "should apply second return mutation" do
    nodes = parse %Q(
      class Foo
        def foo(x)
          @value = Bar.new(x)
        end
      end

      class Bar
        def initialize(x)
          @x = x
        end
      end

      class Baz
        def coco
          @coco = 1
        end
      end

      f = Foo.new
      o = Baz.new
      f.foo(o)
      o.coco
    )
    mod = infer_type nodes
    nodes[5].obj.type.instance_vars['@value'].type.instance_vars['@x'].type.should be(nodes.last.obj.type)
  end
end