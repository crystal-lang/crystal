require 'spec_helper'

describe "Type relationship" do
  let(:mod) { Crystal::Module.new }

  it "computes simple relationships" do
    type = ObjectType.new("Foo")

    relationships = Type.relationship([type, type])

    relationships.length.should eq(2)
    relationships[0].should eq(type)
    relationships[1].should eq(Path.new(0))
  end

  it "computes nested relationships" do
    second = ObjectType.new('Second')
    first = ObjectType.new('First').with_var('@next', second)

    relationships = Type.relationship([first, second])

    relationships.length.should eq(2)
    relationships[0].should eq(first)
    relationships[1].should eq(Path.new(0, '@next'))
  end

  it "computes inverted nested relationships" do
    second = ObjectType.new('Second')
    first = ObjectType.new('First').with_var('@next', second)

    relationships = Type.relationship([second, first])

    relationships.length.should eq(2)
    relationships[0].should eq(second)
    relationships[1].should eq(ObjectType.new('First').with_var('@next', Path.new(0)))
  end

  it "computes very nested relationships" do
    third = ObjectType.new('Third')
    second = ObjectType.new('Second').with_var('@foo', third)
    first = ObjectType.new('First').with_var('@next', second)

    relationships = Type.relationship([first, second, third])

    relationships.length.should eq(3)
    relationships[0].should eq(first)
    relationships[1].should eq(Path.new(0, '@next'))
    relationships[2].should eq(Path.new(0, '@next', '@foo'))
  end

  it "computes inverted very nested relationships" do
    third = ObjectType.new('Third')
    second = ObjectType.new('Second').with_var('@foo', third)
    first = ObjectType.new('First').with_var('@next', second)

    relationships = Type.relationship([third, second, first])

    relationships.length.should eq(3)
    relationships[0].should eq(third)
    relationships[1].should eq(ObjectType.new('Second').with_var('@foo', Path.new(0)))
    relationships[2].should eq(ObjectType.new('First').with_var('@next', Path.new(1)))
  end

  it "computes very nested relationships in yet another order" do
    third = ObjectType.new('Third')
    second = ObjectType.new('Second').with_var('@foo', third)
    first = ObjectType.new('First').with_var('@next', second)

    relationships = Type.relationship([third, first, second])

    relationships.length.should eq(3)
    relationships[0].should eq(third)
    relationships[1].should eq(ObjectType.new('First').with_var('@next', ObjectType.new('Second').with_var('@foo', Path.new(0))))
    relationships[2].should eq(Path.new(1, '@next'))
  end

  it "computes simple relationships with Array" do
    type = ArrayType.new

    relationships = Type.relationship([type, type])

    relationships.length.should eq(2)
    relationships[0].should eq(type)
    relationships[1].should eq(Path.new(0))
  end

  it "computes simple relationships inside Array" do
    obj = ObjectType.new('Foo')
    type = ArrayType.of(obj)

    relationships = Type.relationship([type, obj])

    relationships.length.should eq(2)
    relationships[0].should eq(type)
    relationships[1].should eq(Path.new(0, 'element'))
  end

  it "computes simple relationships with Union" do
    type = UnionType.new

    relationships = Type.relationship([type, type])

    relationships.length.should eq(2)
    relationships[0].should eq(type)
    relationships[1].should eq(Path.new(0))
  end

  it "computes nested relationships with Union" do
    obj1 = ObjectType.new('Foo')
    obj2 = ObjectType.new('Bar')
    type = UnionType.new obj1, obj2

    relationships = Type.relationship([type, obj1, obj2])

    relationships.length.should eq(3)
    relationships[0].should eq(type)
    relationships[1].should eq(Path.new(0, 0))
    relationships[2].should eq(Path.new(0, 1))
  end

  it "computes relationship with object with primitive type" do
    obj = ObjectType.new('Foo').with_var('@next', mod.int)

    relationships = Type.relationship([obj])

    relationships.should eq([obj])
  end

  it "computes relationship with recursive type" do
    obj = ObjectType.new('Foo')
    obj.with_var('@next', obj)

    relationships = Type.relationship([obj, obj])
    relationships.length.should eq(2)
    relationships[0].should eq(ObjectType.new('Foo').with_var('@next', Path.new(0)))
    relationships[1].should eq(Path.new(0))
  end
end
