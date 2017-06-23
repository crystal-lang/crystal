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
      -1763.116.significant(2, base: 2).should eq(-1536.0)
      753.155.significant(3, base: 2).should eq(768.0)
      15.159.significant(1, base: 2).should eq(16.0)
    end

    it "8 base " do
      -1763.116.significant(2, base: 8).should eq(-1792.0)
      753.155.significant(3, base: 8).should eq(752.0)
      15.159.significant(1, base: 8).should eq(16.0)
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
      -1763.116.round(2, base: 2).should eq(-1763.0)
      753.155.round(2, base: 2).should eq(753.25)
      15.159.round(2, base: 2).should eq(15.25)
    end

    it "8 base " do
      -1763.116.round(2, base: 8).should eq(-1763.109375)
      753.155.round(1, base: 8).should eq(753.125)
      15.159.round(0, base: 8).should eq(15.0)
    end

    it "preserves type" do
      123.round(2).should eq(123)
      123.round(2).should be_a(Int32)
    end

    it "accepts negative precision" do
      123.round(-2).should eq(100)
      123.round(-3).should eq(0)
      523.round(-3).should eq(1000)

      123.456.round(-2).should eq(100)
      123_456.123456.round(-5).should eq(100_000)
      753.155.round(-5, base: 2).should eq(768)
    end
  end

  describe "clamp" do
    it "clamps integers" do
      -5.clamp(-10, 100).should eq(-5)
      -5.clamp(10, 100).should eq(10)
      5.clamp(10, 100).should eq(10)
      50.clamp(10, 100).should eq(50)
      500.clamp(10, 100).should eq(100)

      50.clamp(10..100).should eq(50)
    end

    it "clamps floats" do
      -5.5.clamp(-10.1, 100.1).should eq(-5.5)
      -5.5.clamp(10.1, 100.1).should eq(10.1)
      5.5.clamp(10.1, 100.1).should eq(10.1)
      50.5.clamp(10.1, 100.1).should eq(50.5)
      500.5.clamp(10.1, 100.1).should eq(100.1)

      50.5.clamp(10.1..100.1).should eq(50.5)
    end

    it "fails with an exclusive range" do
      expect_raises(ArgumentError) do
        range = Range.new(1, 2, exclusive: true)
        5.clamp(range)
      end
    end
  end

  it "gives the absolute value" do
    123.abs.should eq(123)
    -123.abs.should eq(123)
  end

  it "gives the square of a value" do
    2.abs2.should eq(4)
    -2.abs2.should eq(4)
    2.5.abs2.should eq(6.25)
    -2.5.abs2.should eq(6.25)
  end

  it "gives the sign" do
    123.sign.should eq(1)
    -123.sign.should eq(-1)
    0.sign.should eq(0)
  end

  it "divides and calculs the modulo" do
    11.divmod(3).should eq({3, 2})
    11.divmod(-3).should eq({-4, -1})

    10.divmod(2).should eq({5, 0})
    11.divmod(2).should eq({5, 1})

    10.divmod(-2).should eq({-5, 0})
    11.divmod(-2).should eq({-6, -1})

    -10.divmod(2).should eq({-5, 0})
    -11.divmod(2).should eq({-6, 1})

    -10.divmod(-2).should eq({5, 0})
    -11.divmod(-2).should eq({5, -1})
  end

  it "compare the numbers" do
    10.<=>(10).should eq(0)
    10.<=>(11).should eq(-1)
    11.<=>(10).should eq(1)
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

  it "creates a slice" do
    slice = Int8.slice(1, 2, 300)
    slice.should be_a(Slice(Int8))
    slice.size.should eq(3)
    slice[0].should eq(1)
    slice[1].should eq(2)
    slice[2].should eq(300.to_u8)
  end

  it "creates a static array" do
    ary = Int8.static_array(1, 2, 300)
    ary.should be_a(StaticArray(Int8, 3))
    ary.size.should eq(3)
    ary[0].should eq(1)
    ary[1].should eq(2)
    ary[2].should eq(300.to_u8)
  end

  it "test zero?" do
    0.zero?.should eq true
    0.0.zero?.should eq true
    0f32.zero?.should eq true
    1.zero?.should eq false
    1.0.zero?.should eq false
    1f32.zero?.should eq false
  end

  describe "step" do
    it "from int to float" do
      count = 0
      0.step(by: 0.1, to: 0.3) do |x|
        typeof(x).should eq(typeof(0.1))
        case count
        when 0 then x.should eq(0.0)
        when 1 then x.should eq(0.1)
        when 2 then x.should eq(0.2)
        end
        count += 1
      end
    end

    it "iterator" do
      iter = 0.step(by: 0.1, to: 0.3)
      iter.next.should eq(0.0)
      iter.next.should eq(0.1)
      iter.next.should eq(0.2)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(0.0)
    end

    it "iterator without limit" do
      iter = 0.step

      1000.times do
        iter.next
      end

      iter.next.should eq(1000)
    end
  end
end
