require "spec"

describe "Box" do
  it "boxes and unboxes" do
    a = 1
    box = Box.box(a)
    expect(Box(Int32).unbox(box)).to eq(1)
  end
end
