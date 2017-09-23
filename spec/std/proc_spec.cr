require "spec"

describe "Proc" do
  it "does to_s(io)" do
    str = IO::Memory.new
    f = ->(x : Int32) { x.to_f }
    f.to_s(str)
    str.to_s.should eq("#<Proc(Int32, Float64):0x#{f.pointer.address.to_s(16)}>")
  end

  it "does to_s(io) when closured" do
    str = IO::Memory.new
    a = 1.5
    f = ->(x : Int32) { x + a }
    f.to_s(str)
    str.to_s.should eq("#<Proc(Int32, Float64):0x#{f.pointer.address.to_s(16)}:closure>")
  end

  it "does to_s" do
    str = IO::Memory.new
    f = ->(x : Int32) { x.to_f }
    f.to_s.should eq("#<Proc(Int32, Float64):0x#{f.pointer.address.to_s(16)}>")
  end

  it "does to_s when closured" do
    str = IO::Memory.new
    a = 1.5
    f = ->(x : Int32) { x + a }
    f.to_s.should eq("#<Proc(Int32, Float64):0x#{f.pointer.address.to_s(16)}:closure>")
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
    f = ->(x : Int32) { x + a }
    f2 = Proc(Int32, Int32).new(f.pointer, f.closure_data)
    f2.call(3).should eq(4)
  end

  it "does ==" do
    func = ->{ 1 }
    func.should eq(func)
    func2 = ->{ 1 }
    func2.should_not eq(func)
  end

  it "clones" do
    func = ->{ 1 }
    func.clone.should eq(func)
  end

  it "#arity" do
    f = ->(x : Int32, y : Int32) {}
    f.arity.should eq(2)
  end

  it "#partial" do
    f = ->(x : Int32, y : Int32, z : Int32) { x + y + z }
    f.call(1, 2, 3).should eq(6)

    f2 = f.partial(10)
    f2.call(2, 3).should eq(15)
    f2.call(2, 10).should eq(22)

    f3 = f2.partial(20)
    f3.call(3).should eq(33)
    f3.call(10).should eq(40)

    f = ->(x : String, y : Char) { x.index(y) }
    f.call("foo", 'o').should eq(1)

    f2 = f.partial("bar")
    f2.call('a').should eq(1)
    f2.call('r').should eq(2)
  end

  typeof(->{ 1 }.hash)
end
