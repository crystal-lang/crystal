require "spec"

describe Class, "#===" do
  it "does ===" do
    (Int32 === 1).should be_true
    (Int32 === 1.5).should be_false
    (Array === [1]).should be_true
    (Array(Int32) === [1]).should be_true
    (Array(Int32) === ['a']).should be_false
  end
end

describe Class, ".cast" do
  it "casts, allowing the class to be passed in at runtime" do
    ar = [99, "something"]
    cl = {Int32, String}
    casted = {cl[0].cast(ar[0]), cl[1].cast(ar[1])}
    casted.should eq({99, "something"})
    typeof(casted[0]).should eq(Int32)
    typeof(casted[1]).should eq(String)
  end
end
