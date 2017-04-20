require "spec"
require "float_printer"
include FloatPrinter

private def float_to_s(v)
  String.build(22) do |buff|
    FloatPrinter.to_s(v, buff)
  end
end

private def test_str(s, file = __FILE__, line = __LINE__)
  [s, "-#{s}"].each do |str|
    test_pair str.to_f64, str, file, line
  end
end

private def test_pair(v : UInt64, str, file = __FILE__, line = __LINE__)
  d = pointerof(v).as(Float64*).value
  test_pair(d, str, file, line)
end
private def test_pair(v : Float64, str, file = __FILE__, line = __LINE__)
  float_to_s(v).should eq(str), file, line
end

describe "to_s" do
  it { test_str "0.0" }

  it { test_str "Infinity" }

  it { test_str "NaN" }

  it { test_str "0.01" }
  it { test_str "0.1" }
  it { test_str "1.0" }
  it { test_str "1.2" }
  it { test_str "123.456" }

  it { test_str "1.0e+234" }
  it { test_str "1.1e+234" }
  it { test_str "1.0e-234" }

  it { test_str "111111111111111.0" }
  it { test_str "111111111111111.1" }

  it { test_pair 0.001, "0.001" }
  it { test_pair 0.0001, "0.0001" }
  it { test_pair 0.00001, "1.0e-5" }
  it { test_pair 0.000001, "1.0e-6" }
  it { test_pair -0.0001, "-0.0001" }
  it { test_pair -0.00001, "-1.0e-5" }
  it { test_pair -12345e23, "-1.2345e+27" }

  it { test_pair 10.0, "10.0" }
  it { test_pair 1100.0, "1100.0" }

  it { test_pair 100000000000000.0, "100000000000000.0" }
  it { test_pair 1000000000000000.0, "1.0e+15" }
  it { test_pair 1111111111111111.0, "1.111111111111111e+15" }

  it "min float64" do
    test_pair 5e-324, "5.0e-324"
  end

  it "max float64" do
    test_pair 1.7976931348623157e308, "1.7976931348623157e+308"
  end

  it "large number, rounded" do
    test_pair 4.1855804968213567e298, "4.185580496821357e+298"
  end

  it "small number, rounded" do
    test_pair 5.5626846462680035e-309, "5.562684646268003e-309"
  end

  it "falure case" do
    # grisu cannot do this number, so it should fall back to libc
    test_pair 3.5844466002796428e+298, "3.5844466002796428e+298"
  end

  it "smallest normal" do
    test_pair 0x0010000000000000_u64, "2.2250738585072014e-308"
  end

  it "largest denormal" do
    test_pair 0x000FFFFFFFFFFFFF_u64, "2.225073858507201e-308"
  end
end
