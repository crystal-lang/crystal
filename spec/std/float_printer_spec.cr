# The example numbers in these specs are ported from the C++
# "double-conversions" library. The following is their license:
#   Copyright 2012 the V8 project authors. All rights reserved.
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are
#   met:
#
#       * Redistributions of source code must retain the above copyright
#         notice, this list of conditions and the following disclaimer.
#       * Redistributions in binary form must reproduce the above
#         copyright notice, this list of conditions and the following
#         disclaimer in the documentation and/or other materials provided
#         with the distribution.
#       * Neither the name of Google Inc. nor the names of its
#         contributors may be used to endorse or promote products derived
#         from this software without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
require "spec"

private def float_to_s(v)
  String.build(22) do |buff|
    Float::Printer.print(v, buff)
  end
end

private def test_str(s, file = __FILE__, line = __LINE__)
  [s, "-#{s}"].each do |str|
    test_pair str.to_f64, str, file, line
  end
end

private def test_pair(v : UInt64, str, file = __FILE__, line = __LINE__)
  d = v.unsafe_as(Float64)
  test_pair(d, str, file, line)
end

private def test_pair(v : UInt32, str, file = __FILE__, line = __LINE__)
  d = v.unsafe_as(Float32)
  test_pair(d, str, file, line)
end

private def test_pair(v : Float64 | Float32, str, file = __FILE__, line = __LINE__)
  float_to_s(v).should eq(str), file, line
end

describe "#print Float64" do
  it { test_str "0.0" }

  it { test_str "Infinity" }

  it { test_pair 0x7ff8000000000000_u64, "NaN" }
  it { test_pair 0xfff8000000000000_u64, "-NaN" }

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

describe "#print Float32" do
  it { test_pair 0_f32, "0.0" }
  it { test_pair -0_f32, "-0.0" }
  it { test_pair Float32::INFINITY, "Infinity" }
  it { test_pair -Float32::INFINITY, "-Infinity" }
  it { test_pair 0x7fc00000_u32, "NaN" }
  it { test_pair 0xffc80000_u32, "-NaN" }
  it { test_pair 0.000001_f32, "1.0e-6" }
  it { test_pair -0.0001_f32, "-0.0001" }
  it { test_pair -0.00001_f32, "-1.0e-5" }
  it { test_pair -12345e23_f32, "-1.2345e+27" }
  it { test_pair 100000000000000.0_f32, "100000000000000.0" }
  it { test_pair 1000000000000000.0_f32, "1.0e+15" }
  it { test_pair 1111111111111111.0_f32, "1.1111111e+15" }
  it { test_pair -3.9292015898194142585311918e-10_f32, "-3.9292017e-10" }

  it "largest float" do
    test_pair 3.4028234e38_f32, "3.4028235e+38"
  end

  it "largest normal" do
    test_pair 0x7f7fffff_u32, "3.4028235e+38"
  end

  it "smallest positive normal" do
    test_pair 0x00800000_u32, "1.1754944e-38"
  end

  it "largest denormal" do
    test_pair 0x007fffff_u32, "1.1754942e-38"
  end

  it "smallest positive denormal" do
    test_pair 0x00000001_u32, "1.0e-45"
  end
end
