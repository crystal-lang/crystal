require "spec"

class TupleSpecObj
  getter x

  def initialize(@x)
  end

  def clone
    TupleSpecObj.new(@x)
  end
end

describe "Tuple" do
  it "does length" do
    expect({1, 2, 1, 2}.length).to eq(4)
  end

  it "does []" do
    a = {1, 2.5}
    i = 0
    expect(a[i]).to eq(1)
    i = 1
    expect(a[i]).to eq(2.5)
  end

  it "does [] raises index out of bounds" do
    a = {1, 2.5}
    i = 2
    expect_raises(IndexOutOfBounds) { a[i] }
    i = -1
    expect_raises(IndexOutOfBounds) { a[i] }
  end

  it "does []?" do
    a = {1, 2}
    expect(a[1]?).to eq(2)
    expect(a[2]?).to be_nil
  end

  it "does at" do
    a = {1, 2}
    expect(a.at(1)).to eq(2)

    expect_raises(IndexOutOfBounds) { a.at(2) }

    expect(a.at(2) { 3 }).to eq(3)
  end

  it "does ==" do
    a = {1, 2}
    b = {3, 4}
    c = {1, 2, 3}
    d = {1}
    e = {1, 2}
    expect(a).to eq(a)
    expect(a).to eq(e)
    expect(a).to_not eq(b)
    expect(a).to_not eq(c)
    expect(a).to_not eq(d)
  end

  it "does == with differnt types but same length" do
    expect({1, 2}).to eq({1.0, 2.0})
  end

  it "does == with another type" do
    expect({1, 2}).to_not eq(1)
  end

  it "does compare" do
    a = {1, 2}
    b = {3, 4}
    c = {1, 6}
    d = {3, 5}
    e = {0, 8}
    expect([a, b, c, d, e].sort).to eq([e, a, c, b, d])
    expect([a, b, c, d, e].min).to eq(e)
  end

  it "does compare with different lengths" do
    a = {2}
    b = {1, 2, 3}
    c = {1, 2}
    d = {1, 1}
    e = {1, 1, 3}
    expect([a, b, c, d, e].sort).to eq([d, e, c, b, a])
    expect([a, b, c, d, e].min).to eq(d)
  end

  it "does to_s" do
    expect({1, 2, 3}.to_s).to eq("{1, 2, 3}")
  end

  it "does each" do
    a = 0
    {1, 2, 3}.each do |i|
      a += i
    end
    expect(a).to eq(6)
  end

  it "does dup" do
    r1, r2 = TupleSpecObj.new(10), TupleSpecObj.new(20)
    t = {r1, r2}
    u = t.dup
    expect(u.length).to eq(2)
    expect(u[0]).to be(r1)
    expect(u[1]).to be(r2)
  end

  it "does clone" do
    r1, r2 = TupleSpecObj.new(10), TupleSpecObj.new(20)
    t = {r1, r2}
    u = t.clone
    expect(u.length).to eq(2)
    expect(u[0].x).to eq(r1.x)
    expect(u[0]).to_not be(r1)
    expect(u[1].x).to eq(r2.x)
    expect(u[1]).to_not be(r2)
  end

  it "does Tuple#new" do
    expect(Tuple.new(1, 2, 3)).to eq({1, 2, 3})
  end

  it "clones empty tuple" do
    expect(Tuple.new.clone).to eq(Tuple.new)
  end
end
