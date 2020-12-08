require "../../spec_helper"

describe "Semantic: reflection" do
  it "types Object class" do
    assert_type("Object") { types["Object"].metaclass }
  end

  it "types Class class" do
    assert_type("Class") { types["Class"] }
  end

  it "types Object and Class metaclasses" do
    assert_type("Object.class") { types["Class"] }
    assert_type("Class.class") { types["Class"] }
  end

  it "types Reference metaclass" do
    assert_type("Reference") { types["Reference"].metaclass }
    assert_type("Reference.class") { types["Class"] }
  end

  it "types metaclass parent" do
    input = parse("
      class Foo; end
      class Bar < Foo; end
    ")
    result = semantic input
    mod = result.program

    mod.types["Bar"].metaclass.as(ClassType).superclass.should eq(mod.types["Foo"].metaclass)
  end
end
