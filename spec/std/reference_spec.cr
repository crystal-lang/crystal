require "spec"

class ReferenceSpecTestClass
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
    expect((o1 == o1)).to be_true
    expect((o1 == o2)).to be_false
    expect((o1 == 1)).to be_false
  end

  it "should not be nil" do
    expect(Reference.new.nil?).to be_false
  end

  it "should be false when negated" do
    expect((!Reference.new)).to be_false
  end

  it "does inspect" do
    r = ReferenceSpecTestClass.new(1, "hello")
    expect(r.inspect).to eq(%(#<ReferenceSpecTestClass:0x#{r.object_id.to_s(16)} @x=1, @y="hello">))
  end

  it "does to_s" do
    r = ReferenceSpecTestClass.new(1, "hello")
    expect(r.to_s).to eq(%(#<ReferenceSpecTestClass:0x#{r.object_id.to_s(16)}>))
  end

  it "does inspect for class" do
    expect(String.inspect).to eq("String")
  end

  it "does to_s for class" do
    expect(String.to_s).to eq("String")
  end

  it "does to_s for class if virtual" do
    expect([ReferenceSpecTestClassBase, ReferenceSpecTestClassSubclass].to_s).to eq("[ReferenceSpecTestClassBase, ReferenceSpecTestClassSubclass]")
  end

  it "returns itself" do
    x = "hello"
    expect(x.itself).to be(x)
  end
end
