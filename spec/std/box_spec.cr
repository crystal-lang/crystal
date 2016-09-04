require "spec"

describe "Box" do
  it "boxes and unboxes" do
    a = 1
    box = Box.box(a)
    Box(Int32).unbox(box).should eq(1)
  end

  it "boxed and unboxed" do
    a = 1
    box = Box(Int32).new(a)
    Box(Int32).unbox(box.box).should eq(1)
  end
end
