require "spec"

describe "Box" do
  it "boxes and unboxes" do
    a = 1
    box = Box.box(a)
    Box(Int32).unbox(box).should eq(1)
  end
end
