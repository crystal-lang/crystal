require "spec"
require "float_printer/grisu3"
include FloatPrinter

private def test_grisu(v : UInt64)
  test_grisu pointerof(v).as(Float64*).value
end

private def test_grisu(v : UInt32)
  test_grisu pointerof(v).as(Float32*).value
end

private def test_grisu(v : Float64 | Float32)
  buffer = StaticArray(UInt8, 128).new(0_u8)
  status, decimal_exponent, length = Grisu3.grisu3(v, buffer.to_unsafe)
  point = decimal_exponent + length
  return status, point, String.new(buffer.to_unsafe)
end

describe "grisu3" do
  context "float64" do
    it "min float" do
      status, point, str = test_grisu 5e-324
      status.should eq true
      str.should eq "5"
      point.should eq -323
    end

    it "max float" do
      status, point, str = test_grisu 1.7976931348623157e308
      status.should eq true
      str.should eq "17976931348623157"
      point.should eq 309
    end

    it "point at end" do
      status, point, str = test_grisu 4294967272.0
      status.should eq true
      str.should eq "4294967272"
      point.should eq 10
    end

    it "large number" do
      status, point, str = test_grisu 4.1855804968213567e298
      status.should eq true
      str.should eq "4185580496821357"
      point.should eq 299
    end

    it "small number" do
      status, point, str = test_grisu 5.5626846462680035e-309
      status.should eq true
      str.should eq "5562684646268003"
      point.should eq -308
    end

    it "another no point move" do
      status, point, str = test_grisu 2147483648.0
      status.should eq true
      str.should eq "2147483648"
      point.should eq 10
    end

    it "failure case" do
      # grisu should not be able to do this number
      # this number is reused to ensure the fallback works
      status, point, str = test_grisu 3.5844466002796428e+298
      status.should eq false
      str.should_not eq "35844466002796428"
    end

    it "smallest normal" do
      status, point, str = test_grisu 0x0010000000000000_u64
      status.should eq true
      str.should eq "22250738585072014"
      point.should eq -307
    end

    it "largest denormal" do
      status, point, str = test_grisu 0x000FFFFFFFFFFFFF_u64
      status.should eq true
      str.should eq "2225073858507201"
      point.should eq -307
    end
  end

  context "float32" do
    it "min" do
      status, point, str = test_grisu 1e-45_f32
      status.should eq true
      str.should eq "1"
      point.should eq -44
    end

    it "max" do
      status, point, str = test_grisu 3.4028234e38_f32
      status.should eq true
      str.should eq "34028235"
      point.should eq 39
    end

    it "general whole number, rounding" do
      status, point, str = test_grisu 4294967272.0_f32
      status.should eq true
      str.should eq "42949673"
      point.should eq 10
    end

    it "general whole number, rounding" do
      status, point, str = test_grisu 4294967272.0_f32
      status.should eq true
      str.should eq "42949673"
      point.should eq 10
    end

    it "large number, rounding" do
      status, point, str = test_grisu 3.32306998946228968226e35_f32
      status.should eq true
      str.should eq "332307"
      point.should eq 36
    end

    it "small number" do
      status, point, str = test_grisu 1.2341e-41_f32
      status.should eq true
      str.should eq "12341"
      point.should eq -40
    end

    it "general no rounding" do
      status, point, str = test_grisu 3.3554432e7_f32
      status.should eq true
      str.should eq "33554432"
      point.should eq 8
    end

    it "general with rounding up" do
      status, point, str = test_grisu 3.26494756798464e14_f32
      status.should eq true
      str.should eq "32649476"
      point.should eq 15
    end

    it "general with rounding down" do
      status, point, str = test_grisu 3.91132223637771935344e37_f32
      status.should eq true
      str.should eq "39113222"
      point.should eq 38
    end

    it "smallest normal" do
      status, point, str = test_grisu 0x00800000_u32
      status.should eq true
      str.should eq "11754944"
      point.should eq -37
    end

    it "largest denormal" do
      status, point, str = test_grisu 0x007FFFFF_u32
      status.should eq true
      str.should eq "11754942"
      point.should eq -37
    end
  end
end
