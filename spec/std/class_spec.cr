require "spec"

private class A
end

private class B1 < A
end

private class C1 < B1
end

private class B2 < A
end

private class ClassWithRedefinedName
  def self.name
    "OtherName"
  end
end

private alias RecursiveNilableType = Array(RecursiveNilableType)?

describe Class do
  it "does ===" do
    (Int32 === 1).should be_true
    (Int32 === 1.5).should be_false
    (Array === [1]).should be_true
    (Array(Int32) === [1]).should be_true
    (Array(Int32) === ['a']).should be_false
  end

  it "casts, allowing the class to be passed in at runtime" do
    ar = [99, "something"]
    cl = {Int32, String}
    casted = {cl[0].cast(ar[0]), cl[1].cast(ar[1])}
    casted.should eq({99, "something"})
    typeof(casted[0]).should eq(Int32)
    typeof(casted[1]).should eq(String)
  end

  it "does |" do
    (Int32 | Char).should eq(typeof(1, 'a'))
    (Int32 | Char | Float64).should eq(typeof(1, 'a', 1.0))
  end

  it "dups" do
    Int32.dup.should eq(Int32)
  end

  it "clones" do
    Int32.clone.should eq(Int32)
  end

  it "#nilable?" do
    Int32.nilable?.should be_false
    Nil.nilable?.should be_true
    (Int32 | String).nilable?.should be_false
    Int32?.nilable?.should be_true
    NoReturn.nilable?.should be_false
    Reference.nilable?.should be_false
    Value.nilable?.should be_true
    Class.nilable?.should be_false
    Object.nilable?.should be_true
    RecursiveNilableType.nilable?.should be_true
  end

  it "does to_s" do
    Int32.to_s.should eq("Int32")
  end

  it "does to_s with name redefined (#7292)" do
    ClassWithRedefinedName.name.should eq("OtherName")
    ClassWithRedefinedName.to_s.should eq("ClassWithRedefinedName")
  end

  describe "comparison operators" do
    t = [A, B1, B2, C1]

    it "<" do
      (t[0] < t[0]).should be_false
      (t[0] < t[1]).should be_false
      (t[0] < t[2]).should be_false
      (t[0] < t[3]).should be_false

      (t[1] < t[0]).should be_true
      (t[1] < t[1]).should be_false
      (t[1] < t[2]).should be_false
      (t[1] < t[3]).should be_false

      (t[2] < t[0]).should be_true
      (t[2] < t[1]).should be_false
      (t[2] < t[2]).should be_false
      (t[2] < t[3]).should be_false

      (t[3] < t[0]).should be_true
      (t[3] < t[1]).should be_true
      (t[3] < t[2]).should be_false
      (t[3] < t[3]).should be_false
    end

    it "<=" do
      (t[0] <= t[0]).should be_true
      (t[0] <= t[1]).should be_false
      (t[0] <= t[2]).should be_false
      (t[0] <= t[3]).should be_false

      (t[1] <= t[0]).should be_true
      (t[1] <= t[1]).should be_true
      (t[1] <= t[2]).should be_false
      (t[1] <= t[3]).should be_false

      (t[2] <= t[0]).should be_true
      (t[2] <= t[1]).should be_false
      (t[2] <= t[2]).should be_true
      (t[2] <= t[3]).should be_false

      (t[3] <= t[0]).should be_true
      (t[3] <= t[1]).should be_true
      (t[3] <= t[2]).should be_false
      (t[3] <= t[3]).should be_true
    end

    it ">" do
      (t[0] > t[0]).should be_false
      (t[0] > t[1]).should be_true
      (t[0] > t[2]).should be_true
      (t[0] > t[3]).should be_true

      (t[1] > t[0]).should be_false
      (t[1] > t[1]).should be_false
      (t[1] > t[2]).should be_false
      (t[1] > t[3]).should be_true

      (t[2] > t[0]).should be_false
      (t[2] > t[1]).should be_false
      (t[2] > t[2]).should be_false
      (t[2] > t[3]).should be_false

      (t[3] > t[0]).should be_false
      (t[3] > t[1]).should be_false
      (t[3] > t[2]).should be_false
      (t[3] > t[3]).should be_false
    end

    it ">=" do
      (t[0] >= t[0]).should be_true
      (t[0] >= t[1]).should be_true
      (t[0] >= t[2]).should be_true
      (t[0] >= t[3]).should be_true

      (t[1] >= t[0]).should be_false
      (t[1] >= t[1]).should be_true
      (t[1] >= t[2]).should be_false
      (t[1] >= t[3]).should be_true

      (t[2] >= t[0]).should be_false
      (t[2] >= t[1]).should be_false
      (t[2] >= t[2]).should be_true
      (t[2] >= t[3]).should be_false

      (t[3] >= t[0]).should be_false
      (t[3] >= t[1]).should be_false
      (t[3] >= t[2]).should be_false
      (t[3] >= t[3]).should be_true
    end
  end
end
