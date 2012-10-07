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
end