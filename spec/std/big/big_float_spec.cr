require "spec"
require "big"
require "spec/helpers/string"

private def it_converts_to_s(value : BigFloat, str, *, file = __FILE__, line = __LINE__)
  it "converts to #{str}", file: file, line: line do
    assert_prints value.to_s, str, file: file, line: line
    str.to_big_f.should eq(value), file: file, line: line
  end
end

private def with_precision(precision, &)
  old_precision = BigFloat.default_precision
  BigFloat.default_precision = precision

  begin
    yield
  ensure
    BigFloat.default_precision = old_precision
  end
end

describe "BigFloat" do
  describe ".new" do
    string_of_integer_value = "123456789012345678901"
    string_of_integer_value_as_float = "1.23456789012345678901e+20"
    bigfloat_of_integer_value = BigFloat.new(string_of_integer_value)
    string_of_float_value = "1234567890.12345678901"
    bigfloat_of_float_value = BigFloat.new(string_of_float_value)

    it "new(String)" do
      bigfloat_of_integer_value.to_s.should eq(string_of_integer_value_as_float)
      bigfloat_of_float_value.to_s.should eq(string_of_float_value)
      BigFloat.new("+#{string_of_integer_value}").to_s.should eq(string_of_integer_value_as_float)
      BigFloat.new("-#{string_of_integer_value}").to_s.should eq("-#{string_of_integer_value_as_float}")
      BigFloat.new("123_456_789.123_456_789").to_s.should eq("123456789.123456789")
    end

    it "raises an ArgumentError unless string denotes valid float" do
      expect_raises(ArgumentError) { BigFloat.new("abc") }
      expect_raises(ArgumentError) { BigFloat.new("+") }
      expect_raises(ArgumentError) { BigFloat.new("") }
    end

    it "new(BigInt)" do
      bigfloat_on_bigint_value = BigFloat.new(BigInt.new(string_of_integer_value))
      bigfloat_on_bigint_value.should eq(bigfloat_of_integer_value)
      bigfloat_on_bigint_value.to_s.should eq(string_of_integer_value_as_float)
    end

    it "new(BigRational)" do
      bigfloat_on_bigrational_value = BigFloat.new(BigRational.new(1, 3))
      bigfloat_on_bigrational_value.should eq(BigFloat.new(1) / BigFloat.new(3))
    end

    it "new(BigFloat)" do
      BigFloat.new(bigfloat_of_integer_value).should eq(bigfloat_of_integer_value)
      BigFloat.new(bigfloat_of_float_value).should eq(bigfloat_of_float_value)
    end

    it "new(Int)" do
      BigFloat.new(1_u8).to_s.should eq("1.0")
      BigFloat.new(1_u16).to_s.should eq("1.0")
      BigFloat.new(1_u32).to_s.should eq("1.0")
      BigFloat.new(1_u64).to_s.should eq("1.0")
      BigFloat.new(1_i8).to_s.should eq("1.0")
      BigFloat.new(1_i16).to_s.should eq("1.0")
      BigFloat.new(1_i32).to_s.should eq("1.0")
      BigFloat.new(1_i64).to_s.should eq("1.0")
      BigFloat.new(-1_i8).to_s.should eq("-1.0")
      BigFloat.new(-1_i16).to_s.should eq("-1.0")
      BigFloat.new(-1_i32).to_s.should eq("-1.0")
      BigFloat.new(-1_i64).to_s.should eq("-1.0")

      BigFloat.new(255_u8).to_s.should eq("255.0")
      BigFloat.new(65535_u16).to_s.should eq("65535.0")
      BigFloat.new(4294967295_u32).to_s.should eq("4294967295.0")
      BigFloat.new(18446744073709551615_u64).to_s.should eq("1.8446744073709551615e+19")
      BigFloat.new(127_i8).to_s.should eq("127.0")
      BigFloat.new(32767_i16).to_s.should eq("32767.0")
      BigFloat.new(2147483647_i32).to_s.should eq("2147483647.0")
      BigFloat.new(9223372036854775807_i64).to_s.should eq("9.223372036854775807e+18")
      BigFloat.new(-128_i8).to_s.should eq("-128.0")
      BigFloat.new(-32768_i16).to_s.should eq("-32768.0")
      BigFloat.new(-2147483648_i32).to_s.should eq("-2147483648.0")
      BigFloat.new(-9223372036854775808_i64).to_s.should eq("-9.223372036854775808e+18")
    end

    it "raises if creating from infinity" do
      expect_raises(ArgumentError, "Can only construct from a finite number") { BigFloat.new(Float32::INFINITY) }
      expect_raises(ArgumentError, "Can only construct from a finite number") { BigFloat.new(Float64::INFINITY) }
      expect_raises(ArgumentError, "Can only construct from a finite number") { BigFloat.new(Float32::INFINITY, precision: 128) }
      expect_raises(ArgumentError, "Can only construct from a finite number") { BigFloat.new(Float64::INFINITY, precision: 128) }
    end

    it "raises if creating from NaN" do
      expect_raises(ArgumentError, "Can only construct from a finite number") { BigFloat.new(Float32::NAN) }
      expect_raises(ArgumentError, "Can only construct from a finite number") { BigFloat.new(Float64::NAN) }
      expect_raises(ArgumentError, "Can only construct from a finite number") { BigFloat.new(Float32::NAN, precision: 128) }
      expect_raises(ArgumentError, "Can only construct from a finite number") { BigFloat.new(Float64::NAN, precision: 128) }
    end
  end

  describe "#<=>" do
    it "compares against NaNs" do
      (1.to_big_f <=> Float64::NAN).should be_nil
      (1.to_big_f <=> Float32::NAN).should be_nil
      (Float64::NAN <=> 1.to_big_f).should be_nil
      (Float32::NAN <=> 1.to_big_f).should be_nil

      typeof(1.to_big_f <=> Float64::NAN).should eq(Int32?)
      typeof(1.to_big_f <=> Float32::NAN).should eq(Int32?)
      typeof(Float64::NAN <=> 1.to_big_f).should eq(Int32?)
      typeof(Float32::NAN <=> 1.to_big_f).should eq(Int32?)

      typeof(1.to_big_f <=> 1.to_big_f).should eq(Int32)
    end
  end

  describe "unary #-" do
    it do
      bf = "0.12345".to_big_f
      (-bf).to_s.should eq("-0.12345")
    end

    it do
      bf = "61397953.0005354".to_big_f
      (-bf).to_s.should eq("-61397953.0005354")
    end

    it do
      bf = "395.009631567315769036".to_big_f
      (-bf).to_s.should eq("-395.009631567315769036")
    end
  end

  describe "#+" do
    it { ("1.0".to_big_f + "2.0".to_big_f).to_s.should eq("3.0") }
    it { ("0.04".to_big_f + "89.0001".to_big_f).to_s.should eq("89.0401") }
    it { ("-5.5".to_big_f + "5.5".to_big_f).to_s.should eq("0.0") }
    it { ("5.5".to_big_f + "-5.5".to_big_f).to_s.should eq("0.0") }
  end

  describe "#-" do
    it { ("1.0".to_big_f - "2.0".to_big_f).to_s.should eq("-1.0") }
    it { ("0.04".to_big_f - "89.0001".to_big_f).to_s.should eq("-88.9601") }
    it { ("-5.5".to_big_f - "5.5".to_big_f).to_s.should eq("-11.0") }
    it { ("5.5".to_big_f - "-5.5".to_big_f).to_s.should eq("11.0") }
  end

  describe "#*" do
    it { ("1.0".to_big_f * "2.0".to_big_f).to_s.should eq("2.0") }
    it { ("0.04".to_big_f * "89.0001".to_big_f).to_s.should eq("3.560004") }
    it { ("-5.5".to_big_f * "5.5".to_big_f).to_s.should eq("-30.25") }
    it { ("5.5".to_big_f * "-5.5".to_big_f).to_s.should eq("-30.25") }
  end

  describe "#/" do
    it { ("1.0".to_big_f / "2.0".to_big_f).to_s.should eq("0.5") }
    it { ("0.04".to_big_f / "89.0001".to_big_f).to_s.should eq("0.000449437697261014313467") }
    it { ("-5.5".to_big_f / "5.5".to_big_f).to_s.should eq("-1.0") }
    it { ("5.5".to_big_f / "-5.5".to_big_f).to_s.should eq("-1.0") }
    expect_raises(DivisionByZeroError) { 0.1.to_big_f / 0 }
    it { ("5.5".to_big_f / 16_u64).to_s.should eq("0.34375") }
    it { ("5.5".to_big_f / 16_u8).to_s.should eq("0.34375") }
  end

  describe "#//" do
    it { ("1.0".to_big_f // "2.0".to_big_f).to_s.should eq("0.0") }
    it { ("0.04".to_big_f // "89.0001".to_big_f).to_s.should eq("0.0") }
    it { ("-5.5".to_big_f // "5.5".to_big_f).to_s.should eq("-1.0") }
    it { ("5.5".to_big_f // "-5.5".to_big_f).to_s.should eq("-1.0") }
    expect_raises(DivisionByZeroError) { 0.1.to_big_f // 0 }
    it { ("5.5".to_big_f // 16_u64).to_s.should eq("0.0") }
    it { ("5.5".to_big_f // 16_u8).to_s.should eq("0.0") }

    it { ("-1".to_big_f // 2_u8).to_s.should eq("-1.0") }
  end

  describe "#**" do
    it { ("1.34".to_big_f ** 2).should be_close("1.7956".to_big_f, 1e-12) }
    it { ("-0.05".to_big_f ** 10).should be_close("0.00000000000009765625".to_big_f, 1e-12) }
    it { (0.1234567890.to_big_f ** 3).should be_close("0.001881676371789154860897069".to_big_f, 1e-12) }
  end

  describe "#abs" do
    it { -5.to_big_f.abs.should eq(5) }
    it { 5.to_big_f.abs.should eq(5) }
    it { "-0.00001".to_big_f.abs.to_s.should eq("1.0e-5") }
    it { "0.00000000001".to_big_f.abs.to_s.should eq("1.0e-11") }
  end

  describe "#ceil" do
    it { 2.0.to_big_f.ceil.should eq(2) }
    it { 2.1.to_big_f.ceil.should eq(3) }
    it { 2.9.to_big_f.ceil.should eq(3) }
  end

  describe "#floor" do
    it { 2.1.to_big_f.floor.should eq(2) }
    it { 2.9.to_big_f.floor.should eq(2) }
    it { -2.9.to_big_f.floor.should eq(-3) }
  end

  describe "#trunc" do
    it { 2.1.to_big_f.trunc.should eq(2) }
    it { 2.9.to_big_f.trunc.should eq(2) }
    it { -2.9.to_big_f.trunc.should eq(-2) }
  end

  describe "#to_f" do
    it { 1.34.to_big_f.to_f.should eq(1.34) }
    it { 0.0001304.to_big_f.to_f.should eq(0.0001304) }
    it { 1.234567.to_big_f.to_f32.should eq(1.234567_f32) }
  end

  describe "#to_f!" do
    it { 1.34.to_big_f.to_f!.should eq(1.34) }
    it { 0.0001304.to_big_f.to_f!.should eq(0.0001304) }
    it { 1.234567.to_big_f.to_f32!.should eq(1.234567_f32) }
  end

  describe "#to_i" do
    it { 1.34.to_big_f.to_i.should eq(1) }
    it { 123.to_big_f.to_i.should eq(123) }
    it { -4321.to_big_f.to_i.should eq(-4321) }
  end

  describe "#to_i!" do
    it { 1.34.to_big_f.to_i!.should eq(1) }
    it { 123.to_big_f.to_i!.should eq(123) }
    it { -4321.to_big_f.to_i!.should eq(-4321) }
  end

  describe "#to_i64" do
    it "basic" do
      1.to_big_f.to_i64.should eq 1
      1.to_big_f.to_i64.should be_a(Int64)
    end

    it { expect_raises(OverflowError) { (2.0 ** 63).to_big_f.to_i64 } }
    it { expect_raises(OverflowError) { (BigFloat.new(2.0 ** 63, precision: 128) - 0.9999).to_i64 } }
    it { expect_raises(OverflowError) { (-9.223372036854778e+18).to_big_f.to_i64 } } # (-(2.0 ** 63)).prev_float
  end

  describe "#to_i64!" do
    it "basic" do
      1.to_big_f.to_i64!.should eq 1
      1.to_big_f.to_i64!.should be_a(Int64)
    end

    it "doesn't raise on overflow" do
      (2.0 ** 63).to_big_f.to_i64!
      (BigFloat.new(2.0 ** 63, precision: 128) - 0.9999).to_i64!
      (-9.223372036854778e+18).to_big_f.to_i64! # (-(2.0 ** 63)).prev_float
    end
  end

  describe "#to_u" do
    it { 1.34.to_big_f.to_u.should eq(1) }
    it { 123.to_big_f.to_u.should eq(123) }
    it { 4321.to_big_f.to_u.should eq(4321) }
    it do
      expect_raises(OverflowError) { -123.34.to_big_f.to_u }
    end
  end

  describe "#to_u!" do
    it { 1.34.to_big_f.to_u!.should eq(1) }
    it { 123.to_big_f.to_u!.should eq(123) }
    it { 4321.to_big_f.to_u!.should eq(4321) }
  end

  describe "#to_u64" do
    it "basic" do
      1.to_big_f.to_u64.should eq 1
      1.to_big_f.to_u64.should be_a(UInt64)
    end

    it { expect_raises(OverflowError) { (2.0 ** 64).to_big_f.to_u64 } }
    it { expect_raises(OverflowError) { (-1).to_big_f.to_u64 } }
    it { expect_raises(OverflowError) { (-0.0001).to_big_f.to_u64 } }
  end

  describe "#to_u64!" do
    it "basic" do
      1.to_big_f.to_u64!.should eq 1
      1.to_big_f.to_u64!.should be_a(UInt64)
    end

    it "doesn't raise on overflow" do
      (2.0 ** 64).to_big_f.to_u64!
      (-1).to_big_f.to_u64!
      (-0.0001).to_big_f.to_u64!
    end
  end

  describe "to_s" do
    it_converts_to_s "0".to_big_f, "0.0"
    it_converts_to_s "-0".to_big_f, "0.0"
    it_converts_to_s "0.000001".to_big_f, "1.0e-6"
    it_converts_to_s "48600000".to_big_f, "48600000.0"
    it_converts_to_s "12345678.87654".to_big_f, "12345678.87654"
    it_converts_to_s "12345678.87654321".to_big_f, "12345678.87654321"
    it_converts_to_s "9.000000000000987".to_big_f, "9.000000000000987"
    it_converts_to_s "12345678901234567".to_big_f, "1.2345678901234567e+16"
    it_converts_to_s "1234567890123456789".to_big_f, "1.234567890123456789e+18"

    it_converts_to_s ".01".to_big_f, "0.01"
    it_converts_to_s "-.01".to_big_f, "-0.01"
    it_converts_to_s ".1".to_big_f, "0.1"
    it_converts_to_s "-.1".to_big_f, "-0.1"
    it_converts_to_s "1".to_big_f, "1.0"
    it_converts_to_s "-1".to_big_f, "-1.0"
    it_converts_to_s "10".to_big_f, "10.0"
    it_converts_to_s "100".to_big_f, "100.0"
    it_converts_to_s "150".to_big_f, "150.0"

    it_converts_to_s (3.0).to_big_f, "3.0"
    it_converts_to_s 3.to_big_f, "3.0"
    it_converts_to_s -3.to_big_f, "-3.0"

    it_converts_to_s "1.23e45".to_big_f, "1.23e+45"
    it_converts_to_s "1e-234".to_big_f, "1.0e-234"

    it_converts_to_s Float64::MAX.to_s.to_big_f, "1.7976931348623157e+308"
    it_converts_to_s Float64::MIN_POSITIVE.to_s.to_big_f, "2.2250738585072014e-308"

    # since Float64-to-BigFloat conversion is always exact, but GMP floats have
    # a *minimum* precision equal to the machine word size, we cannot assume the
    # shortest round-trip property for Float64s converted this way
    it { assert_prints (0.1).to_big_f.to_s, "0.100000000000000005551" }
    it { assert_prints Float64::MAX.to_big_f.to_s, "1.79769313486231570815e+308" }
    it { assert_prints Float64::MIN_POSITIVE.to_big_f.to_s, "2.22507385850720138309e-308" }
  end

  describe "#inspect" do
    it { assert_prints "2.3".to_big_f.inspect, "2.3" }
  end

  describe "#round" do
    describe "rounding modes" do
      it "to_zero" do
        -1.5.to_big_f.round(:to_zero).should eq -1.0.to_big_f
        -1.0.to_big_f.round(:to_zero).should eq -1.0.to_big_f
        -0.9.to_big_f.round(:to_zero).should eq 0.0.to_big_f
        -0.5.to_big_f.round(:to_zero).should eq 0.0.to_big_f
        -0.1.to_big_f.round(:to_zero).should eq 0.0.to_big_f
        0.0.to_big_f.round(:to_zero).should eq 0.0.to_big_f
        0.1.to_big_f.round(:to_zero).should eq 0.0.to_big_f
        0.5.to_big_f.round(:to_zero).should eq 0.0.to_big_f
        0.9.to_big_f.round(:to_zero).should eq 0.0.to_big_f
        1.0.to_big_f.round(:to_zero).should eq 1.0.to_big_f
        1.5.to_big_f.round(:to_zero).should eq 1.0.to_big_f

        with_precision(256) do
          "123456789123456789123.0".to_big_f.round(:to_zero).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.1".to_big_f.round(:to_zero).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.5".to_big_f.round(:to_zero).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.9".to_big_f.round(:to_zero).should eq "123456789123456789123.0".to_big_f
          "123456789123456789124.0".to_big_f.round(:to_zero).should eq "123456789123456789124.0".to_big_f
          "-123456789123456789123.0".to_big_f.round(:to_zero).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.1".to_big_f.round(:to_zero).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.5".to_big_f.round(:to_zero).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.9".to_big_f.round(:to_zero).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789124.0".to_big_f.round(:to_zero).should eq "-123456789123456789124.0".to_big_f
        end
      end

      it "to_positive" do
        -1.5.to_big_f.round(:to_positive).should eq -1.0.to_big_f
        -1.0.to_big_f.round(:to_positive).should eq -1.0.to_big_f
        -0.9.to_big_f.round(:to_positive).should eq 0.0.to_big_f
        -0.5.to_big_f.round(:to_positive).should eq 0.0.to_big_f
        -0.1.to_big_f.round(:to_positive).should eq 0.0.to_big_f
        0.0.to_big_f.round(:to_positive).should eq 0.0.to_big_f
        0.1.to_big_f.round(:to_positive).should eq 1.0.to_big_f
        0.5.to_big_f.round(:to_positive).should eq 1.0.to_big_f
        0.9.to_big_f.round(:to_positive).should eq 1.0.to_big_f
        1.0.to_big_f.round(:to_positive).should eq 1.0.to_big_f
        1.5.to_big_f.round(:to_positive).should eq 2.0.to_big_f

        with_precision(256) do
          "123456789123456789123.0".to_big_f.round(:to_positive).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.1".to_big_f.round(:to_positive).should eq "123456789123456789124.0".to_big_f
          "123456789123456789123.5".to_big_f.round(:to_positive).should eq "123456789123456789124.0".to_big_f
          "123456789123456789123.9".to_big_f.round(:to_positive).should eq "123456789123456789124.0".to_big_f
          "123456789123456789124.0".to_big_f.round(:to_positive).should eq "123456789123456789124.0".to_big_f
          "-123456789123456789123.0".to_big_f.round(:to_positive).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.1".to_big_f.round(:to_positive).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.5".to_big_f.round(:to_positive).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.9".to_big_f.round(:to_positive).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789124.0".to_big_f.round(:to_positive).should eq "-123456789123456789124.0".to_big_f
        end
      end

      it "to_negative" do
        -1.5.to_big_f.round(:to_negative).should eq -2.0.to_big_f
        -1.0.to_big_f.round(:to_negative).should eq -1.0.to_big_f
        -0.9.to_big_f.round(:to_negative).should eq -1.0.to_big_f
        -0.5.to_big_f.round(:to_negative).should eq -1.0.to_big_f
        -0.1.to_big_f.round(:to_negative).should eq -1.0.to_big_f
        0.0.to_big_f.round(:to_negative).should eq 0.0.to_big_f
        0.1.to_big_f.round(:to_negative).should eq 0.0.to_big_f
        0.5.to_big_f.round(:to_negative).should eq 0.0.to_big_f
        0.9.to_big_f.round(:to_negative).should eq 0.0.to_big_f
        1.0.to_big_f.round(:to_negative).should eq 1.0.to_big_f
        1.5.to_big_f.round(:to_negative).should eq 1.0.to_big_f

        with_precision(256) do
          "123456789123456789123.0".to_big_f.round(:to_negative).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.1".to_big_f.round(:to_negative).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.5".to_big_f.round(:to_negative).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.9".to_big_f.round(:to_negative).should eq "123456789123456789123.0".to_big_f
          "123456789123456789124.0".to_big_f.round(:to_negative).should eq "123456789123456789124.0".to_big_f
          "-123456789123456789123.0".to_big_f.round(:to_negative).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.1".to_big_f.round(:to_negative).should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789123.5".to_big_f.round(:to_negative).should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789123.9".to_big_f.round(:to_negative).should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789124.0".to_big_f.round(:to_negative).should eq "-123456789123456789124.0".to_big_f
        end
      end

      it "ties_even" do
        -2.5.to_big_f.round(:ties_even).should eq -2.0.to_big_f
        -1.5.to_big_f.round(:ties_even).should eq -2.0.to_big_f
        -1.0.to_big_f.round(:ties_even).should eq -1.0.to_big_f
        -0.9.to_big_f.round(:ties_even).should eq -1.0.to_big_f
        -0.5.to_big_f.round(:ties_even).should eq 0.0.to_big_f
        -0.1.to_big_f.round(:ties_even).should eq 0.0.to_big_f
        0.0.to_big_f.round(:ties_even).should eq 0.0.to_big_f
        0.1.to_big_f.round(:ties_even).should eq 0.0.to_big_f
        0.5.to_big_f.round(:ties_even).should eq 0.0.to_big_f
        0.9.to_big_f.round(:ties_even).should eq 1.0.to_big_f
        1.0.to_big_f.round(:ties_even).should eq 1.0.to_big_f
        1.5.to_big_f.round(:ties_even).should eq 2.0.to_big_f
        2.5.to_big_f.round(:ties_even).should eq 2.0.to_big_f

        with_precision(256) do
          "123456789123456789123.0".to_big_f.round(:ties_even).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.1".to_big_f.round(:ties_even).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.5".to_big_f.round(:ties_even).should eq "123456789123456789124.0".to_big_f
          "123456789123456789123.9".to_big_f.round(:ties_even).should eq "123456789123456789124.0".to_big_f
          "123456789123456789124.0".to_big_f.round(:ties_even).should eq "123456789123456789124.0".to_big_f
          "123456789123456789124.5".to_big_f.round(:ties_even).should eq "123456789123456789124.0".to_big_f
          "-123456789123456789123.0".to_big_f.round(:ties_even).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.1".to_big_f.round(:ties_even).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.5".to_big_f.round(:ties_even).should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789123.9".to_big_f.round(:ties_even).should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789124.0".to_big_f.round(:ties_even).should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789124.5".to_big_f.round(:ties_even).should eq "-123456789123456789124.0".to_big_f
        end
      end

      it "ties_away" do
        -2.5.to_big_f.round(:ties_away).should eq -3.0.to_big_f
        -1.5.to_big_f.round(:ties_away).should eq -2.0.to_big_f
        -1.0.to_big_f.round(:ties_away).should eq -1.0.to_big_f
        -0.9.to_big_f.round(:ties_away).should eq -1.0.to_big_f
        -0.5.to_big_f.round(:ties_away).should eq -1.0.to_big_f
        -0.1.to_big_f.round(:ties_away).should eq 0.0.to_big_f
        0.0.to_big_f.round(:ties_away).should eq 0.0.to_big_f
        0.1.to_big_f.round(:ties_away).should eq 0.0.to_big_f
        0.5.to_big_f.round(:ties_away).should eq 1.0.to_big_f
        0.9.to_big_f.round(:ties_away).should eq 1.0.to_big_f
        1.0.to_big_f.round(:ties_away).should eq 1.0.to_big_f
        1.5.to_big_f.round(:ties_away).should eq 2.0.to_big_f
        2.5.to_big_f.round(:ties_away).should eq 3.0.to_big_f

        with_precision(256) do
          "123456789123456789123.0".to_big_f.round(:ties_away).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.1".to_big_f.round(:ties_away).should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.5".to_big_f.round(:ties_away).should eq "123456789123456789124.0".to_big_f
          "123456789123456789123.9".to_big_f.round(:ties_away).should eq "123456789123456789124.0".to_big_f
          "123456789123456789124.0".to_big_f.round(:ties_away).should eq "123456789123456789124.0".to_big_f
          "123456789123456789124.5".to_big_f.round(:ties_away).should eq "123456789123456789125.0".to_big_f
          "-123456789123456789123.0".to_big_f.round(:ties_away).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.1".to_big_f.round(:ties_away).should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.5".to_big_f.round(:ties_away).should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789123.9".to_big_f.round(:ties_away).should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789124.0".to_big_f.round(:ties_away).should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789124.5".to_big_f.round(:ties_away).should eq "-123456789123456789125.0".to_big_f
        end
      end

      it "default (=ties_even)" do
        -2.5.to_big_f.round.should eq -2.0.to_big_f
        -1.5.to_big_f.round.should eq -2.0.to_big_f
        -1.0.to_big_f.round.should eq -1.0.to_big_f
        -0.9.to_big_f.round.should eq -1.0.to_big_f
        -0.5.to_big_f.round.should eq 0.0.to_big_f
        -0.1.to_big_f.round.should eq 0.0.to_big_f
        0.0.to_big_f.round.should eq 0.0.to_big_f
        0.1.to_big_f.round.should eq 0.0.to_big_f
        0.5.to_big_f.round.should eq 0.0.to_big_f
        0.9.to_big_f.round.should eq 1.0.to_big_f
        1.0.to_big_f.round.should eq 1.0.to_big_f
        1.5.to_big_f.round.should eq 2.0.to_big_f
        2.5.to_big_f.round.should eq 2.0.to_big_f

        with_precision(256) do
          "123456789123456789123.0".to_big_f.round.should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.1".to_big_f.round.should eq "123456789123456789123.0".to_big_f
          "123456789123456789123.5".to_big_f.round.should eq "123456789123456789124.0".to_big_f
          "123456789123456789123.9".to_big_f.round.should eq "123456789123456789124.0".to_big_f
          "123456789123456789124.0".to_big_f.round.should eq "123456789123456789124.0".to_big_f
          "123456789123456789124.5".to_big_f.round.should eq "123456789123456789124.0".to_big_f
          "-123456789123456789123.0".to_big_f.round.should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.1".to_big_f.round.should eq "-123456789123456789123.0".to_big_f
          "-123456789123456789123.5".to_big_f.round.should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789123.9".to_big_f.round.should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789124.0".to_big_f.round.should eq "-123456789123456789124.0".to_big_f
          "-123456789123456789124.5".to_big_f.round.should eq "-123456789123456789124.0".to_big_f
        end
      end
    end
  end

  it "#hash" do
    b = 123.to_big_f
    b.hash.should eq(b.to_f64.hash)
  end

  it "clones" do
    x = 1.to_big_f
    x.clone.should eq(x)
  end
end

describe "BigFloat Math" do
  it ".frexp" do
    Math.frexp(0.2.to_big_f).should eq({0.8, -2})
  end

  it ".sqrt" do
    Math.sqrt(BigFloat.new("1" + "0"*48)).should eq(BigFloat.new("1" + "0"*24))
  end
end
