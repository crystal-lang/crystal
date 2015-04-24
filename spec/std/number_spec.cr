require "spec"

describe "Number" do
  describe "significant" do
    it "10 base " do
      expect(1234.567.significant(1)).to eq(1000)
      expect(1234.567.significant(2)).to eq(1200)
      expect(1234.567.significant(3)).to eq(1230)
      expect(1234.567.significant(4)).to eq(1235)
      expect(1234.567.significant(5)).to be_close(1234.6, 1e-7)
      expect(1234.567.significant(6)).to eq(1234.57)
      expect(1234.567.significant(7)).to eq(1234.567)
    end

    it "2 base " do
      expect(-1763.116.significant(2, base = 2)).to eq(-1536.0)
      expect(753.155.significant(3, base = 2)).to eq(768.0)
      expect(15.159.significant(1, base = 2)).to eq(16.0)
    end

    it "8 base " do
      expect(-1763.116.significant(2, base = 8)).to eq(-1792.0)
      expect(753.155.significant(3, base = 8)).to eq(752.0)
      expect(15.159.significant(1, base = 8)).to eq(16.0)
    end

    it "preserves type" do
      expect(123.significant(2)).to eq(120)
      expect(123.significant(2)).to be_a(Int32)
    end
  end

  describe "round" do
    it "10 base " do
      expect(-1763.116.round(2)).to eq(-1763.12)
      expect(753.155.round(2)).to eq(753.16)
      expect(15.151.round(2)).to eq(15.15)
    end

    it "2 base " do
      expect(-1763.116.round(2, base = 2)).to eq(-1763.0)
      expect(753.155.round(2, base = 2)).to eq(753.25)
      expect(15.159.round(2, base = 2)).to eq(15.25)
    end

    it "8 base " do
      expect(-1763.116.round(2, base = 8)).to eq(-1763.109375)
      expect(753.155.round(1, base = 8)).to eq(753.125)
      expect(15.159.round(0, base = 8)).to eq(15.0)
    end

    it "preserves type" do
      expect(123.round(2)).to eq(123)
      expect(123.round(2)).to be_a(Int32)
    end
  end

  it "creates an array with [] and some elements" do
    ary = Int64[1, 2, 3]
    expect(ary).to eq([1, 2, 3])
    expect(ary[0]).to be_a(Int64)
  end

  it "creates an array with [] and no elements" do
    ary = Int64[]
    expect(ary).to eq([] of Int64)
    ary << 1_i64
    expect(ary).to eq([1])
  end

  it "can use methods from Comparable" do
    expect(5.between?(0, 9)).to be_true
    expect(0.between?(5, 9)).to be_false

    expect(5_u64.between?(0_i8, 9_u16)).to be_true
    expect(0_i8.between?(5_u32, 9_i64)).to be_false

    expect(25641_i16.between?(594_i64, 487696874_u32)).to be_true
    expect(594_i64.between?(25641_i16, 487696874_u32)).to be_false
  end

  it "steps from int to float" do
    count = 0
    0.step(by: 0.1, limit: 0.3) do |x|
      expect(typeof(x)).to eq(typeof(0.1))
      case count
      when 0 then expect(x).to eq(0.0)
      when 1 then expect(x).to eq(0.1)
      when 2 then expect(x).to eq(0.2)
      end
      count += 1
    end
  end
end
