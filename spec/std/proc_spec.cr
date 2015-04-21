require "spec"

describe "Proc" do
  it "does to_s(io)" do
    str = StringIO.new
    f = ->(x : Int32) { x.to_f }
    f.to_s(str)
    expect(str.to_s).to eq("#<(Int32 -> Float64):0x#{f.pointer.address.to_s(16)}>")
  end

  it "does to_s(io) when closured" do
    str = StringIO.new
    a = 1.5
    f = ->(x : Int32) { x + a }
    f.to_s(str)
    expect(str.to_s).to eq("#<(Int32 -> Float64):0x#{f.pointer.address.to_s(16)}:closure>")
  end

  it "does to_s" do
    str = StringIO.new
    f = ->(x : Int32) { x.to_f }
    expect(f.to_s).to eq("#<(Int32 -> Float64):0x#{f.pointer.address.to_s(16)}>")
  end

  it "does to_s when closured" do
    str = StringIO.new
    a = 1.5
    f = ->(x : Int32) { x + a }
    expect(f.to_s).to eq("#<(Int32 -> Float64):0x#{f.pointer.address.to_s(16)}:closure>")
  end

  it "gets pointer" do
    f = ->{ 1 }
    expect(f.pointer.address).to be > 0
  end

  it "gets closure data for non-closure" do
    f = ->{ 1 }
    expect(f.closure_data.address).to eq(0)
    expect(f.closure?).to be_false
  end

  it "gets closure data for closure" do
    a = 1
    f = ->{ a }
    expect(f.closure_data.address).to be > 0
    expect(f.closure?).to be_true
  end

  it "does new" do
    a = 1
    f = ->(x : Int32){ x + a }
    f2 = Proc(Int32, Int32).new(f.pointer, f.closure_data)
    expect(f2.call(3)).to eq(4)
  end

  it "does ==" do
    func = ->{ 1 }
    expect(func).to eq(func)
    func2 = ->{ 1 }
    expect(func2).to_not eq(func)
  end
end
