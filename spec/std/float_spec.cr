require "spec"
require "spec/helpers/string"

describe "Float" do
  describe "**" do
    it { (2.5_f32 ** 2_i32).should be_close(6.25_f32, 0.0001) }
    it { (2.5_f32 ** 2).should be_close(6.25_f32, 0.0001) }
    it { (2.5_f32 ** 2.5_f32).should be_close(9.882117688026186_f32, 0.0001) }
    it { (2.5_f32 ** 2.5).should be_close(9.882117688026186_f32, 0.0001) }
    it { (2.5_f64 ** 2_i32).should be_close(6.25_f64, 0.0001) }
    it { (2.5_f64 ** 2).should be_close(6.25_f64, 0.0001) }
    it { (2.5_f64 ** 2.5_f64).should be_close(9.882117688026186_f64, 0.0001) }
    it { (2.5_f64 ** 2.5).should be_close(9.882117688026186_f64, 0.001) }
  end

  describe "%" do
    it "uses modulo behavior, not remainder behavior" do
      ((-11.5) % 4.0).should eq(0.5)
    end
  end

  describe "modulo" do
    it "raises when mods by zero" do
      expect_raises(DivisionByZeroError) { 1.2.modulo 0.0 }
    end

    it { (13.0.modulo 4.0).should eq(1.0) }
    it { (13.0.modulo -4.0).should eq(-3.0) }
    it { (-13.0.modulo 4.0).should eq(3.0) }
    it { (-13.0.modulo -4.0).should eq(-1.0) }
    it { (11.5.modulo 4.0).should eq(3.5) }
    it { (11.5.modulo -4.0).should eq(-0.5) }
    it { (-11.5.modulo 4.0).should eq(0.5) }
    it { (-11.5.modulo -4.0).should eq(-3.5) }
  end

  describe "remainder" do
    it "raises when mods by zero" do
      expect_raises(DivisionByZeroError) { 1.2.remainder 0.0 }
    end

    it { (13.0.remainder 4.0).should eq(1.0) }
    it { (13.0.remainder -4.0).should eq(1.0) }
    it { (-13.0.remainder 4.0).should eq(-1.0) }
    it { (-13.0.remainder -4.0).should eq(-1.0) }
    it { (11.5.remainder 4.0).should eq(3.5) }
    it { (11.5.remainder -4.0).should eq(3.5) }
    it { (-11.5.remainder 4.0).should eq(-3.5) }
    it { (-11.5.remainder -4.0).should eq(-3.5) }

    it "preserves type" do
      r = 1.5_f32.remainder(1)
      typeof(r).should eq(Float32)
    end
  end

  describe "round" do
    it { 2.5.round.should eq(2) }
    it { 3.5.round.should eq(4) }
    it { 2.4.round.should eq(2) }
  end

  describe "floor" do
    it { 2.1.floor.should eq(2) }
    it { 2.9.floor.should eq(2) }
  end

  describe "ceil" do
    it { 2.0_f32.ceil.should eq(2) }
    it { 2.0.ceil.should eq(2) }

    it { 2.1_f32.ceil.should eq(3_f32) }
    it { 2.1.ceil.should eq(3) }

    it { 2.9_f32.ceil.should eq(3) }
    it { 2.9.ceil.should eq(3) }
  end

  describe "#integer?" do
    it { 1.0_f32.integer?.should be_true }
    it { 1.0_f64.integer?.should be_true }

    it { 1.2_f32.integer?.should be_false }
    it { 1.2_f64.integer?.should be_false }

    it { Float32::MAX.integer?.should be_true }
    it { Float64::MAX.integer?.should be_true }

    it { Float32::INFINITY.integer?.should be_false }
    it { Float64::INFINITY.integer?.should be_false }

    it { Float32::NAN.integer?.should be_false }
    it { Float64::NAN.integer?.should be_false }
  end

  describe "fdiv" do
    it { 1.0.fdiv(1).should eq 1.0 }
    it { 1.0.fdiv(2).should eq 0.5 }
    it { 1.0.fdiv(0.5).should eq 2.0 }
    it { 0.0.fdiv(1).should eq 0.0 }
    it { 1.0.fdiv(0).should eq 1.0/0.0 }
  end

  describe "divmod" do
    it { 1.2.divmod(0.3)[0].should eq(4) }
    it { 1.2.divmod(0.3)[1].should be_close(0.0, 0.00001) }

    it { 1.3.divmod(0.3)[0].should eq(4) }
    it { 1.3.divmod(0.3)[1].should be_close(0.1, 0.00001) }

    it { 1.4.divmod(0.3)[0].should eq(4) }
    it { 1.4.divmod(0.3)[1].should be_close(0.2, 0.00001) }

    it { -1.2.divmod(0.3)[0].should eq(-4) }
    it { -1.2.divmod(0.3)[1].should be_close(0.0, 0.00001) }

    it { -1.3.divmod(0.3)[0].should eq(-5) }
    it { -1.3.divmod(0.3)[1].should be_close(0.2, 0.00001) }

    it { -1.4.divmod(0.3)[0].should eq(-5) }
    it { -1.4.divmod(0.3)[1].should be_close(0.1, 0.00001) }

    it { 1.2.divmod(-0.3)[0].should eq(-4) }
    it { 1.2.divmod(-0.3)[1].should be_close(0.0, 0.00001) }

    it { 1.3.divmod(-0.3)[0].should eq(-5) }
    it { 1.3.divmod(-0.3)[1].should be_close(-0.2, 0.00001) }

    it { 1.4.divmod(-0.3)[0].should eq(-5) }
    it { 1.4.divmod(-0.3)[1].should be_close(-0.1, 0.00001) }

    it { -1.2.divmod(-0.3)[0].should eq(4) }
    it { -1.2.divmod(-0.3)[1].should be_close(0.0, 0.00001) }

    it { -1.3.divmod(-0.3)[0].should eq(4) }
    it { -1.3.divmod(-0.3)[1].should be_close(-0.1, 0.00001) }

    it { -1.4.divmod(-0.3)[0].should eq(4) }
    it { -1.4.divmod(-0.3)[1].should be_close(-0.2, 0.00001) }
  end

  describe "floor division //" do
    it "preserves type of lhs" do
      (7.0 // 2).should be_a(Float64)
      (7.0 // 2i32).should be_a(Float64)
      (7.0 // 2.0).should be_a(Float64)
      (7.0_f32 // 2.0_f64).should be_a(Float32)
      (7.0_f32 // 2.0_f32).should be_a(Float32)
    end

    it "applies floor" do
      (7.0 // 2.0).should eq(3.0)
      (-7.0 // 2.0).should eq(-4.0)

      (6.0 // 2.0).should eq(3.0)
      (-6.0 // 2.0).should eq(-3.0)

      (30.3 // 3.9).should eq(7.0)
    end
  end

  describe "#to_s" do
    it "does to_s for f64" do
      assert_prints 12.34.to_s, "12.34"
      assert_prints 1.2.to_s, "1.2"
      assert_prints 1.23.to_s, "1.23"
      assert_prints 1.234.to_s, "1.234"
      assert_prints 0.65000000000000002.to_s, "0.65"
      assert_prints 1.234001.to_s, "1.234001"
      assert_prints 1.23499.to_s, "1.23499"
      assert_prints 1.23499999999999999.to_s, "1.235"
      assert_prints 1.2345.to_s, "1.2345"
      assert_prints 1.23456.to_s, "1.23456"
      assert_prints 1.234567.to_s, "1.234567"
      assert_prints 1.2345678.to_s, "1.2345678"
      assert_prints 1.23456789.to_s, "1.23456789"
      assert_prints 1.234567891.to_s, "1.234567891"
      assert_prints 1.2345678911.to_s, "1.2345678911"
      assert_prints 1.2345678912.to_s, "1.2345678912"
      assert_prints 1.23456789123.to_s, "1.23456789123"
      assert_prints 9525365.25.to_s, "9525365.25"
      assert_prints 12.9999.to_s, "12.9999"
      assert_prints 12.9999999999999999.to_s, "13.0"
      assert_prints 1.0.to_s, "1.0"
      assert_prints 2e20.to_s, "2.0e+20"
      assert_prints 1e-10.to_s, "1.0e-10"
      assert_prints 1464132168.65.to_s, "1464132168.65"
      assert_prints 146413216.865.to_s, "146413216.865"
      assert_prints 14641321.6865.to_s, "14641321.6865"
      assert_prints 1464132.16865.to_s, "1464132.16865"
      assert_prints 654329382.1.to_s, "654329382.1"
      assert_prints 6543293824.1.to_s, "6543293824.1"
      assert_prints 65432938242.1.to_s, "65432938242.1"
      assert_prints 654329382423.1.to_s, "654329382423.1"
      assert_prints 6543293824234.1.to_s, "6543293824234.1"
      assert_prints 65432938242345.1.to_s, "65432938242345.1"
      assert_prints 65432.123e20.to_s, "6.5432123e+24"
      assert_prints 65432.123e200.to_s, "6.5432123e+204"
      assert_prints -65432.123e200.to_s, "-6.5432123e+204"
      assert_prints 65432.123456e20.to_s, "6.5432123456e+24"
      assert_prints 65432.1234567e20.to_s, "6.54321234567e+24"
      assert_prints 65432.12345678e20.to_s, "6.543212345678e+24"
      assert_prints 65432.1234567891e20.to_s, "6.54321234567891e+24"
      assert_prints (1.0/0.0).to_s, "Infinity"
      assert_prints (-1.0/0.0).to_s, "-Infinity"
      assert_prints (0.999999999999999989).to_s, "1.0"
    end

    it "does to_s for f32" do
      assert_prints 12.34_f32.to_s, "12.34"
      assert_prints 1.2_f32.to_s, "1.2"
      assert_prints 1.23_f32.to_s, "1.23"
      assert_prints 1.234_f32.to_s, "1.234"
      assert_prints 0.65000000000000002_f32.to_s, "0.65"
      # assert_prints 1.234001_f32.to_s, "1.234001"
      assert_prints 1.23499_f32.to_s, "1.23499"
      assert_prints 1.23499999999999_f32.to_s, "1.235"
      assert_prints 1.2345_f32.to_s, "1.2345"
      assert_prints 1.23456_f32.to_s, "1.23456"
      # assert_prints 9525365.25_f32.to_s, "9525365.25"
      assert_prints (1.0_f32/0.0_f32).to_s, "Infinity"
      assert_prints (-1.0_f32/0.0_f32).to_s, "-Infinity"
    end
  end

  describe "#next_float" do
    it "does for f64" do
      0.0.next_float.should eq(Float64::MIN_SUBNORMAL)
      1.0.next_float.should eq(1.0000000000000002)
      (-1.0).next_float.should eq(-0.9999999999999999)
      Float64::MAX.next_float.should eq(Float64::INFINITY)
      Float64::INFINITY.next_float.should eq(Float64::INFINITY)
      (-Float64::INFINITY).next_float.should eq(Float64::MIN)
      Float64::NAN.next_float.nan?.should be_true
    end

    it "does for f32" do
      0.0_f32.next_float.should eq(Float32::MIN_SUBNORMAL)
      1.0_f32.next_float.should eq(1.0000001_f32)
      (-1.0_f32).next_float.should eq(-0.99999994_f32)
      Float32::MAX.next_float.should eq(Float32::INFINITY)
      Float32::INFINITY.next_float.should eq(Float32::INFINITY)
      (-Float32::INFINITY).next_float.should eq(Float32::MIN)
      Float32::NAN.next_float.nan?.should be_true
    end
  end

  describe "#prev_float" do
    it "does for f64" do
      0.0.prev_float.should eq(-Float64::MIN_SUBNORMAL)
      1.0.prev_float.should eq(0.9999999999999999)
      (-1.0).prev_float.should eq(-1.0000000000000002)
      Float64::MIN.prev_float.should eq(-Float64::INFINITY)
      Float64::INFINITY.prev_float.should eq(Float64::MAX)
      (-Float64::INFINITY).prev_float.should eq(-Float64::INFINITY)
      Float64::NAN.prev_float.nan?.should be_true
    end

    it "does for f32" do
      0.0_f32.prev_float.should eq(-Float32::MIN_SUBNORMAL)
      1.0_f32.prev_float.should eq(0.99999994_f32)
      (-1.0_f32).prev_float.should eq(-1.0000001_f32)
      Float32::MIN.prev_float.should eq(-Float32::INFINITY)
      Float32::INFINITY.prev_float.should eq(Float32::MAX)
      (-Float32::INFINITY).prev_float.should eq(-Float32::INFINITY)
      Float32::NAN.prev_float.nan?.should be_true
    end
  end

  describe "#inspect" do
    it "does inspect for f64" do
      3.2.inspect.should eq("3.2")
    end

    it "does inspect for f32" do
      3.2_f32.inspect.should eq("3.2")
    end

    it "does inspect for f64 with IO" do
      str = String.build { |io| 3.2.inspect(io) }
      str.should eq("3.2")
    end

    it "does inspect for f32" do
      str = String.build { |io| 3.2_f32.inspect(io) }
      str.should eq("3.2")
    end
  end

  describe "hash" do
    it "does for Float32" do
      1.2_f32.hash.should eq(1.2_f32.hash)
    end

    it "does for Float64" do
      1.2.hash.should eq(1.2.hash)
    end
  end

  describe ".new" do
    it "String overload" do
      Float32.new("1").should be_a(Float32)
      Float32.new("1").should eq(1)
      expect_raises ArgumentError, %(Invalid Float32: " 1 ") do
        Float32.new(" 1 ", whitespace: false)
      end

      Float64.new("1").should be_a(Float64)
      Float64.new("1").should eq(1)
      expect_raises ArgumentError, %(Invalid Float64: " 1 ") do
        Float64.new(" 1 ", whitespace: false)
      end
    end

    it "fallback overload" do
      Float32.new(1_f64).should be_a(Float32)
      Float32.new(1_f64).should eq(1)

      Float64.new(1_f32).should be_a(Float64)
      Float64.new(1_f32).should eq(1)
    end
  end

  it "does nan?" do
    1.5.nan?.should be_false
    (0.0 / 0.0).nan?.should be_true
  end

  it "does infinite?" do
    (0.0).infinite?.should be_nil
    (-1.0/0.0).infinite?.should eq(-1)
    (1.0/0.0).infinite?.should eq(1)

    (0.0_f32).infinite?.should be_nil
    (-1.0_f32/0.0_f32).infinite?.should eq(-1)
    (1.0_f32/0.0_f32).infinite?.should eq(1)
  end

  it "does finite?" do
    0.0.finite?.should be_true
    1.5.finite?.should be_true
    (1.0/0.0).finite?.should be_false
    (-1.0/0.0).finite?.should be_false
    (-0.0/0.0).finite?.should be_false
  end

  {% if compare_versions(Crystal::VERSION, "0.36.1") > 0 %}
    it "converts infinity" do
      Float32::INFINITY.to_f64.infinite?.should eq 1
      Float32::INFINITY.to_f32.infinite?.should eq 1
      expect_raises(OverflowError) { Float32::INFINITY.to_i }
      (-Float32::INFINITY).to_f64.infinite?.should eq -1
      (-Float32::INFINITY).to_f32.infinite?.should eq -1
      expect_raises(OverflowError) { (-Float32::INFINITY).to_i }

      Float64::INFINITY.to_f64.infinite?.should eq 1
      Float64::INFINITY.to_f32.infinite?.should eq 1
      expect_raises(OverflowError) { Float64::INFINITY.to_i }
      (-Float64::INFINITY).to_f64.infinite?.should eq -1
      (-Float64::INFINITY).to_f32.infinite?.should eq -1
      expect_raises(OverflowError) { (-Float64::INFINITY).to_i }
    end
  {% else %}
    pending "converts infinity"
  {% end %}

  it "does unary -" do
    f = -(1.5)
    f.should eq(-1.5)
    f.should be_a(Float64)

    f = -(1.5_f32)
    f.should eq(-1.5_f32)
    f.should be_a(Float32)
  end

  it "clones" do
    1.0.clone.should eq(1.0)
    1.0_f32.clone.should eq(1.0_f32)
  end

  it "constants have right binary value" do
    Float32::MIN.unsafe_as(UInt32).should eq 0xff7fffff_u32
    Float32::MAX.unsafe_as(UInt32).should eq 0x7f7fffff_u32
    Float32::EPSILON.unsafe_as(UInt32).should eq 0x34000000_u32
    Float32::MIN_POSITIVE.unsafe_as(UInt32).should eq 0x00800000_u32

    Float64::MIN.unsafe_as(UInt64).should eq 0xffefffffffffffff_u64
    Float64::MAX.unsafe_as(UInt64).should eq 0x7fefffffffffffff_u64
    Float64::EPSILON.unsafe_as(UInt64).should eq 0x3cb0000000000000_u64
    Float64::MIN_POSITIVE.unsafe_as(UInt64).should eq 0x0010000000000000_u64
  end

  it "returns nil in <=> for NaN values (Float32)" do
    nan = Float32::NAN

    (1_f32 <=> nan).should be_nil
    (1_f64 <=> nan).should be_nil

    (1_u8 <=> nan).should be_nil
    (1_u16 <=> nan).should be_nil
    (1_u32 <=> nan).should be_nil
    (1_u64 <=> nan).should be_nil
    (1_i8 <=> nan).should be_nil
    (1_i16 <=> nan).should be_nil
    (1_i32 <=> nan).should be_nil
    (1_i64 <=> nan).should be_nil

    (nan <=> 1_u8).should be_nil
    (nan <=> 1_u16).should be_nil
    (nan <=> 1_u32).should be_nil
    (nan <=> 1_u64).should be_nil
    (nan <=> 1_i8).should be_nil
    (nan <=> 1_i16).should be_nil
    (nan <=> 1_i32).should be_nil
    (nan <=> 1_i64).should be_nil
  end

  it "returns nil in <=> for NaN values (Float64)" do
    nan = Float64::NAN

    (1_f32 <=> nan).should be_nil
    (1_f64 <=> nan).should be_nil

    (1_u8 <=> nan).should be_nil
    (1_u16 <=> nan).should be_nil
    (1_u32 <=> nan).should be_nil
    (1_u64 <=> nan).should be_nil
    (1_i8 <=> nan).should be_nil
    (1_i16 <=> nan).should be_nil
    (1_i32 <=> nan).should be_nil
    (1_i64 <=> nan).should be_nil

    (nan <=> 1_u8).should be_nil
    (nan <=> 1_u16).should be_nil
    (nan <=> 1_u32).should be_nil
    (nan <=> 1_u64).should be_nil
    (nan <=> 1_i8).should be_nil
    (nan <=> 1_i16).should be_nil
    (nan <=> 1_i32).should be_nil
    (nan <=> 1_i64).should be_nil
  end

  it "#abs" do
    0.0_f64.abs.sign_bit.should eq 1
    -0.0_f64.abs.sign_bit.should eq 1

    0.1_f64.abs.should eq 0.1_f64
    -0.1_f64.abs.should eq 0.1_f64

    0.0_f32.abs.sign_bit.should eq 1_f32
    -0.0_f32.abs.sign_bit.should eq 1_f32

    0.1_f32.abs.should eq 0.1_f32
    -0.1_f32.abs.should eq 0.1_f32

    Float64::MAX.abs.should eq Float64::MAX
    Float64::MIN.abs.should eq -Float64::MIN
    Float64::INFINITY.abs.should eq Float64::INFINITY
    (-Float64::INFINITY).abs.should eq Float64::INFINITY

    Float32::MAX.abs.should eq Float32::MAX
    Float32::MIN.abs.should eq -Float32::MIN
    Float32::INFINITY.abs.should eq Float32::INFINITY
    (-Float32::INFINITY).abs.should eq Float32::INFINITY
  end

  it "#sign_bit" do
    1.2_f64.sign_bit.should eq(1)
    -1.2_f64.sign_bit.should eq(-1)
    0.0_f64.sign_bit.should eq(1)
    -0.0_f64.sign_bit.should eq(-1)
    Float64::INFINITY.sign_bit.should eq(1)
    (-Float64::INFINITY).sign_bit.should eq(-1)
    0x7ff0_0000_0000_0001_u64.unsafe_as(Float64).sign_bit.should eq(1)
    0xfff0_0000_0000_0001_u64.unsafe_as(Float64).sign_bit.should eq(-1)

    1.2_f32.sign_bit.should eq(1)
    -1.2_f32.sign_bit.should eq(-1)
    0.0_f32.sign_bit.should eq(1)
    -0.0_f32.sign_bit.should eq(-1)
    Float32::INFINITY.sign_bit.should eq(1)
    (-Float32::INFINITY).sign_bit.should eq(-1)
    0x7f80_0001_u32.unsafe_as(Float32).sign_bit.should eq(1)
    0xff80_0001_u32.unsafe_as(Float32).sign_bit.should eq(-1)
  end
end
