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

private abstract struct Base
end

private record Sub < Base, x : Int32

private record CustomInitializer, id : Int32, active : Bool = false do
  def initialize(*, __id id : Int32)
    @id = id
  end
end

describe "record" do
  it "defines record with type declarations" do
    ary = [2, 3]
    rec = RecordSpec::Record1.new(1, ary)
    rec.x.should eq(1)
    rec.y.should be(ary)

    copy = rec.copy_with(x: 5)
    copy.x.should eq(5)
    copy.y.should be(rec.y)

    cloned = rec.clone
    cloned.x.should eq(1)
    cloned.y.should eq(ary)
    cloned.y.should_not be(ary)
  end

  it "defines record with type declaration and initialization" do
    rec = RecordSpec::Record2.new
    rec.x.should eq(0)
    rec.y.should eq([2, 3])

    copy = rec.copy_with(y: [7, 8])
    copy.x.should eq(rec.x)
    copy.y.should eq([7, 8])

    cloned = rec.clone
    cloned.x.should eq(0)
    cloned.y.should eq(rec.y)
    cloned.y.should_not be(rec.y)
  end

  it "defines record with assignments" do
    rec = RecordSpec::Record3.new
    rec.x.should eq(0)
    rec.y.should eq([2, 3])

    copy = rec.copy_with(y: [7, 8])
    copy.x.should eq(rec.x)
    copy.y.should eq([7, 8])

    cloned = rec.clone
    cloned.x.should eq(0)
    cloned.y.should eq(rec.y)
    cloned.y.should_not be(rec.y)
  end

  it "can clone record with parent type" do
    rec = Sub.new 1
    rec.clone.x.should eq(1)
  end

  it "can copy_with record with parent type" do
    rec = Sub.new 1
    rec.copy_with(x: 2).x.should eq(2)
  end

  it "uses the default values on the ivars" do
    CustomInitializer.new(__id: 10).active.should be_false
  end
end
