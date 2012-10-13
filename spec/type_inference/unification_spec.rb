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

  it "unifies static array types" do
    input = parse 'a = StaticArray.new(2); a[0] = 1; a[1] = 1.1; b = StaticArray.new(2); b[0] = 1; b[1] = 1.1; c = a; c = b'
    infer_type input
    input[-2].value.type.should equal(input[-1].value.type)
  end

  it "unifies array types" do
    input = parse 'a = [0, 0]; a[0] = 1; a[1] = 1.1; b = [0, 0]; b[0] = 1; b[1] = 1.1; c = a; c = b'
    infer_type input
    input[-2].value.type.should equal(input[-1].value.type)
  end
end