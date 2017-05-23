require "spec"

private module RecordSpec
  record Record1,
    x : Int32,
    y : Array(Int32)

  record Record2,
    x : Int32 = 0,
    y : Array(Int32) = [2, 3]

  record Record3,
    x = 0,
    y = [2, 3]
end

describe "record" do
  it "defines record with type declarations" do
    ary = [2, 3]
    rec = RecordSpec::Record1.new(1, ary)
    rec.x.should eq(1)
    rec.y.should be(ary)

    cloned = rec.clone
    cloned.x.should eq(1)
    cloned.y.should eq(ary)
    cloned.y.should_not be(ary)
  end

  it "defines record with type declaration and initialization" do
    rec = RecordSpec::Record2.new
    rec.x.should eq(0)
    rec.y.should eq([2, 3])

    cloned = rec.clone
    cloned.x.should eq(0)
    cloned.y.should eq(rec.y)
    cloned.y.should_not be(rec.y)
  end

  it "defines record with assignments" do
    rec = RecordSpec::Record3.new
    rec.x.should eq(0)
    rec.y.should eq([2, 3])

    cloned = rec.clone
    cloned.x.should eq(0)
    cloned.y.should eq(rec.y)
    cloned.y.should_not be(rec.y)
  end
end
