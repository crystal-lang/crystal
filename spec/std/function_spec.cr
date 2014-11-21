require "spec"

describe "Function" do
  it "does to_s(io)" do
    str = StringIO.new
    f = ->(x : Int32) { x.to_f }
    f.to_s(str)
    str.to_s.should eq("#<(Int32 -> Float64):0x#{f.pointer.address.to_s(16)}>")
  end

  it "does to_s(io) when closured" do
    str = StringIO.new
    a = 1.5
    f = ->(x : Int32) { x + a }
    f.to_s(str)
    str.to_s.should eq("#<(Int32 -> Float64):0x#{f.pointer.address.to_s(16)}:closure>")
  end

  it "does to_s" do
    str = StringIO.new
    f = ->(x : Int32) { x.to_f }
    f.to_s.should eq("#<(Int32 -> Float64):0x#{f.pointer.address.to_s(16)}>")
  end

  it "does to_s when closured" do
    str = StringIO.new
    a = 1.5
    f = ->(x : Int32) { x + a }
    f.to_s.should eq("#<(Int32 -> Float64):0x#{f.pointer.address.to_s(16)}:closure>")
  end
end
