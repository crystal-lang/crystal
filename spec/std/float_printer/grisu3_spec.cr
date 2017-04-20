require "spec"
require "float_printer/grisu3"
include FloatPrinter

private def test_grisu(v : UInt64)
  f = pointerof(v).as(Float64*).value
  test_grisu(f)
end

private def test_grisu(v : Float64)
  buffer = StaticArray(UInt8, 128).new(0_u8)
  status, decimal_exponent, length = Grisu3.grisu3(v, buffer.to_unsafe)
  point = decimal_exponent + length
  return status, point, String.new(buffer.to_unsafe)
end

describe "grisu3" do
  it "min float64" do
    status, point, str = test_grisu 5e-324
    status.should eq true
    str.should eq "5"
    point.should eq -323
  end

  it "max float64" do
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
