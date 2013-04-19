require 'spec_helper'

describe 'Type inference unification' do
  it "reuses same type" do
    input = parse 'class A; end; a = A.new; a = A.new'
    infer_type input
    input[1].type.should equal(input[2].type)
  end

  it "unifies type of instance variable" do
    input = parse %Q(
      class A
        def next=(n)
          @next = n
        end
      end

      class B
        def next=(n)
          @next = n
        end
      end

      a = A.new
      while true
        b = a.next = B.new
        a = b.next = A.new
      end
      a
    )
    infer_type input
    a_type = input.last.type
    a_type.instance_vars['@next'].type.instance_vars['@next'].type.should equal(a_type)
  end

  it "unifies recursive type" do
    input = parse %Q(
      class Node
        def add(x)
          @left = x
          @left.add(x)
        end
      end

      root = Node.new
      root.add Node.new
      root
    )
    infer_type input
  end

  it "unifies union types" do
    input = parse 'a = 1; a = 1.1; b = 1; b = 1.1; c = a; c = b'
    infer_type input
    input[4].value.type.should equal(input[5].value.type)
  end

  it "unifies array types" do
    input = parse 'require "pointer"; require "array"; a = [0, 0]; a[0] = 1; a[1] = 1.1; b = [0, 0]; b[0] = 1; b[1] = 1.1; c = a; c = b'
    infer_type input
    input[-2].value.type.should equal(input[-1].value.type)
  end

  it "unifies pointer types" do
    input = parse 'a = 1; b = a.ptr; c = a.ptr'
    infer_type input
    input[1].target.type.should equal(input[2].target.type)
  end

  it "unifies two objects with arrays of unions" do
    mod = Crystal::Program.new
    nodes = Expressions.from [Var.new('a'), Var.new('b')]
    nodes[0].type = ObjectType.new('Foo').generic!.with_var('@x', mod.array_of(UnionType.new(ObjectType.new('Bar').generic!, ObjectType.new('Bar').generic!)))
    nodes[1].type = ObjectType.new('Foo').generic!.with_var('@x', mod.array_of(UnionType.new(ObjectType.new('Bar').generic!, ObjectType.new('Bar').generic!)))

    unify nodes

    nodes[0].type.should equal(nodes[1].type)
  end

  it "unifies array of union of same type within def" do
    input = parse %(
      require "array"

      class Foo
        def initialize
          @x = [Bar.new, Bar.new]
        end
      end

      class Bar
      end

      Foo.new
    )
    infer_type input
    input.last.type.should equal(input.last.target_def.body.type)
  end

  it "unifies recursive generic types" do
    input = parse %(
      class Entry
        def next=(n)
          @next = n
        end

        def next
          @next
        end
      end

      entry1 = Entry.new
      entry1.next = entry1

      entry2 = Entry.new
      entry2.next = entry1
      entry2.next = entry2

      union = entry1
      union = entry2
      )
    infer_type input

    type = input.last.type

    type.should be_a(ObjectType)
    type.instance_vars['@next'].type.should be_a(ObjectType)
  end
end