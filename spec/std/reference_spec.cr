require "spec"

class ReferenceSpecTestClass
  @x : Int32
  @y : String

  def initialize(@x, @y)
  end
end

class ReferenceSpecTestClassBase
end

class ReferenceSpecTestClassSubclass < ReferenceSpecTestClassBase
end

describe "Reference" do
  it "compares reference to other reference" do
    o1 = Reference.new
    o2 = Reference.new
    (o1 == o1).should be_true
    (o1 == o2).should be_false
    (o1 == 1).should be_false
  end

  it "should not be nil" do
    Reference.new.nil?.should be_false
  end

  it "should be false when negated" do
    (!Reference.new).should be_false
  end

  it "does inspect" do
    r = ReferenceSpecTestClass.new(1, "hello")
    r.inspect.should eq(%(#<ReferenceSpecTestClass:0x#{r.object_id.to_s(16)} @x=1, @y="hello">))
  end

  it "does to_s" do
    r = ReferenceSpecTestClass.new(1, "hello")
    r.to_s.should eq(%(#<ReferenceSpecTestClass:0x#{r.object_id.to_s(16)}>))
  end

  it "does inspect for class" do
    String.inspect.should eq("String")
  end

  it "does to_s for class" do
    String.to_s.should eq("String")
  end

  it "does to_s for class if virtual" do
    [ReferenceSpecTestClassBase, ReferenceSpecTestClassSubclass].to_s.should eq("[ReferenceSpecTestClassBase, ReferenceSpecTestClassSubclass]")
  end

  it "returns itself" do
    x = "hello"
    x.itself.should be(x)
  end
end
