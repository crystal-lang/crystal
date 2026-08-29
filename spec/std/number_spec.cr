require "spec"
require "big"
require "complex"
require "../support/number"

describe "Number" do
  {% for number_type in BUILTIN_NUMBER_TYPES %}
    it_unchecked_initializes_from_value_to {{ number_type }}
    it_initializes_from_value_to {{ number_type }}
  {% end %}

  it_can_convert_between({{ BUILTIN_NUMBER_TYPES }}, {{ BUILTIN_NUMBER_TYPES }})

  describe "significant" do
    it "10 base" do
      1234.567.significant(1).should eq(1000)
      1234.567.significant(2).should eq(1200)
      1234.567.significant(3).should eq(1230)
      1234.567.significant(4).should eq(1235)
      1234.567.significant(5).should be_close(1234.6, 1e-7)
      1234.567.significant(6).should eq(1234.57)
      1234.567.significant(7).should eq(1234.567)

      123.456789.significant(5).should eq(123.46)
      0.000123456789.significant(3).should eq 0.000123
      0.123456789.significant(4).should eq 0.1235
      1.23456789.significant(2).should eq 1.2
    end

    it "2 base" do
      -1763.116.significant(2, base: 2).should eq(-1536.0)
      753.155.significant(3, base: 2).should eq(768.0)
      15.159.significant(1, base: 2).should eq(16.0)
    end

    it "8 base" do
      -1763.116.significant(2, base: 8).should eq(-1792.0)
      753.155.significant(3, base: 8).should eq(752.0)
      15.159.significant(1, base: 8).should eq(16.0)
    end

    it "preserves type" do
      123.significant(2).should eq(120)
      123.significant(2).should be_a(Int32)
      0.significant(1).should be_a(Int32)
    end
  end

  describe "#round" do
    it "rounds to nearest integer" do
      5.5.round.should eq(6)
      0.4.round.should eq(0)
      -2.8.round.should eq(-3)
      0.0.round.should eq(0)
      0.49999999999999994.round.should eq(0)
      -1763.116.round.should eq(-1763)
      753.155.round.should eq(753)
      15.151.round.should eq(15)
    end

    it "infinity Float64" do
      Float64::INFINITY.round.should eq Float64::INFINITY
      Float64::INFINITY.round(digits: 0).should eq Float64::INFINITY
      Float64::INFINITY.round(digits: 3).should eq Float64::INFINITY
      Float64::INFINITY.round(digits: -3).should eq Float64::INFINITY
      (-Float64::INFINITY).round.should eq -Float64::INFINITY
      (-Float64::INFINITY).round(digits: 0).should eq -Float64::INFINITY
      (-Float64::INFINITY).round(digits: 3).should eq -Float64::INFINITY
      (-Float64::INFINITY).round(digits: -3).should eq -Float64::INFINITY
    end

    {% if compare_versions(Crystal::VERSION, "0.36.1") > 0 %}
      it "infinity Float32" do
        Float32::INFINITY.round.should eq Float32::INFINITY
        Float32::INFINITY.round(digits: 0).should eq Float32::INFINITY
        Float32::INFINITY.round(digits: 3).should eq Float32::INFINITY
        Float32::INFINITY.round(digits: -3).should eq Float32::INFINITY
        (-Float32::INFINITY).round.should eq -Float32::INFINITY
        (-Float32::INFINITY).round(digits: 0).should eq -Float32::INFINITY
        (-Float32::INFINITY).round(digits: 3).should eq -Float32::INFINITY
        (-Float32::INFINITY).round(digits: -3).should eq -Float32::INFINITY
      end
    {% else %}
      pending "infinity Float32"
    {% end %}

    it "nan" do
      Float64::NAN.round.nan?.should be_true
      Float32::NAN.round.nan?.should be_true
    end

    it "rounds to digits" do
      5.5.round(0).should eq(6)
      5.7.round(1).should eq(5.7)
      1.2345678.round(2).should eq(1.23)
      123456.78.round(-2).should eq(123500) # rounded up
      -123456.78.round(-2).should eq(-123500)

      -1763.116.round(2).should eq(-1763.12)
      753.155.round(2).should eq(753.16)
      15.151.round(2).should eq(15.15)

      0.8346268.round(-1).should eq(0)
    end

    it { 42.0.round(300).should eq(42.0) }

    pending "edge cases" do
      42.0.round(308).should eq(42.0)
      42.0.round(309).should eq(42.0)

      1.0e307.round(2).should eq(1.0e307)
      0.42.round(2**30).should eq(0.42)
    end

    it "preserves type" do
      1.round.should be_a(Int32)
      1_u8.round.should be_a(UInt8)
      1.0_f32.round.should be_a(Float32)
    end

    it "negative digits" do
      123.round(-2).should eq(100)
      123.round(-3).should eq(0)
      523.round(-3).should eq(1000)

      123.456.round(-2).should eq(100)
      123_456.123456.round(-5).should eq(100_000)
    end

    it "accepts unsigned precision" do
      123.round(UInt8.new(3)).should eq(123)
      11.308.round(UInt8.new(3)).should eq(11.308)
      11.308.round(UInt8.new(2)).should eq(11.31)
    end

    it "handle medium amount of digits" do
      1.098765432109876543210987654321.round(15).should eq(1.098765432109876)
      1.098765432109876543210987654321.round(21).should eq(1.098765432109876543211)
      6543210987654321.0.round(-15).should eq(7000000000000000.0)
    end

    describe "rounding modes" do
      it "to_zero" do
        -1.5.round(:to_zero).should eq -1.0
        -1.0.round(:to_zero).should eq -1.0
        -0.9.round(:to_zero).should eq 0.0
        -0.5.round(:to_zero).should eq 0.0
        -0.1.round(:to_zero).should eq 0.0
        0.0.round(:to_zero).should eq 0.0
        0.1.round(:to_zero).should eq 0.0
        0.5.round(:to_zero).should eq 0.0
        0.9.round(:to_zero).should eq 0.0
        1.0.round(:to_zero).should eq 1.0
        1.5.round(:to_zero).should eq 1.0
      end

      it "to_positive" do
        -1.5.round(:to_positive).should eq -1.0
        -1.0.round(:to_positive).should eq -1.0
        -0.9.round(:to_positive).should eq 0.0
        -0.5.round(:to_positive).should eq 0.0
        -0.1.round(:to_positive).should eq 0.0
        0.0.round(:to_positive).should eq 0.0
        0.1.round(:to_positive).should eq 1.0
        0.5.round(:to_positive).should eq 1.0
        0.9.round(:to_positive).should eq 1.0
        1.0.round(:to_positive).should eq 1.0
        1.5.round(:to_positive).should eq 2.0
      end

      it "to_negative" do
        -1.5.round(:to_negative).should eq -2.0
        -1.0.round(:to_negative).should eq -1.0
        -0.9.round(:to_negative).should eq -1.0
        -0.5.round(:to_negative).should eq -1.0
        -0.1.round(:to_negative).should eq -1.0
        0.0.round(:to_negative).should eq 0.0
        0.1.round(:to_negative).should eq 0.0
        0.5.round(:to_negative).should eq 0.0
        0.9.round(:to_negative).should eq 0.0
        1.0.round(:to_negative).should eq 1.0
        1.5.round(:to_negative).should eq 1.0
      end

      it "ties_even" do
        -2.5.round(:ties_even).should eq -2.0
        -1.5.round(:ties_even).should eq -2.0
        -1.0.round(:ties_even).should eq -1.0
        -0.9.round(:ties_even).should eq -1.0
        -0.5.round(:ties_even).should eq 0.0
        -0.1.round(:ties_even).should eq 0.0
        0.0.round(:ties_even).should eq 0.0
        0.1.round(:ties_even).should eq 0.0
        0.5.round(:ties_even).should eq 0.0
        0.9.round(:ties_even).should eq 1.0
        1.0.round(:ties_even).should eq 1.0
        1.5.round(:ties_even).should eq 2.0
        2.5.round(:ties_even).should eq 2.0
      end

      it "ties_away" do
        -2.5.round(:ties_away).should eq -3.0
        -1.5.round(:ties_away).should eq -2.0
        -1.0.round(:ties_away).should eq -1.0
        -0.9.round(:ties_away).should eq -1.0
        -0.5.round(:ties_away).should eq -1.0
        -0.1.round(:ties_away).should eq 0.0
        0.0.round(:ties_away).should eq 0.0
        0.1.round(:ties_away).should eq 0.0
        0.5.round(:ties_away).should eq 1.0
        0.9.round(:ties_away).should eq 1.0
        1.0.round(:ties_away).should eq 1.0
        1.5.round(:ties_away).should eq 2.0
        2.5.round(:ties_away).should eq 3.0
      end

      it "default (=ties_even)" do
        -2.5.round.should eq -2.0
        -1.5.round.should eq -2.0
        -1.0.round.should eq -1.0
        -0.9.round.should eq -1.0
        -0.5.round.should eq 0.0
        -0.1.round.should eq 0.0
        0.0.round.should eq 0.0
        0.1.round.should eq 0.0
        0.5.round.should eq 0.0
        0.9.round.should eq 1.0
        1.0.round.should eq 1.0
        1.5.round.should eq 2.0
        2.5.round.should eq 2.0
      end
    end

    describe "with digits" do
      it "to_zero" do
        12.345.round(-1, mode: :to_zero).should eq 10
        12.345.round(0, mode: :to_zero).should eq 12
        12.345.round(1, mode: :to_zero).should eq 12.3
        12.345.round(2, mode: :to_zero).should eq 12.34
        -12.345.round(-1, mode: :to_zero).should eq -10
        -12.345.round(0, mode: :to_zero).should eq -12
        -12.345.round(1, mode: :to_zero).should eq -12.3
        -12.345.round(2, mode: :to_zero).should eq -12.34
      end

      it "to_positive" do
        12.345.round(-1, mode: :to_positive).should eq 20
        12.345.round(0, mode: :to_positive).should eq 13
        12.345.round(1, mode: :to_positive).should eq 12.4
        12.345.round(2, mode: :to_positive).should eq 12.35
        -12.345.round(-1, mode: :to_positive).should eq -10
        -12.345.round(0, mode: :to_positive).should eq -12
        -12.345.round(1, mode: :to_positive).should eq -12.3
        -12.345.round(2, mode: :to_positive).should eq -12.34
      end

      it "to_negative" do
        12.345.round(-1, mode: :to_negative).should eq 10
        12.345.round(0, mode: :to_negative).should eq 12
        12.345.round(1, mode: :to_negative).should eq 12.3
        12.345.round(2, mode: :to_negative).should eq 12.34
        -12.345.round(-1, mode: :to_negative).should eq -20
        -12.345.round(0, mode: :to_negative).should eq -13
        -12.345.round(1, mode: :to_negative).should eq -12.4
        -12.345.round(2, mode: :to_negative).should eq -12.35
      end

      it "ties_away" do
        13.825.round(-1, mode: :ties_away).should eq 10
        13.825.round(0, mode: :ties_away).should eq 14
        13.825.round(1, mode: :ties_away).should eq 13.8
        13.825.round(2, mode: :ties_away).should eq 13.83
        -13.825.round(-1, mode: :ties_away).should eq -10
        -13.825.round(0, mode: :ties_away).should eq -14
        -13.825.round(1, mode: :ties_away).should eq -13.8
        -13.825.round(2, mode: :ties_away).should eq -13.83
      end

      it "ties_even" do
        15.255.round(-1, mode: :ties_even).should eq 20
        15.255.round(0, mode: :ties_even).should eq 15
        15.255.round(1, mode: :ties_even).should eq 15.3
        15.255.round(2, mode: :ties_even).should eq 15.26
        -15.255.round(-1, mode: :ties_even).should eq -20
        -15.255.round(0, mode: :ties_even).should eq -15
        -15.255.round(1, mode: :ties_even).should eq -15.3
        -15.255.round(2, mode: :ties_even).should eq -15.26
      end
    end

    describe "base" do
      it "2" do
        -1763.116.round(2, base: 2).should eq(-1763.0)
        753.155.round(2, base: 2).should eq(753.25)
        15.159.round(2, base: 2).should eq(15.25)
        753.155.round(-5, base: 2).should eq(768)
      end

      it "8" do
        -1763.116.round(2, base: 8).should eq(-1763.109375)
        753.155.round(1, base: 8).should eq(753.125)
        15.159.round(0, base: 8).should eq(15.0)
      end
    end
  end

  describe "#round_even" do
    it { -2.5.round_even.should eq -2.0 }
    it { -1.5.round_even.should eq -2.0 }
    it { -1.0.round_even.should eq -1.0 }
    it { -0.9.round_even.should eq -1.0 }
    it { -0.5.round_even.should eq -0.0 }
    it { -0.1.round_even.should eq 0.0 }
    it { 0.0.round_even.should eq 0.0 }
    it { 0.1.round_even.should eq 0.0 }
    it { 0.5.round_even.should eq 0.0 }
    it { 0.9.round_even.should eq 1.0 }
    it { 1.0.round_even.should eq 1.0 }
    it { 1.5.round_even.should eq 2.0 }
    it { 2.5.round_even.should eq 2.0 }

    it { 1.round_even.should eq 1 }
    it { 1.round_even.should be_a(Int32) }
    it { 1_u8.round_even.should be_a(UInt8) }
    it { 1_f32.round_even.should be_a(Float32) }
  end

  describe "#round_away" do
    it { -2.5.round_away.should eq -3.0 }
    it { -1.5.round_away.should eq -2.0 }
    it { -1.0.round_away.should eq -1.0 }
    it { -0.9.round_away.should eq -1.0 }
    it { -0.5.round_away.should eq -1.0 }
    it { -0.1.round_away.should eq 0.0 }
    it { 0.0.round_away.should eq 0.0 }
    it { 0.1.round_away.should eq 0.0 }
    it { 0.5.round_away.should eq 1.0 }
    it { 0.9.round_away.should eq 1.0 }
    it { 1.0.round_away.should eq 1.0 }
    it { 1.5.round_away.should eq 2.0 }
    it { 2.5.round_away.should eq 3.0 }

    it { 1.round_away.should eq 1 }
    it { 1.round_away.should be_a(Int32) }
    it { 1_u8.round_away.should be_a(UInt8) }
    it { 1_f32.round_away.should be_a(Float32) }
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

  it "divides and calculates the modulo" do
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
    slice[2].should eq(300.to_u8!)
  end

  it "creates a static array" do
    ary = Int8.static_array(1, 2, 300)
    ary.should be_a(StaticArray(Int8, 3))
    ary.size.should eq(3)
    ary[0].should eq(1)
    ary[1].should eq(2)
    ary[2].should eq(300.to_u8!)
  end

  it "#zero?" do
    0.zero?.should be_true
    0.0.zero?.should be_true
    0_f32.zero?.should be_true
    1.zero?.should be_false
    1.0.zero?.should be_false
    1f32.zero?.should be_false
  end

  it "#positive?" do
    1.positive?.should be_true
    1.0.positive?.should be_true
    0.positive?.should be_false
    0.0.positive?.should be_false
    -1.positive?.should be_false
    -1.1.positive?.should be_false
  end

  it "#negative?" do
    1.negative?.should be_false
    1.0.negative?.should be_false
    0.negative?.should be_false
    0.0.negative?.should be_false
    -1.negative?.should be_true
    -1.1.negative?.should be_true
  end

  describe "#step" do
    it_iterates "basic Int", [1, 2, 3, 4, 5], 1.step(to: 5)
    it_iterates "basic Float", [1.0, 2.0, 3.0, 4.0, 5.0], 1.0.step(to: 5.0)

    it_iterates "single value Int", [1], 1.step(to: 1)
    it_iterates "single value Float", [1.0], 1.0.step(to: 1.0)

    it_iterates "single value by Int", [1], 1.step(to: 1, by: 2)
    it_iterates "single value by Float", [1.0], 1.0.step(to: 1.0, by: 2.0)
    it_iterates "single value Int by Float", [1.0], 1.step(to: 1, by: 2.0)
    it_iterates "single value Float by Int", [1.0], 1.0.step(to: 1.0, by: 2)

    it_iterates "negative Int", [-1, -2, -3, -4, -5], -1.step(to: -5)
    it_iterates "negative Float", [-1.0, -2.0, -3.0, -4.0, -5.0], -1.0.step(to: -5.0)

    it_iterates "downto Int", [3, 2, 1, 0], 3.step(to: 0)
    it_iterates "downto Int by", [3, 2, 1, 0], 3.step(to: 0, by: -1)
    it_iterates "downto UInt", [3, 2, 1, 0] of UInt8, 3u8.step(to: 0)
    it_iterates "downto UInt by", [3, 2, 1, 0] of UInt8, 3u8.step(to: 0, by: -1)
    it_iterates "downto Float", [3.0, 2.0, 1.0, 0.0], 3.0.step(to: 0)
    it_iterates "downto Float by", [3.0, 2.0, 1.0, 0.0], 3.0.step(to: 0, by: -1)

    it_iterates "by Int", [1, 3, 5], 1.step(to: 5, by: 2)
    it_iterates "by Float", [1.0, 3.0, 5.0], 1.0.step(to: 5.0, by: 2.0)
    it_iterates "by Float half", [1.0, 2.5, 4.0], 1.0.step(to: 5.0, by: 1.5)

    it_iterates "negative by Int", [-1, -3, -5], -1.step(to: -5, by: -2)
    it_iterates "negative by Float", [-1.0, -3.0, -5.0], -1.0.step(to: -5.0, by: -2.0)
    it_iterates "negative by Float half", [-1.0, -2.5, -4.0], -1.0.step(to: -5.0, by: -1.5)

    it_iterates "missing end Int", [1, 3], 1.step(to: 4, by: 2)
    it_iterates "missing end Float", [1.0, 3.0], 1.0.step(to: 4.0, by: 2.0)
    it_iterates "missing end UInt", [3, 1] of UInt8, 3u8.step(to: 0, by: -2)

    it_iterates "Int to Float", [1, 2, 3, 4, 5], 1.step(to: 5.0)
    it_iterates "Int to Float by", [1, 2, 3, 4, 5], 1.step(to: 5.0, by: 1)
    it_iterates "Float to Int", [1.0, 2.0, 3.0, 4.0, 5.0], 1.0.step(to: 5)
    it_iterates "Float to Int by", [1.0, 2.0, 3.0, 4.0, 5.0], 1.0.step(to: 5, by: 1)

    it_iterates "Int by Float", [1.0, 3.0, 5.0], 1.step(to: 5, by: 2.0)
    it_iterates "Float by Int", [1.0, 3.0, 5.0], 1.0.step(to: 5.0, by: 2)

    it_iterates "over zero Int", [-1, 0, 1], -1.step(to: 1)
    it_iterates "over zero Float", [-1.0, 0.0, 1.0], -1.0.step(to: 1.0)

    it_iterates "at max Int", [Int8::MAX - 2, Int8::MAX - 1, Int8::MAX], (Int8::MAX - 2).step(to: Int8::MAX)
    it_iterates "over max Int", [Int8::MAX - 1], (Int8::MAX - 1).step(to: Int8::MAX, by: 2)

    it_iterates "at min Int", [Int8::MIN + 2, Int8::MIN + 1, Int8::MIN], (Int8::MIN + 2).step(to: Int8::MIN)
    it_iterates "over min Int", [Int8::MIN + 1], (Int8::MIN + 1).step(to: Int8::MIN, by: -2)

    it "by zero yielding" do
      yielded = false
      expect_raises(ArgumentError, "Zero step size") do
        0.step(to: 1, by: 0) { yielded = true }
      end
      yielded.should be_false
    end

    it "by zero iterator" do
      expect_raises(ArgumentError, "Zero step size") do
        0.step(to: 1, by: 0)
      end
    end

    it_iterates "empty if `by` and `to` are opposed", [] of Int32, 1.step(to: 2, by: -1)

    it_iterates "empty if `to` can't be compared", [] of Float64, 1.0.step(to: Float64::NAN)
    it_iterates "empty if `to` can't be compared by", [] of Float64, 1.0.step(to: Float64::NAN, by: 1.0)
    it_iterates "empty if `self` can't be compared", [] of Float64, Float64::NAN.step(to: 1.0)
    it_iterates "empty if `self` can't be compared by", [] of Float64, Float64::NAN.step(to: 1.0, by: 1.0)

    describe "exclusive" do
      it_iterates "basic Int", [1, 2, 3, 4], 1.step(to: 5, exclusive: true)
      it_iterates "basic Float", [1.0, 2.0, 3.0, 4.0], 1.0.step(to: 5.0, exclusive: true)

      it_iterates "single value Int", [] of Int32, 1.step(to: 1, exclusive: true)
      it_iterates "single value Float", [] of Float64, 1.0.step(to: 1.0, exclusive: true)
    end

    describe "without limit" do
      describe "iterator" do
        it "basic" do
          iter = 0.step

          5.times do
            iter.next
          end

          iter.next.should eq(5)
        end

        it "raises overflow error" do
          iter = (Int8::MAX - 1).step
          iter.next.should eq Int8::MAX - 1
          iter.next.should eq Int8::MAX
          expect_raises(OverflowError) do
            iter.next
          end
        end
      end

      describe "yielding" do
        it "basic" do
          i = 1
          1.step do |x|
            x.should eq(i)
            break if x >= 10
            i += 1
          end
          i.should eq 10
        end

        it "raises overflow error" do
          ary = [] of Int8
          expect_raises(OverflowError) do
            (Int8::MAX - 1).step do |x|
              ary << x
            end
          end
          ary.should eq [Int8::MAX - 1, Int8::MAX]
        end
      end
    end

    describe "whole range" do
      it { (UInt8::MIN..UInt8::MAX).each.count { true }.should eq(256) }
      it_iterates "UInt8 upwards", (UInt8::MIN.to_i..UInt8::MAX.to_i).map(&.to_u8), (UInt8::MIN..UInt8::MAX).step(by: 1)
      it_iterates "UInt8 downwards", (UInt8::MIN.to_i..UInt8::MAX.to_i).map(&.to_u8).reverse!, (UInt8::MAX..UInt8::MIN).step(by: -1)

      it { (Int8::MIN..Int8::MAX).each.count { true }.should eq(256) }
      it_iterates "Int8 upwards", (Int8::MIN.to_i..Int8::MAX.to_i).map(&.to_i8), (Int8::MIN..Int8::MAX).step(by: 1)
      it_iterates "Int8 downwards", (Int8::MIN.to_i..Int8::MAX.to_i).map(&.to_i8).reverse!, (Int8::MAX..Int8::MIN).step(by: -1)

      it { (Int16::MIN..Int16::MAX).each.count { true }.should eq(65536) }
      it_iterates "Int16 upwards", (Int16::MIN.to_i..Int16::MAX.to_i).map(&.to_i16), (Int16::MIN..Int16::MAX).step(by: 1)
      it_iterates "Int16 downwards", (Int16::MIN.to_i..Int16::MAX.to_i).map(&.to_i16).reverse!, (Int16::MAX..Int16::MIN).step(by: -1)
    end

    it_iterates "towards limit [max-4, max-2, max]", [Int32::MAX - 4, Int32::MAX - 2, Int32::MAX], (Int32::MAX - 4).step(to: Int32::MAX, by: 2)
    it_iterates "towards limit [max-4, max-2, max)", [Int32::MAX - 4, Int32::MAX - 2], (Int32::MAX - 4).step(to: Int32::MAX, by: 2, exclusive: true)
    it_iterates "towards limit [max-3, max-1, max)", [Int32::MAX - 3, Int32::MAX - 1], (Int32::MAX - 3).step(to: Int32::MAX, by: 2)
  end

  floor_division_returns_lhs_type {{ BUILTIN_NUMBER_TYPES }}, {{ BUILTIN_NUMBER_TYPES }}

  division_between_returns {{ BUILTIN_INTEGER_TYPES }}, {{ BUILTIN_INTEGER_TYPES }}, Float64
  division_between_returns {{ BUILTIN_INTEGER_TYPES }}, [Float32], Float32
  division_between_returns [Float32], {{ BUILTIN_INTEGER_TYPES }}, Float32
  division_between_returns {{ BUILTIN_INTEGER_TYPES }}, [Float64], Float64
  division_between_returns [Float64], {{ BUILTIN_INTEGER_TYPES }}, Float64

  division_between_returns [Float32], [Float32], Float32
  division_between_returns {{ BUILTIN_FLOAT_TYPES }}, [Float64], Float64
  division_between_returns [Float64], {{ BUILTIN_FLOAT_TYPES }}, Float64
end
