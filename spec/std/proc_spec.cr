require "spec"

describe "Proc" do
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

  it "gets pointer" do
    f = ->{ 1 }
    f.pointer.address.should be > 0
  end

  it "gets closure data for non-closure" do
    f = ->{ 1 }
    f.closure_data.address.should eq(0)
    f.closure?.should be_false
  end

  it "gets closure data for closure" do
    a = 1
    f = ->{ a }
    f.closure_data.address.should be > 0
    f.closure?.should be_true
  end

  it "does new" do
    a = 1
    f = ->(x : Int32){ x + a }
    f2 = Proc(Int32, Int32).new(f.pointer, f.closure_data)
    f2.call(3).should eq(4)
  end

  it "does ==" do
    func = ->{ 1 }
    func.should eq(func)
    func2 = ->{ 1 }
    func2.should_not eq(func)
  end
end
