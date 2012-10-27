require 'spec_helper'

describe "Type inference: union" do
  it "types union when obj is union" do
    assert_type("a = 1; a = 2.3; a + 1") { UnionType.new(int, float) }
  end

  it "types union when arg is union" do
    assert_type("a = 1; a = 2.3; 1 + a") { UnionType.new(int, float) }
  end

  it "types union when both obj and arg are union" do
    assert_type("a = 1; a = 2.3; a + a") { UnionType.new(int, float) }
  end

  it "unifies unions when instance var changes" do
    nodes = parse(%Q(
      class A
        def next=(n)
          @next = n
        end
      end

      a = A.new
      a.next = 1
      a.next = 2.3
      a
    ))
    mod = infer_type nodes

    expected_type = ObjectType.new("A").with_var("@next", UnionType.new(mod.int, mod.float))

    nodes[1].type.should eq(expected_type)
    nodes[2].target_def.owner.should eq(expected_type)
    nodes[3].target_def.owner.should eq(expected_type)
    nodes.last.type.should eq(expected_type)
  end

  pending "unifies unions when instance var changes 2" do
    nodes = parse(%Q(
      class A
        def next=(n)
          @next = n
        end
      end

      a = A.new
      a.next = 1

      a = A.new
      a.next = 2.3
      a
    ))
    mod = infer_type nodes

    expected_type = ObjectType.new("A").with_var("@next", UnionType.new(mod.int, mod.float))

    nodes[1].type.should eq(expected_type)
    nodes[2].target_def.owner.should eq(expected_type)
    nodes[3].type.should eq(expected_type)
    nodes[4].target_def.owner.should eq(expected_type)
    nodes.last.type.should eq(expected_type)

    # The alloc of the first A.new
    nodes[1].value.target_def.body.target_def.body.type.should eq(expected_type)

    # The alloc of the second A.new
    nodes[3].value.target_def.body.target_def.body.type.should eq(expected_type)
  end

  it "types union of classes" do
    assert_type("class A; end; class B; end; a = A.new; a = B.new; a") { UnionType.new(ObjectType.new('A'), ObjectType.new('B')) }
  end
end