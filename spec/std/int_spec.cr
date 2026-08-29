require "./spec_helper"
require "big"
require "spec/helpers/iterate"
require "../support/number"

private macro it_converts_to_s(num, str, **opts)
  it {{ "converts #{num} to #{str}" }} do
    num = {{ num }}
    str = {{ str }}
    num.to_s({{ opts.double_splat }}).should eq(str)
    String.build { |io| num.to_s(io, {{ opts.double_splat }}) }.should eq(str)
  end
end

private class IntEnumerable
  include Enumerable(Int32)

  def initialize(@elements : Array(Int32))
  end

  def each(&)
    @elements.each do |e|
      yield e
    end
  end
end

describe "Int" do
  describe "#integer?" do
    {% for int in BUILTIN_INTEGER_TYPES %}
      it { {{ int }}::MIN.integer?.should be_true }
      it { {{ int }}::MAX.integer?.should be_true }
    {% end %}
  end

  describe "**" do
    it "with positive Int32" do
      x = 2 ** 2
      x.should eq(4)
      x.should be_a(Int32)

      x = 2 ** 0
      x.should eq(1)
      x.should be_a(Int32)
    end

    it "with positive UInt8" do
      x = 2_u8 ** 2
      x.should eq(4)
      x.should be_a(UInt8)
    end

    it "raises with negative exponent" do
      expect_raises(ArgumentError, "Cannot raise an integer to a negative integer power, use floats for that") do
        2 ** -1
      end
    end

    it "should work with large integers" do
      x = 51_i64 ** 11
      x.should eq(6071163615208263051_i64)
      x.should be_a(Int64)
    end

    describe "with float" do
      it { (2 ** 2.0).should be_close(4, 0.0001) }
      it { (2 ** 2.5_f32).should be_close(5.656854249492381, 0.0001) }
      it { (2 ** 2.5).should be_close(5.656854249492381, 0.0001) }
    end
  end

  describe "&**" do
    it "with positive Int32" do
      x = 2 &** 2
      x.should eq(4)
      x.should be_a(Int32)

      x = 2 &** 0
      x.should eq(1)
      x.should be_a(Int32)
    end

    it "with UInt8" do
      x = 2_u8 &** 2
      x.should eq(4)
      x.should be_a(UInt8)
    end

    it "raises with negative exponent" do
      expect_raises(ArgumentError, "Cannot raise an integer to a negative integer power, use floats for that") do
        2 &** -1
      end
    end

    it "works with large integers" do
      x = 51_i64 &** 11
      x.should eq(6071163615208263051_i64)
      x.should be_a(Int64)
    end

    it "wraps with larger integers" do
      x = 51_i64 &** 12
      x.should eq(-3965304877440961871_i64)
      x.should be_a(Int64)
    end
  end

  describe "#===(:Char)" do
    it { (99 === 'c').should be_true }
    it { (99_u8 === 'c').should be_true }
    it { (99 === 'z').should be_false }
    it { (37202 === '酒').should be_true }
  end

  describe "divisible_by?" do
    it { 10.divisible_by?(5).should be_true }
    it { 10.divisible_by?(3).should be_false }
  end

  describe "even?" do
    it { 2.even?.should be_true }
    it { 3.even?.should be_false }
  end

  describe "odd?" do
    it { 2.odd?.should be_false }
    it { 3.odd?.should be_true }
  end

  describe "succ" do
    it { 8.succ.should eq(9) }
    it { -2147483648.succ.should eq(-2147483647) }
    it { 2147483646.succ.should eq(2147483647) }
  end

  describe "pred" do
    it { 9.pred.should eq(8) }
    it { -2147483647.pred.should eq(-2147483648) }
    it { 2147483647.pred.should eq(2147483646) }
  end

  describe "abs" do
    it "does for signed" do
      1_i8.abs.should eq(1_i8)
      -1_i8.abs.should eq(1_i8)
      1_i16.abs.should eq(1_i16)
      -1_i16.abs.should eq(1_i16)
      1_i32.abs.should eq(1_i32)
      -1_i32.abs.should eq(1_i32)
      1_i64.abs.should eq(1_i64)
      -1_i64.abs.should eq(1_i64)
    end

    it "does for unsigned" do
      1_u8.abs.should eq(1_u8)
      1_u16.abs.should eq(1_u16)
      1_u32.abs.should eq(1_u32)
      1_u64.abs.should eq(1_u64)
    end
  end

  describe "#to_signed" do
    {% for n in [8, 16, 32, 64, 128] %}
      it "does for Int{{ n }}" do
        x = Int{{ n }}.new(123).to_signed
        x.should be_a(Int{{ n }})
        x.should eq(123)

        Int{{ n }}.new(-123).to_signed.should eq(-123)
        Int{{ n }}::MIN.to_signed.should eq(Int{{ n }}::MIN)
        Int{{ n }}::MAX.to_signed.should eq(Int{{ n }}::MAX)
      end

      it "does for UInt{{ n }}" do
        x = UInt{{ n }}.new(123).to_signed
        x.should be_a(Int{{ n }})
        x.should eq(123)

        UInt{{ n }}::MIN.to_signed.should eq(0)
        expect_raises(OverflowError) { UInt{{ n }}::MAX.to_signed }
        expect_raises(OverflowError) { (UInt{{ n }}.new(Int{{ n }}::MAX) + 1).to_signed }
      end
    {% end %}
  end

  describe "#to_signed!" do
    {% for n in [8, 16, 32, 64, 128] %}
      it "does for Int{{ n }}" do
        x = Int{{ n }}.new(123).to_signed!
        x.should be_a(Int{{ n }})
        x.should eq(123)

        Int{{ n }}.new(-123).to_signed!.should eq(-123)
        Int{{ n }}::MIN.to_signed!.should eq(Int{{ n }}::MIN)
        Int{{ n }}::MAX.to_signed!.should eq(Int{{ n }}::MAX)
      end

      it "does for UInt{{ n }}" do
        x = UInt{{ n }}.new(123).to_signed!
        x.should be_a(Int{{ n }})
        x.should eq(123)

        UInt{{ n }}::MIN.to_signed!.should eq(0)
        UInt{{ n }}::MAX.to_signed!.should eq(-1)
        (UInt{{ n }}::MAX - 122).to_signed!.should eq(-123)
        (UInt{{ n }}.new(Int{{ n }}::MAX) + 1).to_signed!.should eq(Int{{ n }}::MIN)
      end
    {% end %}
  end

  describe "#to_unsigned" do
    {% for n in [8, 16, 32, 64, 128] %}
      it "does for Int{{ n }}" do
        x = Int{{ n }}.new(123).to_unsigned
        x.should be_a(UInt{{ n }})
        x.should eq(123)

        Int{{ n }}.zero.to_unsigned.should eq(UInt{{ n }}::MIN)
        Int{{ n }}::MAX.to_unsigned.should eq(UInt{{ n }}.new(Int{{ n }}::MAX))
        expect_raises(OverflowError) { Int{{ n }}::MIN.to_unsigned }
      end

      it "does for UInt{{ n }}" do
        x = UInt{{ n }}.new(123).to_unsigned
        x.should be_a(UInt{{ n }})
        x.should eq(123)

        UInt{{ n }}::MIN.to_unsigned.should eq(UInt{{ n }}::MIN)
        UInt{{ n }}::MAX.to_unsigned.should eq(UInt{{ n }}::MAX)
      end
    {% end %}
  end

  describe "#to_unsigned!" do
    {% for n in [8, 16, 32, 64, 128] %}
      it "does for Int{{ n }}" do
        x = Int{{ n }}.new(123).to_unsigned!
        x.should be_a(UInt{{ n }})
        x.should eq(123)

        Int{{ n }}.new(-123).to_unsigned!.should eq(UInt{{ n }}::MAX - 122)
        Int{{ n }}::MIN.to_unsigned!.should eq(UInt{{ n }}::MAX // 2 + 1)
        Int{{ n }}::MAX.to_unsigned!.should eq(UInt{{ n }}::MAX // 2)
        Int{{ n }}.new(-1).to_unsigned!.should eq(UInt{{ n }}::MAX)
      end

      it "does for UInt{{ n }}" do
        x = UInt{{ n }}.new(123).to_unsigned!
        x.should be_a(UInt{{ n }})
        x.should eq(123)

        UInt{{ n }}::MIN.to_unsigned!.should eq(UInt{{ n }}::MIN)
        UInt{{ n }}::MAX.to_unsigned!.should eq(UInt{{ n }}::MAX)
      end
    {% end %}
  end

  describe "#abs_unsigned" do
    {% for int in Int::Signed.union_types %}
      it "does for {{ int }}" do
        x = {{ int }}.new(123).abs_unsigned
        x.should be_a(U{{ int }})
        x.should eq(123)

        x = {{ int }}.new(-123).abs_unsigned
        x.should be_a(U{{ int }})
        x.should eq(123)
      end

      it "does for U{{ int }}" do
        x = U{{ int }}.new(123).abs_unsigned
        x.should be_a(U{{ int }})
        x.should eq(123)
      end

      it "does not overflow on {{ int }}::MIN" do
        x = {{ int }}::MIN.abs_unsigned
        x.should be_a(U{{ int }})
        x.should eq(U{{ int }}.zero &- {{ int }}::MIN)
      end
    {% end %}
  end

  describe "#neg_signed" do
    {% for int in Int::Signed.union_types %}
      it "does for {{ int }}" do
        x = {{ int }}.new(123).neg_signed
        x.should be_a({{ int }})
        x.should eq(-123)

        x = {{ int }}.new(-123).neg_signed
        x.should be_a({{ int }})
        x.should eq(123)

        expect_raises(OverflowError) { {{ int }}::MIN.neg_signed }
      end

      it "does for U{{ int }}" do
        x = U{{ int }}.new(123).neg_signed
        x.should be_a({{ int }})
        x.should eq(-123)
      end

      it "does not overflow on {{ int }}::MIN.abs_unsigned" do
        x = {{ int }}::MIN.abs_unsigned.neg_signed
        x.should be_a({{ int }})
        x.should eq({{ int }}::MIN)
      end
    {% end %}
  end

  describe "gcd" do
    it { 14.gcd(0).should eq(14) }
    it { 14.gcd(1).should eq(1) }
    it { 10.gcd(75).should eq(5) }
    it { 10.gcd(-75).should eq(5) }
    it { -10.gcd(75).should eq(5) }

    it { 7.gcd(5).should eq(1) }   # prime
    it { 14.gcd(25).should eq(1) } # coprime
    it { 24.gcd(40).should eq(8) } # common divisor

    it "doesn't silently overflow" { 614_889_782_588_491_410_i64.gcd(53).should eq(1) }
    it "raises on too big result to fit in result type" do
      expect_raises(OverflowError, "Arithmetic overflow") { Int64::MIN.gcd(1) }
    end
  end

  describe "lcm" do
    it { 2.lcm(2).should eq(2) }
    it { 3.lcm(-7).should eq(21) }
    it { 4.lcm(6).should eq(12) }
    it { 0.lcm(2).should eq(0) }
    it { 2.lcm(0).should eq(0) }

    it "doesn't silently overflow" { 2_000_000.lcm(3_000_000).should eq(6_000_000) }
  end

  describe "#to_s" do
    it_converts_to_s 0, "0"
    it_converts_to_s 1, "1"

    context "extrema for various int sizes" do
      it_converts_to_s 127_i8, "127"
      it_converts_to_s -128_i8, "-128"

      it_converts_to_s 32767_i16, "32767"
      it_converts_to_s -32768_i16, "-32768"

      it_converts_to_s 2147483647, "2147483647"
      it_converts_to_s -2147483648, "-2147483648"

      it_converts_to_s 9223372036854775807_i64, "9223372036854775807"
      it_converts_to_s -9223372036854775808_i64, "-9223372036854775808"

      it_converts_to_s 255_u8, "255"
      it_converts_to_s 65535_u16, "65535"
      it_converts_to_s 4294967295_u32, "4294967295"

      it_converts_to_s 18446744073709551615_u64, "18446744073709551615"

      it_converts_to_s UInt128::MAX, "340282366920938463463374607431768211455"
      it_converts_to_s Int128::MAX, "170141183460469231731687303715884105727"
      it_converts_to_s Int128::MIN, "-170141183460469231731687303715884105728"
    end

    context "base and upcase parameters" do
      it_converts_to_s 12, "1100", base: 2
      it_converts_to_s -12, "-1100", base: 2
      it_converts_to_s -123456, "-11110001001000000", base: 2
      it_converts_to_s 1234, "4d2", base: 16
      it_converts_to_s -1234, "-4d2", base: 16
      it_converts_to_s 1234, "ya", base: 36
      it_converts_to_s -1234, "-ya", base: 36
      it_converts_to_s 1234, "4D2", base: 16, upcase: true
      it_converts_to_s -1234, "-4D2", base: 16, upcase: true
      it_converts_to_s 1234, "YA", base: 36, upcase: true
      it_converts_to_s -1234, "-YA", base: 36, upcase: true
      it_converts_to_s 0, "0", base: 2
      it_converts_to_s 0, "0", base: 16
      it_converts_to_s 1, "1", base: 2
      it_converts_to_s 1, "1", base: 16
      it_converts_to_s 0, "0", base: 62
      it_converts_to_s 1, "1", base: 62
      it_converts_to_s 10, "a", base: 62
      it_converts_to_s 35, "z", base: 62
      it_converts_to_s 36, "A", base: 62
      it_converts_to_s 61, "Z", base: 62
      it_converts_to_s 62, "10", base: 62
      it_converts_to_s 97, "1z", base: 62
      it_converts_to_s 3843, "ZZ", base: 62
      it_converts_to_s Int128::MIN, "-1#{"0" * 127}", base: 2

      it "raises on base 1" do
        expect_raises(ArgumentError, "Invalid base 1") { 123.to_s(1) }
        expect_raises(ArgumentError, "Invalid base 1") { 123.to_s(IO::Memory.new, 1) }
      end

      it "raises on base 37" do
        expect_raises(ArgumentError, "Invalid base 37") { 123.to_s(37) }
        expect_raises(ArgumentError, "Invalid base 37") { 123.to_s(IO::Memory.new, 37) }
      end

      it "raises on base 62 with upcase" do
        expect_raises(ArgumentError, "upcase must be false for base 62") { 123.to_s(62, upcase: true) }
        expect_raises(ArgumentError, "upcase must be false for base 62") { 123.to_s(IO::Memory.new, 62, upcase: true) }
      end
    end

    context "precision parameter" do
      it_converts_to_s 0, "", precision: 0
      it_converts_to_s 0, "0", precision: 1
      it_converts_to_s 0, "00", precision: 2
      it_converts_to_s 0, "00000", precision: 5
      it_converts_to_s 0, "0" * 200, precision: 200

      it_converts_to_s 1, "1", precision: 0
      it_converts_to_s 1, "1", precision: 1
      it_converts_to_s 1, "01", precision: 2
      it_converts_to_s 1, "00001", precision: 5
      it_converts_to_s 1, "#{"0" * 199}1", precision: 200

      it_converts_to_s 2, "2", precision: 0
      it_converts_to_s 2, "2", precision: 1
      it_converts_to_s 2, "02", precision: 2
      it_converts_to_s 2, "00002", precision: 5
      it_converts_to_s 2, "#{"0" * 199}2", precision: 200

      it_converts_to_s -1, "-1", precision: 0
      it_converts_to_s -1, "-1", precision: 1
      it_converts_to_s -1, "-01", precision: 2
      it_converts_to_s -1, "-00001", precision: 5
      it_converts_to_s -1, "-#{"0" * 199}1", precision: 200

      it_converts_to_s 123, "123", precision: 0
      it_converts_to_s 123, "123", precision: 1
      it_converts_to_s 123, "123", precision: 2
      it_converts_to_s 123, "00123", precision: 5
      it_converts_to_s 123, "#{"0" * 197}123", precision: 200

      it_converts_to_s 9223372036854775807_i64, "#{"1" * 63}", base: 2, precision: 62
      it_converts_to_s 9223372036854775807_i64, "#{"1" * 63}", base: 2, precision: 63
      it_converts_to_s 9223372036854775807_i64, "0#{"1" * 63}", base: 2, precision: 64
      it_converts_to_s 9223372036854775807_i64, "#{"0" * 137}#{"1" * 63}", base: 2, precision: 200

      it_converts_to_s -9223372036854775808_i64, "-1#{"0" * 63}", base: 2, precision: 63
      it_converts_to_s -9223372036854775808_i64, "-1#{"0" * 63}", base: 2, precision: 64
      it_converts_to_s -9223372036854775808_i64, "-01#{"0" * 63}", base: 2, precision: 65
      it_converts_to_s -9223372036854775808_i64, "-#{"0" * 136}1#{"0" * 63}", base: 2, precision: 200

      it "raises on negative precision" do
        expect_raises(ArgumentError, "Precision must be non-negative") { 123.to_s(precision: -1) }
        expect_raises(ArgumentError, "Precision must be non-negative") { 123.to_s(IO::Memory.new, precision: -1) }
      end
    end
  end

  describe "#inspect" do
    it "doesn't append the type" do
      23.inspect.should eq("23")
      23_i8.inspect.should eq("23")
      23_i16.inspect.should eq("23")
      -23_i64.inspect.should eq("-23")
      23_u8.inspect.should eq("23")
      23_u16.inspect.should eq("23")
      23_u32.inspect.should eq("23")
      23_u64.inspect.should eq("23")
    end

    it "doesn't append the type using IO" do
      str = String.build { |io| 23.inspect(io) }
      str.should eq("23")

      str = String.build { |io| -23_i64.inspect(io) }
      str.should eq("-23")
    end
  end

  describe "bit" do
    it { 5.bit(0).should eq(1) }
    it { 5.bit(1).should eq(0) }
    it { 5.bit(2).should eq(1) }
    it { 5.bit(3).should eq(0) }
    it { 0.bit(63).should eq(0) }
    it { Int64::MAX.bit(63).should eq(0) }
    it { UInt64::MAX.bit(63).should eq(1) }
    it { UInt64::MAX.bit(64).should eq(0) }
  end

  describe "#bits" do
    # Basic usage
    it { 0b10011.bits(0..0).should eq(0b1) }
    it { 0b10011.bits(0..1).should eq(0b11) }
    it { 0b10011.bits(0..2).should eq(0b11) }
    it { 0b10011.bits(0..3).should eq(0b11) }
    it { 0b10011.bits(0..4).should eq(0b10011) }
    it { 0b10011.bits(0..5).should eq(0b10011) }
    it { 0b10011.bits(1..5).should eq(0b1001) }

    # no range start indicated
    it { 0b10011.bits(..1).should eq(0b11) }
    it { 0b10011.bits(..2).should eq(0b11) }
    it { 0b10011.bits(..3).should eq(0b11) }
    it { 0b10011.bits(..4).should eq(0b10011) }

    # Check against limits
    it { 0b10011_u8.bits(0..16).should eq(0b10011_u8) }
    it { 0b10011_u8.bits(1..16).should eq(0b1001_u8) }

    # Will work with signed values
    it { -5_i8.bits(0..16).should eq(-5_i8) }
    it { -5_i8.bits(1..16).should eq(-3_i8) }
    it { -5_i8.bits(2..16).should eq(-2_i8) }
    it { -5_i8.bits(3..16).should eq(-1_i8) }

    it "raises when invalid indexes are provided" do
      expect_raises(IndexError) { 0b10011.bits(0..-1) }
      expect_raises(IndexError) { 0b10011.bits(-1..3) }
      expect_raises(IndexError) { 0b10011.bits(4..2) }
    end
  end

  describe "divmod" do
    it "returns a Tuple of two elements containing the quotient and modulus obtained by dividing self by argument" do
      5.divmod(3).should eq({1, 2})
      -5.divmod(3).should eq({-2, 1})
      5.divmod(-3).should eq({-2, -1})
      -5.divmod(-3).should eq({1, -2})
    end

    it "preserves type of lhs" do
      {% for type in [UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64, UInt128, Int128] %}
        {{ type }}.new(7).divmod(2).should be_a(Tuple({{ type }}, {{ type }}))
      {% end %}
    end

    it "raises when divides by zero" do
      expect_raises(DivisionByZeroError) { 5.divmod(0) }
    end

    it "raises when divides Int::MIN by -1" do
      expect_raises(ArgumentError) { Int8::MIN.divmod(-1) }
      expect_raises(ArgumentError) { Int16::MIN.divmod(-1) }
      expect_raises(ArgumentError) { Int32::MIN.divmod(-1) }
      expect_raises(ArgumentError) { Int64::MIN.divmod(-1) }
      expect_raises(ArgumentError) { Int128::MIN.divmod(-1) }

      (UInt8::MIN.divmod(-1)).should eq({0, 0})
    end
  end

  describe "tdivmod" do
    it "returns a Tuple of two elements containing the quotient and modulus obtained by dividing self by argument using truncated division" do
      5.tdivmod(3).should eq({1, 2})
      -5.tdivmod(3).should eq({-1, -2})
      5.tdivmod(-3).should eq({-1, 2})
      -5.tdivmod(-3).should eq({1, -2})
    end

    it "preserves type of lhs" do
      {% for type in [UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64, UInt128, Int128] %}
        {{ type }}.new(7).tdivmod(2).should be_a(Tuple({{ type }}, {{ type }}))
      {% end %}
    end

    it "raises when divides by zero" do
      expect_raises(DivisionByZeroError) { 5.tdivmod(0) }
    end

    it "raises when divides Int::MIN by -1" do
      expect_raises(ArgumentError) { Int8::MIN.tdivmod(-1) }
      expect_raises(ArgumentError) { Int16::MIN.tdivmod(-1) }
      expect_raises(ArgumentError) { Int32::MIN.tdivmod(-1) }
      expect_raises(ArgumentError) { Int64::MIN.tdivmod(-1) }
      expect_raises(ArgumentError) { Int128::MIN.tdivmod(-1) }

      (UInt8::MIN.tdivmod(-1)).should eq({0, 0})
    end
  end

  describe "fdiv" do
    it { 1.fdiv(1).should eq 1.0 }
    it { 1.fdiv(2).should eq 0.5 }
    it { 1.fdiv(0.5).should eq 2.0 }
    it { 0.fdiv(1).should eq 0.0 }
    it { 1.fdiv(0).should eq 1.0/0.0 }
  end

  describe "~" do
    it { (~1).should eq(-2) }
    it { (~1_u32).should eq(4294967294) }
  end

  describe ">>" do
    it { (8000 >> 1).should eq(4000) }
    it { (8000 >> 2).should eq(2000) }
    it { (8000 >> 32).should eq(0) }
    it { (8000 >> -1).should eq(16000) }
  end

  describe "<<" do
    it { (8000 << 1).should eq(16000) }
    it { (8000 << 2).should eq(32000) }
    it { (8000 << 32).should eq(0) }
    it { (8000 << -1).should eq(4000) }
  end

  describe "#rotate_left" do
    it { 0x87654321_u32.rotate_left(1).should eq(0x0ECA8643_u32) }
    it { 0x87654321_u32.rotate_left(2).should eq(0x1D950C86_u32) }
    it { 0x87654321_u32.rotate_left(-1).should eq(0xC3B2A190_u32) }
    it { 0x87654321_u32.rotate_left(-2).should eq(0x61D950C8_u32) }
    it { 0x87654321_u32.rotate_left(32).should eq(0x87654321_u32) }

    it { -0x789ABCDF.rotate_left(1).should eq(0x0ECA8643) }
    it { -0x789ABCDF.rotate_left(2).should eq(0x1D950C86) }
    it { -0x789ABCDF.rotate_left(-1).should eq(-0x3C4D5E70) }
    it { -0x789ABCDF.rotate_left(-2).should eq(0x61D950C8) }
    it { -0x789ABCDF.rotate_left(32).should eq(-0x789ABCDF) }

    {% for int in BUILTIN_INTEGER_TYPES %}
      it do
        x = ({{ int }}.new(1) << (sizeof({{ int }}) * 8 - 1)).rotate_left(1)
        x.should be_a({{ int }})
        x.should eq({{ int }}.new(1))
      end
    {% end %}
  end

  describe "#rotate_right" do
    it { 0x87654321_u32.rotate_right(1).should eq(0xC3B2A190_u32) }
    it { 0x87654321_u32.rotate_right(2).should eq(0x61D950C8_u32) }
    it { 0x87654321_u32.rotate_right(-1).should eq(0x0ECA8643_u32) }
    it { 0x87654321_u32.rotate_right(-2).should eq(0x1D950C86_u32) }
    it { 0x87654321_u32.rotate_right(32).should eq(0x87654321_u32) }

    it { -0x789ABCDF.rotate_right(1).should eq(-0x3C4D5E70) }
    it { -0x789ABCDF.rotate_right(2).should eq(0x61D950C8) }
    it { -0x789ABCDF.rotate_right(-1).should eq(0x0ECA8643) }
    it { -0x789ABCDF.rotate_right(-2).should eq(0x1D950C86) }
    it { -0x789ABCDF.rotate_right(32).should eq(-0x789ABCDF) }

    {% for int in BUILTIN_INTEGER_TYPES %}
      it do
        x = {{ int }}.new(1).rotate_right(1)
        x.should be_a({{ int }})
        x.should eq({{ int }}.new(1) << (sizeof({{ int }}) * 8 - 1))
      end
    {% end %}
  end

  describe "to" do
    it "does upwards" do
      a = 0
      1.to(3) { |i| a += i }.should be_nil
      a.should eq(6)
    end

    it "does downwards" do
      a = 0
      4.to(2) { |i| a += i }.should be_nil
      a.should eq(9)
    end

    it "does when same" do
      a = 0
      2.to(2) { |i| a += i }.should be_nil
      a.should eq(2)
    end
  end

  describe "step" do
    it "steps through limit" do
      passed = false
      1.step(to: 1) { |x| passed = true }
      fail "expected step to pass through 1" unless passed
    end
  end

  describe ".new" do
    it "String overload" do
      Int8.new("1").should be_a(Int8)
      Int8.new("1").should eq(1)
      expect_raises ArgumentError, %(Invalid Int8: " 1 ") do
        Int8.new(" 1 ", whitespace: false)
      end

      Int16.new("1").should be_a(Int16)
      Int16.new("1").should eq(1)
      expect_raises ArgumentError, %(Invalid Int16: " 1 ") do
        Int16.new(" 1 ", whitespace: false)
      end

      Int32.new("1").should be_a(Int32)
      Int32.new("1").should eq(1)
      expect_raises ArgumentError, %(Invalid Int32: " 1 ") do
        Int32.new(" 1 ", whitespace: false)
      end

      Int64.new("1").should be_a(Int64)
      Int64.new("1").should eq(1)
      expect_raises ArgumentError, %(Invalid Int64: " 1 ") do
        Int64.new(" 1 ", whitespace: false)
      end

      UInt8.new("1").should be_a(UInt8)
      UInt8.new("1").should eq(1)
      expect_raises ArgumentError, %(Invalid UInt8: " 1 ") do
        UInt8.new(" 1 ", whitespace: false)
      end

      UInt16.new("1").should be_a(UInt16)
      UInt16.new("1").should eq(1)
      expect_raises ArgumentError, %(Invalid UInt16: " 1 ") do
        UInt16.new(" 1 ", whitespace: false)
      end

      UInt32.new("1").should be_a(UInt32)
      UInt32.new("1").should eq(1)
      expect_raises ArgumentError, %(Invalid UInt32: " 1 ") do
        UInt32.new(" 1 ", whitespace: false)
      end

      UInt64.new("1").should be_a(UInt64)
      UInt64.new("1").should eq(1)
      expect_raises ArgumentError, %(Invalid UInt64: " 1 ") do
        UInt64.new(" 1 ", whitespace: false)
      end
    end

    it "fallback overload" do
      Int8.new(1).should be_a(Int8)
      Int8.new(1).should eq(1)

      Int16.new(1).should be_a(Int16)
      Int16.new(1).should eq(1)

      Int32.new(1).should be_a(Int32)
      Int32.new(1).should eq(1)

      Int64.new(1).should be_a(Int64)
      Int64.new(1).should eq(1)

      Int128.new(1).should be_a(Int128)
      Int128.new(1).should eq(1)

      UInt8.new(1).should be_a(UInt8)
      UInt8.new(1).should eq(1)

      UInt16.new(1).should be_a(UInt16)
      UInt16.new(1).should eq(1)

      UInt32.new(1).should be_a(UInt32)
      UInt32.new(1).should eq(1)

      UInt64.new(1).should be_a(UInt64)
      UInt64.new(1).should eq(1)

      UInt128.new(1).should be_a(UInt128)
      UInt128.new(1).should eq(1)
    end
  end

  describe "arithmetic division /" do
    it "divides negative numbers" do
      (7 / 2).should eq(3.5)
      (-7 / 2).should eq(-3.5)
      (7 / -2).should eq(-3.5)
      (-7 / -2).should eq(3.5)

      (6 / 2).should eq(3.0)
      (-6 / 2).should eq(-3.0)
      (6 / -2).should eq(-3.0)
      (-6 / -2).should eq(3.0)
    end

    it "divides by zero" do
      (1 / 0).should eq(Float64::INFINITY)
    end

    it "divides Int::MIN by -1" do
      (Int8::MIN / -1).should eq(-(Int8::MIN.to_f64))
      (Int16::MIN / -1).should eq(-(Int16::MIN.to_f64))
      (Int32::MIN / -1).should eq(-(Int32::MIN.to_f64))
      (Int64::MIN / -1).should eq(-(Int64::MIN.to_f64))
      (Int128::MIN / -1).should eq(-(Int128::MIN.to_f64))

      (UInt8::MIN / -1).should eq(0)
    end
  end

  describe "floor division //" do
    it "preserves type of lhs" do
      {% for type in [UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64, UInt128, Int128] %}
        ({{ type }}.new(7) // 2).should be_a({{ type }})
        ({{ type }}.new(7) // 2.0).should be_a({{ type }})
        ({{ type }}.new(7) // 2.0_f32).should be_a({{ type }})
      {% end %}
    end

    it "divides negative numbers" do
      (7 // 2).should eq(3)
      (-7 // 2).should eq(-4)
      (7 // -2).should eq(-4)
      (-7 // -2).should eq(3)

      (6 // 2).should eq(3)
      (-6 // 2).should eq(-3)
      (6 // -2).should eq(-3)
      (-6 // -2).should eq(3)
    end
  end

  describe "tdiv" do
    it "divides self by argument using truncated division" do
      5.tdiv(3).should eq(1)
      -5.tdiv(3).should eq(-1)
      5.tdiv(-3).should eq(-1)
      -5.tdiv(-3).should eq(1)
    end

    it "preserves type of lhs" do
      {% for type in [UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64, UInt128, Int128] %}
        {{ type }}.new(7).tdiv(2).should be_a({{ type }})
      {% end %}
    end

    it "raises when divides by zero" do
      expect_raises(DivisionByZeroError) { 5.tdiv(0) }
    end

    it "raises when divides Int::MIN by -1" do
      expect_raises(ArgumentError) { Int8::MIN.tdiv(-1) }
      expect_raises(ArgumentError) { Int16::MIN.tdiv(-1) }
      expect_raises(ArgumentError) { Int32::MIN.tdiv(-1) }
      expect_raises(ArgumentError) { Int64::MIN.tdiv(-1) }
      expect_raises(ArgumentError) { Int128::MIN.tdiv(-1) }

      (UInt8::MIN.tdiv(-1)).should eq(0)
    end
  end

  it "holds true that x == q*y + r" do
    [5, -5, 6, -6, 10, -10].each do |x|
      [3, -3].each do |y|
        q = x // y
        r = x % y
        (q*y + r).should eq(x)
      end
    end
  end

  it "raises when divides by zero" do
    expect_raises(DivisionByZeroError) { 1 // 0 }
    (4 // 2).should eq(2)
  end

  it "raises when divides Int::MIN by -1" do
    expect_raises(ArgumentError) { Int8::MIN // -1 }
    expect_raises(ArgumentError) { Int16::MIN // -1 }
    expect_raises(ArgumentError) { Int32::MIN // -1 }
    expect_raises(ArgumentError) { Int64::MIN // -1 }
    expect_raises(ArgumentError) { Int128::MIN // -1 }

    (UInt8::MIN // -1).should eq(0)
  end

  it "raises when mods by zero" do
    expect_raises(DivisionByZeroError) { 1 % 0 }
    (4 % 2).should eq(0)
  end

  it "% doesn't overflow (#7979)" do
    (53 % 532_000_782_588_491_410).should eq(53)
  end

  it_iterates "#times", [0, 1, 2], 3.times
  it_iterates "#times for UInt32 (#5019)", [0_u32, 1_u32, 2_u32, 3_u32], 4_u32.times

  it "does %" do
    (7 % 5).should eq(2)
    (-7 % 5).should eq(3)

    (13 % -4).should eq(-3)
    (-13 % -4).should eq(-1)
  end

  it "returns 0 when doing IntN::MIN % -1 (#8306)" do
    {% for n in [8, 16, 32, 64, 128] %}
      (Int{{ n }}::MIN % -1.to_i{{ n }}).should eq(0)
    {% end %}
  end

  it "does remainder" do
    7.remainder(5).should eq(2)
    -7.remainder(5).should eq(-2)

    13.remainder(-4).should eq(1)
    -13.remainder(-4).should eq(-1)
  end

  it "returns 0 when doing IntN::MIN.remainder(-1) (#8306)" do
    {% for n in [8, 16, 32, 64, 128] %}
      (Int{{ n }}::MIN.remainder(-1.to_i{{ n }})).should eq(0)
    {% end %}
  end

  it "does upto" do
    i = sum = 0
    1.upto(3) do |n|
      i += 1
      sum += n
    end.should be_nil
    i.should eq(3)
    sum.should eq(6)
  end

  it "does upto max" do
    i = sum = 0
    (Int32::MAX - 3).upto(Int32::MAX) do |n|
      i += 1
      sum += Int32::MAX - n
      n.should be >= (Int32::MAX - 3)
    end.should be_nil
    i.should eq(4)
    sum.should eq(6)
  end

  it "gets upto iterator" do
    iter = 1.upto(3)
    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should eq(3)
    iter.next.should be_a(Iterator::Stop)
  end

  it "gets upto iterator max" do
    iter = (Int32::MAX - 3).upto(Int32::MAX)
    iter.next.should eq(Int32::MAX - 3)
    iter.next.should eq(Int32::MAX - 2)
    iter.next.should eq(Int32::MAX - 1)
    iter.next.should eq(Int32::MAX)
    iter.next.should be_a(Iterator::Stop)
  end

  it "upto iterator ups and downs" do
    0.upto(3).to_a.should eq([0, 1, 2, 3])
    3.upto(0).to_a.should eq([] of Int32)
    res = [Int32::MAX - 3, Int32::MAX - 2, Int32::MAX - 1, Int32::MAX]
    (Int32::MAX - 3).upto(Int32::MAX).to_a.should eq(res)
    Int32::MAX.upto(0).to_a.should eq([] of Int32)
  end

  it "does downto" do
    i = sum = 0
    3.downto(1) do |n|
      i += 1
      sum += n
    end.should be_nil
    i.should eq(3)
    sum.should eq(6)
  end

  it "does downto min" do
    i = sum = 0
    (Int32::MIN + 3).downto(Int32::MIN) do |n|
      i += 1
      sum += n - Int32::MIN
      n.should be <= Int32::MIN + 3
    end
    i.should eq(4)
    sum.should eq(6)
  end

  it "does downto min unsigned" do
    i = sum = 0
    3_u16.downto(0) do |n|
      i += 1
      sum += n
      n.should be <= 3_u16
    end
    i.should eq(4)
    sum.should eq(6)
  end

  it "gets downto iterator" do
    iter = 3.downto(1)
    iter.next.should eq(3)
    iter.next.should eq(2)
    iter.next.should eq(1)
    iter.next.should be_a(Iterator::Stop)
  end

  it "downto iterator ups and downs" do
    3.downto(0).to_a.should eq([3, 2, 1, 0])
    3_u16.downto(0).to_a.should eq([3_u16, 2_u16, 1_u16, 0_u16])
    3.downto(4).to_a.should eq([] of Int32)
    3_u16.downto(4_u16).to_a.should eq([] of UInt16)
    res = [Int32::MIN + 3, Int32::MIN + 2, Int32::MIN + 1, Int32::MIN]
    (Int32::MIN + 3).downto(Int32::MIN).to_a.should eq(res)
  end

  it "gets downto iterator unsigned" do
    iter = 3_u16.downto(0)
    iter.next.should eq(3)
    iter.next.should eq(2)
    iter.next.should eq(1)
    iter.next.should eq(0)
    iter.next.should be_a(Iterator::Stop)
  end

  it "gets to iterator" do
    iter = 1.to(3)
    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should eq(3)
    iter.next.should be_a(Iterator::Stop)
  end

  describe "#bit_reverse" do
    it { 0x12_u8.bit_reverse.should eq(0x48_u8) }
    it { 0x1234_u16.bit_reverse.should eq(0x2C48_u16) }
    it { 0x12345678_u32.bit_reverse.should eq(0x1E6A2C48_u32) }
    it { 0x123456789ABCDEF0_u64.bit_reverse.should eq(0x0F7B3D591E6A2C48_u64) }
    it { 1.to_u128.bit_reverse.should eq(1.to_u128 << 127) }
    it { (1.to_u128 << 127).bit_reverse.should eq(0x1.to_u128) }
    it { 0x12345678.to_u128.bit_reverse.should eq(0x1E6A2C48.to_u128 << 96) }

    it { 0x12_i8.bit_reverse.should eq(0x48_i8) }
    it { 0x1234_i16.bit_reverse.should eq(0x2C48_i16) }
    it { 0x12345678_i32.bit_reverse.should eq(0x1E6A2C48_i32) }
    it { 0x123456789ABCDEF0_i64.bit_reverse.should eq(0x0F7B3D591E6A2C48_i64) }
    it { 1.to_i128.bit_reverse.should eq(1.to_i128 << 127) }
    it { (1.to_i128 << 127).bit_reverse.should eq(0x1.to_i128) }
    it { 0x12345678.to_i128.bit_reverse.should eq(0x1E6A2C48.to_i128 << 96) }

    {% for width in %w(8 16 32 64 128).map(&.id) %}
      it { 0.to_i{{ width }}.bit_reverse.should be_a(Int{{ width }}) }
      it { 0.to_u{{ width }}.bit_reverse.should be_a(UInt{{ width }}) }
    {% end %}
  end

  describe "#byte_swap" do
    it { 0x12_u8.byte_swap.should eq(0x12_u8) }
    it { 0x1234_u16.byte_swap.should eq(0x3412_u16) }
    it { 0x12345678_u32.byte_swap.should eq(0x78563412_u32) }
    it { 0x123456789ABCDEF0_u64.byte_swap.should eq(0xF0DEBC9A78563412_u64) }
    it { 1.to_u128.byte_swap.should eq(1.to_u128 << 120) }
    it { (1.to_u128 << 127).byte_swap.should eq(0x80.to_u128) }
    it { 0x12345678.to_u128.byte_swap.should eq(0x78563412.to_u128 << 96) }

    it { 0x12_i8.byte_swap.should eq(0x12_i8) }
    it { 0x1234_i16.byte_swap.should eq(0x3412_i16) }
    it { 0x12345678_i32.byte_swap.should eq(0x78563412_i32) }
    it { 0x123456789ABCDEF0_i64.byte_swap.should eq(0xF0DEBC9A78563412_u64.to_i64!) }
    it { 1.to_i128.byte_swap.should eq(1.to_i128 << 120) }
    it { (1.to_i128 << 127).byte_swap.should eq(0x80.to_i128) }
    it { 0x12345678.to_i128.byte_swap.should eq(0x78563412.to_i128 << 96) }

    {% for width in %w(8 16 32 64 128).map(&.id) %}
      it { 0.to_i{{ width }}.byte_swap.should be_a(Int{{ width }}) }
      it { 0.to_u{{ width }}.byte_swap.should be_a(UInt{{ width }}) }
    {% end %}
  end

  describe "#popcount" do
    it { 5_i8.popcount.should eq(2) }
    it { 127_i8.popcount.should eq(7) }
    it { -1_i8.popcount.should eq(8) }
    it { -128_i8.popcount.should eq(1) }

    it { 0_u8.popcount.should eq(0) }
    it { 255_u8.popcount.should eq(8) }

    it { 5_i16.popcount.should eq(2) }
    it { -6_i16.popcount.should eq(14) }
    it { 65535_u16.popcount.should eq(16) }

    it { 0_i32.popcount.should eq(0) }
    it { 2147483647_i32.popcount.should eq(31) }
    it { 4294967295_u32.popcount.should eq(32) }

    it { 5_i64.popcount.should eq(2) }
    it { 9223372036854775807_i64.popcount.should eq(63) }
    it { 18446744073709551615_u64.popcount.should eq(64) }

    it { 0_i128.popcount.should eq(0) }
    it { Int128::MAX.popcount.should eq(127) }
    it { UInt128::MAX.popcount.should eq(128) }
  end

  describe "#leading_zeros_count" do
    {% for width in %w(8 16 32 64 128).map(&.id) %}
      it { -1.to_i{{ width }}.leading_zeros_count.should eq(0) }
      it { 0.to_i{{ width }}.leading_zeros_count.should eq({{ width }}) }
      it { 0.to_u{{ width }}.leading_zeros_count.should eq({{ width }}) }
    {% end %}
  end

  describe "#trailing_zeros_count" do
    {% for width in %w(8 16 32 64 128).map(&.id) %}
      it { -2.to_i{{ width }}.trailing_zeros_count.should eq(1) }
      it { 2.to_i{{ width }}.trailing_zeros_count.should eq(1) }
      it { 2.to_u{{ width }}.trailing_zeros_count.should eq(1) }
    {% end %}
  end

  it "compares signed vs. unsigned integers" do
    {% begin %}
      signed_ints = [
        Int8::MAX, Int16::MAX, Int32::MAX, Int64::MAX, Int128::MAX,
        Int8::MIN, Int16::MIN, Int32::MIN, Int64::MIN, Int128::MIN,
        Int8.zero, Int16.zero, Int32.zero, Int64.zero, Int128.zero,
      ]
      unsigned_ints = [
        UInt8::MAX, UInt16::MAX, UInt32::MAX, UInt64::MAX, UInt128::MAX,
        UInt8.zero, UInt16.zero, UInt32.zero, UInt64.zero, UInt128.zero,
      ]

      big_signed_ints = signed_ints.map &.to_big_i
      big_unsigned_ints = unsigned_ints.map &.to_big_i

      signed_ints.zip(big_signed_ints) do |si, bsi|
        unsigned_ints.zip(big_unsigned_ints) do |ui, bui|
          {% for op in %w(< <= > >=).map(&.id) %}
            if (si {{ op }} ui) != (bsi {{ op }} bui)
              fail "comparison of #{si} {{ op }} #{ui} (#{si.class} {{ op }} #{ui.class}) gave incorrect result"
            end
          {% end %}
        end
      end
    {% end %}
  end

  it "compares equality and inequality of signed vs. unsigned integers" do
    x = -1
    y = x.unsafe_as(UInt32)

    (x == y).should be_false
    (y == x).should be_false
    (x != y).should be_true
    (y != x).should be_true
  end

  it "clones" do
    [1_u8, 2_u16, 3_u32, 4_u64, 5.to_u128, 6_i8, 7_i16, 8_i32, 9_i64, 10.to_i128].each do |value|
      value.clone.should eq(value)
    end
  end

  it "#chr" do
    65.chr.should eq('A')

    expect_raises(ArgumentError, "0x110000 out of char range") do
      (0x10ffff + 1).chr
    end

    expect_raises(ArgumentError, "0xd800 out of char range") do
      0xd800.chr
    end

    expect_raises(ArgumentError, "0xdfff out of char range") do
      0xdfff.chr
    end
  end

  it "#unsafe_chr" do
    65.unsafe_chr.should eq('A')
    (0x10ffff + 1).unsafe_chr.ord.should eq(0x10ffff + 1)
  end

  describe "#bit_length" do
    it "for primitive integers" do
      0.bit_length.should eq(0)
      0b1.bit_length.should eq(1)
      0b1001.bit_length.should eq(4)
      0b1001001_i64.bit_length.should eq(7)
      0b1111111111.bit_length.should eq(10)
      0b1000000000.bit_length.should eq(10)
      -1.bit_length.should eq(0)
      -10.bit_length.should eq(4)
    end

    it "for BigInt" do
      (10.to_big_i ** 20).bit_length.should eq(67)
      (10.to_big_i ** 309).bit_length.should eq(1027)
      (10.to_big_i ** 3010).bit_length.should eq(10000)
    end
  end

  describe "#digits" do
    it "works for positive numbers or zero" do
      0.digits.should eq([0])
      1.digits.should eq([1])
      10.digits.should eq([0, 1])
      123.digits.should eq([3, 2, 1])
      123456789.digits.should eq([9, 8, 7, 6, 5, 4, 3, 2, 1])
    end

    it "works for maximums" do
      Int32::MAX.digits.should eq(Int32::MAX.to_s.chars.map(&.to_i).reverse!)
      Int64::MAX.digits.should eq(Int64::MAX.to_s.chars.map(&.to_i).reverse!)
      UInt64::MAX.digits.should eq(UInt64::MAX.to_s.chars.map(&.to_i).reverse!)
      Int128::MAX.digits.should eq(Int128::MAX.to_s.chars.map(&.to_i).reverse!)
      UInt128::MAX.digits.should eq(UInt128::MAX.to_s.chars.map(&.to_i).reverse!)
    end

    it "works for non-Int32" do
      digits = 123_i64.digits
      digits.should eq([3, 2, 1])
    end

    it "works with a base" do
      123.digits(16).should eq([11, 7])
    end

    it "raises for invalid base" do
      [1, 0, -1].each do |base|
        expect_raises(ArgumentError, "Invalid base #{base}") do
          123.digits(base)
        end
      end
    end

    it "raises for negative numbers" do
      expect_raises(ArgumentError, "Can't request digits of negative number") do
        -123.digits
      end
    end
  end

  describe "from_digits" do
    it "returns Int composed from given digits" do
      Int32.from_digits([9, 8, 7, 6, 5, 4, 3, 2, 1]).should eq(123456789)
    end

    it "works with a base" do
      Int32.from_digits([11, 7], 16).should eq(123)
      Int32.from_digits([11, 7], base: 16).should eq(123)
    end

    it "accepts digits as Enumerable" do
      enumerable = IntEnumerable.new([11, 7])
      Int32.from_digits(enumerable, 16).should eq(123)
    end

    it "raises for base less than 2" do
      [-1, 0, 1].each do |base|
        expect_raises(ArgumentError, "Invalid base #{base}") do
          Int32.from_digits([1, 2, 3], base)
        end
      end
    end

    it "raises for digits greater than base" do
      expect_raises(ArgumentError, "Invalid digit 2 for base 2") do
        Int32.from_digits([1, 0, 2], 2)
      end

      expect_raises(ArgumentError, "Invalid digit 10 for base 2") do
        Int32.from_digits([1, 0, 10], 2)
      end
    end

    it "raises for negative digits" do
      expect_raises(ArgumentError, "Invalid digit -1") do
        Int32.from_digits([1, 2, -1])
      end
    end

    it "works properly for values close to the upper limit" do
      UInt8.from_digits([5, 5, 2]).should eq(255)
    end
  end
end
