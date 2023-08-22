require "spec"

describe "Box" do
  it "boxes and unboxes" do
    a = 1
    box = Box.box(a)
    Box(Int32).unbox(box).should eq(1)
  end

  it "boxing a reference returns the same pointer" do
    a = "foo"
    box = Box.box(a)
    box.address.should eq(a.object_id)

    Box(String).unbox(box).should be(a)
  end

  it "boxing nil returns a null pointer" do
    box = Box.box(nil)
    box.address.should eq(0)

    Box(Nil).unbox(box).should be_nil
  end
end
