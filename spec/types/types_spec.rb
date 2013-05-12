require 'spec_helper'

describe UnionType do
  let(:mod) { Crystal::Program.new }

  it "compares to union type" do
    union1 = UnionType.new(mod.int, mod.float)
    union2 = UnionType.new(mod.float, mod.int)
    union3 = UnionType.new(mod.float, mod.int, mod.char)

    union1.should eq(union2)
    union1.should_not eq(union3)
  end

  it "merge equal types" do
    Type.merge(mod.int, mod.int).should eq(mod.int)
  end

  it "merge distinct types" do
    Type.merge(mod.int, mod.float).should eq(UnionType.new(mod.int, mod.float))
  end

  it "merge simple type with union" do
    Type.merge(mod.int, UnionType.new(mod.float, mod.char)).should eq(UnionType.new(mod.int, mod.float, mod.char))
  end

  it "merge union types" do
    Type.merge(UnionType.new(mod.int, mod.char), UnionType.new(mod.float, mod.int)).should eq(UnionType.new(mod.char, mod.float, mod.int))
  end

  it "compares union of object types" do
    foo1 = "Foo".object(value: mod.int)
    foo2 = "Foo".object(value: mod.float)
    union1 = mod.union_of(foo1, foo2)
    union2 = mod.union_of(foo2, foo1)
    union1.should eq(union2)
  end

  it "compares object with different instance vars" do
    obj_int = "Foo".object(value: mod.int)
    obj_float = "Foo".object(value: mod.float)

    obj_int.should_not eq(obj_float)
    obj_float.should_not eq(obj_int)
  end

  it "compares union with single object" do
    obj = "Foo".object(value: mod.float)
    union = mod.union_of("Foo".object(value: mod.int), "Foo".object(value: mod.float))

    obj.should_not eq(union)
    union.should_not eq(obj)
  end

  it "compares object type without vars to one with" do
    obj1 = "Foo".object
    obj2 = "Foo".object(value: mod.float)
    obj1.should_not eq(obj2)
  end
end
