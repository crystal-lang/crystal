require "spec"

describe "Number" do
  describe "significant" do
    it "10 base " do
      1234.567.significant(1).should eq(1000)
      1234.567.significant(2).should eq(1200)
      1234.567.significant(3).should eq(1230)
      1234.567.significant(4).should eq(1235)
      1234.567.significant(5).should be_close(1234.6, 1e-7)
      1234.567.significant(6).should eq(1234.57)
      1234.567.significant(7).should eq(1234.567)
    end

    it "2 base " do
      -1763.116.significant(2, base = 2).should eq(-1536.0)
      753.155.significant(3, base = 2).should eq(768.0)
      15.159.significant(1, base = 2).should eq(16.0)
    end

    it "8 base " do
      -1763.116.significant(2, base = 8).should eq(-1792.0)
      753.155.significant(3, base = 8).should eq(752.0)
      15.159.significant(1, base = 8).should eq(16.0)
    end

    it "preserves type" do
      123.significant(2).should eq(120)
      123.significant(2).should be_a(Int32)
    end
  end

  describe "round" do
    it "10 base " do
      -1763.116.round(2).should eq(-1763.12)
      753.155.round(2).should eq(753.16)
      15.151.round(2).should eq(15.15)
    end

    it "2 base " do
      -1763.116.round(2, base = 2).should eq(-1763.0)
      753.155.round(2, base = 2).should eq(753.25)
      15.159.round(2, base = 2).should eq(15.25)
    end

    it "8 base " do
      -1763.116.round(2, base = 8).should eq(-1763.109375)
      753.155.round(1, base = 8).should eq(753.125)
      15.159.round(0, base = 8).should eq(15.0)
    end

    it "preserves type" do
      123.round(2).should eq(123)
      123.round(2).should be_a(Int32)
    end
  end

  it "creates an array with [] and some elements" do
    ary = Int64[1, 2, 3]
    ary.should eq([1, 2, 3])
    ary[0].should be_a(Int64)
  end

  it "creates an array with [] and no elements" do
    ary = Int64[]
    ary.should eq([] of Int64)
    ary << 1_i64
    ary.should eq([1])
  end

  it "can use methods from Comparable" do
    5.between?(0, 9).should be_true
    0.between?(5, 9).should be_false

    5_u64.between?(0_i8, 9_u16).should be_true
    0_i8.between?(5_u32, 9_i64).should be_false

    25641_i16.between?(594_i64, 487696874_u32).should be_true
    594_i64.between?(25641_i16, 487696874_u32).should be_false
  end

  it "steps from int to float" do
    count = 0
    0.step(by: 0.1, limit: 0.3) do |x|
      typeof(x).should eq(typeof(0.1))
      case count
      when 0 then x.should eq(0.0)
      when 1 then x.should eq(0.1)
      when 2 then x.should eq(0.2)
      end
      count += 1
    end
  end

  it "does step iterator" do
    iter = 0.step(by: 0.1, limit: 0.3)
    iter.next.should eq(0.0)
    iter.next.should eq(0.1)
    iter.next.should eq(0.2)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(0.0)
  end
end
