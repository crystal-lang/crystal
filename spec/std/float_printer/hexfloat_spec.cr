# This file contains test cases derived from Microsoft's STL:
# https://github.com/microsoft/STL/tree/main/tests/std/tests/P0067R5_charconv
#
# Original license:
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

require "spec"
require "spec/helpers/string"

private def assert_to_s(num : F, str, *, file = __FILE__, line = __LINE__) forall F
  assert_prints num.to_hexfloat, str, file: file, line: line
  if num.nan?
    F.parse_hexfloat(str).nan?.should be_true, file: file, line: line
  else
    F.parse_hexfloat(str).should eq(num), file: file, line: line
  end
end

private def assert_parse_error(type : F.class, str, err, *, file = __FILE__, line = __LINE__) forall F
  expect_raises ArgumentError, "Invalid hexfloat: #{err}", file: file, line: line do
    F.parse_hexfloat(str)
  end
  F.parse_hexfloat?(str).should be_nil, file: file, line: line
end

describe Float64 do
  describe ".parse_hexfloat" do
    it { Float64.parse_hexfloat("0x123p+0").should eq(291_f64) }
    it { Float64.parse_hexfloat("0x123.0p+0").should eq(291_f64) }
    it { Float64.parse_hexfloat("0x123p0").should eq(291_f64) }

    it { Float64.parse_hexfloat("0x123.p0").should eq(291_f64) }
    it { Float64.parse_hexfloat("0x.123p12").should eq(291_f64) }
    it { Float64.parse_hexfloat("0x123.456p7").should eq(37282.6875_f64) }

    it { Float64.parse_hexfloat("+0x123p+0").should eq(291_f64) }
    it { Float64.parse_hexfloat("-0x123p-0").should eq(-291_f64) }

    it { Float64.parse_hexfloat("0XABCDEFP+0").should eq(11259375_f64) }

    it { Float64.parse_hexfloat("0x1.000000000000a000p+0").should eq(1.0000000000000022) } # exact
    it { Float64.parse_hexfloat("0x1.000000000000a001p+0").should eq(1.0000000000000022) } # below midpoint, round down
    it { Float64.parse_hexfloat("0x1.000000000000a800p+0").should eq(1.0000000000000022) } # midpoint, round down to even
    it { Float64.parse_hexfloat("0x1.000000000000a801p+0").should eq(1.0000000000000024) } # above midpoint, round up
    it { Float64.parse_hexfloat("0x1.000000000000b000p+0").should eq(1.0000000000000024) } # exact
    it { Float64.parse_hexfloat("0x1.000000000000b001p+0").should eq(1.0000000000000024) } # below midpoint, round down
    it { Float64.parse_hexfloat("0x1.000000000000b800p+0").should eq(1.0000000000000027) } # midpoint, round up to even
    it { Float64.parse_hexfloat("0x1.000000000000b801p+0").should eq(1.0000000000000027) } # above midpoint, round up

    it { Float64.parse_hexfloat("0x1.00000000000020p+0").should eq(1.0000000000000004) } # exact
    it { Float64.parse_hexfloat("0x1.00000000000021p+0").should eq(1.0000000000000004) } # below midpoint, round down
    it { Float64.parse_hexfloat("0x1.00000000000028p+0").should eq(1.0000000000000004) } # midpoint, round down to even
    it { Float64.parse_hexfloat("0x1.00000000000029p+0").should eq(1.0000000000000007) } # above midpoint, round up
    it { Float64.parse_hexfloat("0x1.00000000000030p+0").should eq(1.0000000000000007) } # exact
    it { Float64.parse_hexfloat("0x1.00000000000031p+0").should eq(1.0000000000000007) } # below midpoint, round down
    it { Float64.parse_hexfloat("0x1.00000000000038p+0").should eq(1.0000000000000009) } # midpoint, round up to even
    it { Float64.parse_hexfloat("0x1.00000000000039p+0").should eq(1.0000000000000009) } # above midpoint, round up

    it { Float64.parse_hexfloat("0x1.000000000000a000000000000000000p+0").should eq(1.0000000000000022) } # exact
    it { Float64.parse_hexfloat("0x1.000000000000a000000000000000001p+0").should eq(1.0000000000000022) } # below midpoint, round down
    it { Float64.parse_hexfloat("0x1.000000000000a800000000000000000p+0").should eq(1.0000000000000022) } # midpoint, round down to even
    it { Float64.parse_hexfloat("0x1.000000000000a800000000000000001p+0").should eq(1.0000000000000024) } # above midpoint, round up
    it { Float64.parse_hexfloat("0x1.000000000000b000000000000000000p+0").should eq(1.0000000000000024) } # exact
    it { Float64.parse_hexfloat("0x1.000000000000b000000000000000001p+0").should eq(1.0000000000000024) } # below midpoint, round down
    it { Float64.parse_hexfloat("0x1.000000000000b800000000000000000p+0").should eq(1.0000000000000027) } # midpoint, round up to even
    it { Float64.parse_hexfloat("0x1.000000000000b800000000000000001p+0").should eq(1.0000000000000027) } # above midpoint, round up

    it { Float64.parse_hexfloat("0x1000000000000a0000000p+0").should eq(1.2089258196146319e+24) } # exact
    it { Float64.parse_hexfloat("0x1000000000000a0010000p+0").should eq(1.2089258196146319e+24) } # below midpoint, round down
    it { Float64.parse_hexfloat("0x1000000000000a8000000p+0").should eq(1.2089258196146319e+24) } # midpoint, round down to even
    it { Float64.parse_hexfloat("0x1000000000000a8010000p+0").should eq(1.208925819614632e+24) }  # above midpoint, round up
    it { Float64.parse_hexfloat("0x1000000000000b0000000p+0").should eq(1.208925819614632e+24) }  # exact
    it { Float64.parse_hexfloat("0x1000000000000b0010000p+0").should eq(1.208925819614632e+24) }  # below midpoint, round down
    it { Float64.parse_hexfloat("0x1000000000000b8000000p+0").should eq(1.2089258196146324e+24) } # midpoint, round up to even
    it { Float64.parse_hexfloat("0x1000000000000b8010000p+0").should eq(1.2089258196146324e+24) } # above midpoint, round up

    it { Float64.parse_hexfloat("0x.00000000000000001000000000000a000p+0").should eq(3.388131789017209e-21) }  # exact
    it { Float64.parse_hexfloat("0x.00000000000000001000000000000a001p+0").should eq(3.388131789017209e-21) }  # below midpoint, round down
    it { Float64.parse_hexfloat("0x.00000000000000001000000000000a800p+0").should eq(3.388131789017209e-21) }  # midpoint, round down to even
    it { Float64.parse_hexfloat("0x.00000000000000001000000000000a801p+0").should eq(3.38813178901721e-21) }   # above midpoint, round up
    it { Float64.parse_hexfloat("0x.00000000000000001000000000000b000p+0").should eq(3.38813178901721e-21) }   # exact
    it { Float64.parse_hexfloat("0x.00000000000000001000000000000b001p+0").should eq(3.38813178901721e-21) }   # below midpoint, round down
    it { Float64.parse_hexfloat("0x.00000000000000001000000000000b800p+0").should eq(3.3881317890172104e-21) } # midpoint, round up to even
    it { Float64.parse_hexfloat("0x.00000000000000001000000000000b801p+0").should eq(3.3881317890172104e-21) } # above midpoint, round up

    # https://www.exploringbinary.com/nondeterministic-floating-point-conversions-in-java/
    it { Float64.parse_hexfloat("0x0.0000008p-1022").should eq(6.63123685e-316) }

    describe "round-to-nearest, ties-to-even" do
      it { Float64.parse_hexfloat("0x0.00000000000008p-1022").should eq(0.0) }
      it { Float64.parse_hexfloat("0x0.00000000000008#{"0" * 1000}1p-1022").should eq(5.0e-324) }

      it { Float64.parse_hexfloat("0x0.ffffffffffffe8p-1022").should eq(2.2250738585072004e-308) }
      it { Float64.parse_hexfloat("0x0.ffffffffffffe8#{"0" * 1000}1p-1022").should eq(Float64::MIN_POSITIVE.prev_float) }

      it { Float64.parse_hexfloat("0x1.00000000000008p+0").should eq(1.0) }
      it { Float64.parse_hexfloat("0x1.00000000000008#{"0" * 1000}1p+0").should eq(1.0000000000000002) }

      it { Float64.parse_hexfloat("0x1.ffffffffffffe8p+0").should eq(1.9999999999999996) }
      it { Float64.parse_hexfloat("0x1.ffffffffffffe8#{"0" * 1000}1p+0").should eq(1.9999999999999998) }

      it { Float64.parse_hexfloat("0x1.00000000000008p+1023").should eq(8.98846567431158e307) }
      it { Float64.parse_hexfloat("0x1.00000000000008#{"0" * 1000}1p+1023").should eq(8.988465674311582e307) }

      it { Float64.parse_hexfloat("0x1.ffffffffffffe8p+1023").should eq(1.7976931348623155e308) }
      it { Float64.parse_hexfloat("0x1.ffffffffffffe8#{"0" * 1000}1p+1023").should eq(1.7976931348623157e308) }
    end

    describe "values close to zero" do
      it { Float64.parse_hexfloat("0x0.7p-1074").should eq(Float64.zero) }
      it { Float64.parse_hexfloat("0x0.8p-1074").should eq(Float64.zero) }
      it { Float64.parse_hexfloat("0x0.9p-1074").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x0.fp-1074").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x1.0p-1074").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x1.1p-1074").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x1.7p-1074").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x1.8p-1074").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0x1.9p-1074").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0x1.fp-1074").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0x2.0p-1074").should eq(Float64::MIN_SUBNORMAL * 2) }

      it { Float64.parse_hexfloat("0x0.fp-1075").should eq(Float64.zero) }
      it { Float64.parse_hexfloat("0x1.0p-1075").should eq(Float64.zero) }
      it { Float64.parse_hexfloat("0x1.1p-1075").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x1.fp-1075").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x2.0p-1075").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x2.1p-1075").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x2.fp-1075").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x3.0p-1075").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0x3.1p-1075").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0x3.fp-1075").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0x4.0p-1075").should eq(Float64::MIN_SUBNORMAL * 2) }

      it { Float64.parse_hexfloat("0x1.fp-1076").should eq(Float64.zero) }
      it { Float64.parse_hexfloat("0x2.0p-1076").should eq(Float64.zero) }
      it { Float64.parse_hexfloat("0x2.1p-1076").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x3.fp-1076").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x4.0p-1076").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x4.1p-1076").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x5.fp-1076").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x6.0p-1076").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0x6.1p-1076").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0x7.fp-1076").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0x8.0p-1076").should eq(Float64::MIN_SUBNORMAL * 2) }

      it { Float64.parse_hexfloat("0x3.fp-1077").should eq(Float64.zero) }
      it { Float64.parse_hexfloat("0x4.0p-1077").should eq(Float64.zero) }
      it { Float64.parse_hexfloat("0x4.1p-1077").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x7.fp-1077").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x8.0p-1077").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0x8.1p-1077").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0xb.fp-1077").should eq(Float64::MIN_SUBNORMAL) }
      it { Float64.parse_hexfloat("0xc.0p-1077").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0xc.1p-1077").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0xf.fp-1077").should eq(Float64::MIN_SUBNORMAL * 2) }
      it { Float64.parse_hexfloat("0x10.0p-1077").should eq(Float64::MIN_SUBNORMAL * 2) }
    end

    describe "values close to MIN_POSITIVE and MAX" do
      it { Float64.parse_hexfloat("0x0.fffffffffffffp-1022").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x1.0000000000000p-1022").should eq(Float64::MIN_POSITIVE) }

      it { Float64.parse_hexfloat("0x1.ffffffffffffep-1023").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x1.fffffffffffffp-1023").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x2.0000000000000p-1023").should eq(Float64::MIN_POSITIVE) }

      it { Float64.parse_hexfloat("0x3.ffffffffffffcp-1024").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffdp-1024").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffep-1024").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x3.fffffffffffffp-1024").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x4.0000000000000p-1024").should eq(Float64::MIN_POSITIVE) }

      it { Float64.parse_hexfloat("0x7.ffffffffffff8p-1025").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x7.ffffffffffff9p-1025").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffbp-1025").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffcp-1025").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffdp-1025").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffep-1025").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x7.fffffffffffffp-1025").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x8.0000000000000p-1025").should eq(Float64::MIN_POSITIVE) }

      it { Float64.parse_hexfloat("0x0.fffffffffffff0p-1022").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x0.fffffffffffff1p-1022").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x0.fffffffffffff7p-1022").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x0.fffffffffffff8p-1022").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x0.fffffffffffff9p-1022").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x0.fffffffffffffbp-1022").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x0.fffffffffffffcp-1022").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x0.fffffffffffffdp-1022").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x0.ffffffffffffffp-1022").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x1.00000000000000p-1022").should eq(Float64::MIN_POSITIVE) }

      it { Float64.parse_hexfloat("0x1.ffffffffffffe0p-1023").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x1.ffffffffffffe1p-1023").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x1.ffffffffffffefp-1023").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x1.fffffffffffff0p-1023").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x1.fffffffffffff1p-1023").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x1.fffffffffffff7p-1023").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x1.fffffffffffff8p-1023").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x1.fffffffffffff9p-1023").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x1.ffffffffffffffp-1023").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x2.00000000000000p-1023").should eq(Float64::MIN_POSITIVE) }

      it { Float64.parse_hexfloat("0x3.ffffffffffffc0p-1024").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffc1p-1024").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffdfp-1024").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffe0p-1024").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffe1p-1024").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffefp-1024").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x3.fffffffffffff0p-1024").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x3.fffffffffffff1p-1024").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffffp-1024").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x4.00000000000000p-1024").should eq(Float64::MIN_POSITIVE) }

      it { Float64.parse_hexfloat("0x7.ffffffffffff80p-1025").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x7.ffffffffffff81p-1025").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffbfp-1025").should eq(Float64::MIN_POSITIVE.prev_float) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffc0p-1025").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffc1p-1025").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffdfp-1025").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffe0p-1025").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffe1p-1025").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffffp-1025").should eq(Float64::MIN_POSITIVE) }
      it { Float64.parse_hexfloat("0x8.00000000000000p-1025").should eq(Float64::MIN_POSITIVE) }

      it { Float64.parse_hexfloat("0x1.fffffffffffffp+1023").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x2.0000000000000p+1023").should eq(Float64::INFINITY) }

      it { Float64.parse_hexfloat("0x3.ffffffffffffep+1022").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x3.fffffffffffffp+1022").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x4.0000000000000p+1022").should eq(Float64::INFINITY) }

      it { Float64.parse_hexfloat("0x7.ffffffffffffcp+1021").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffdp+1021").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffep+1021").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x7.fffffffffffffp+1021").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x8.0000000000000p+1021").should eq(Float64::INFINITY) }

      it { Float64.parse_hexfloat("0x0.fffffffffffff8p+1024").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x0.fffffffffffff9p+1024").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x0.fffffffffffffbp+1024").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x0.fffffffffffffcp+1024").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x0.fffffffffffffdp+1024").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x0.ffffffffffffffp+1024").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x1.00000000000000p+1024").should eq(Float64::INFINITY) }

      it { Float64.parse_hexfloat("0x1.fffffffffffff0p+1023").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x1.fffffffffffff1p+1023").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x1.fffffffffffff7p+1023").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x1.fffffffffffff8p+1023").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x1.fffffffffffff9p+1023").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x1.ffffffffffffffp+1023").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x2.00000000000000p+1023").should eq(Float64::INFINITY) }

      it { Float64.parse_hexfloat("0x3.ffffffffffffe0p+1022").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffe1p+1022").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffefp+1022").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x3.fffffffffffff0p+1022").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x3.fffffffffffff1p+1022").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x3.ffffffffffffffp+1022").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x4.00000000000000p+1022").should eq(Float64::INFINITY) }

      it { Float64.parse_hexfloat("0x7.ffffffffffffc0p+1021").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffc1p+1021").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffdfp+1021").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffe0p+1021").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffe1p+1021").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x7.ffffffffffffffp+1021").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x8.00000000000000p+1021").should eq(Float64::INFINITY) }

      it { Float64.parse_hexfloat("0x0.fffffffffffff80p+1024").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x0.fffffffffffff81p+1024").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x0.fffffffffffffbfp+1024").should eq(Float64::MAX) }
      it { Float64.parse_hexfloat("0x0.fffffffffffffc0p+1024").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x0.fffffffffffffc1p+1024").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x0.fffffffffffffffp+1024").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("0x1.000000000000000p+1024").should eq(Float64::INFINITY) }
    end

    describe "special cases" do
      it { Float64.parse_hexfloat("-0x0p+0").to_s.should eq("-0.0") } # sign bit must be negative

      it { Float64.parse_hexfloat("inf").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("INF").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("infinity").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("INFINITY").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("+Infinity").should eq(Float64::INFINITY) }
      it { Float64.parse_hexfloat("-iNF").should eq(-Float64::INFINITY) }

      it { Float64.parse_hexfloat("nan").nan?.should be_true }
      it { Float64.parse_hexfloat("NAN").nan?.should be_true }
      it { Float64.parse_hexfloat("+NaN").nan?.should be_true }
      it { Float64.parse_hexfloat("-nAn").nan?.should be_true }
    end

    describe "invalid hexfloats" do
      it { assert_parse_error Float64, "", "expected '0'" }
      it { assert_parse_error Float64, " ", "expected '0'" }
      it { assert_parse_error Float64, "1", "expected '0'" }
      it { assert_parse_error Float64, "0", "expected 'x' or 'X'" }
      it { assert_parse_error Float64, "01", "expected 'x' or 'X'" }
      it { assert_parse_error Float64, "0x", "expected at least one digit" }
      it { assert_parse_error Float64, "0x.", "expected at least one digit" }
      it { assert_parse_error Float64, "0xp", "expected at least one digit" }
      it { assert_parse_error Float64, "0x.p", "expected at least one digit" }
      it { assert_parse_error Float64, "0x1", "expected 'p' or 'P'" }
      it { assert_parse_error Float64, "0x1.", "expected 'p' or 'P'" }
      it { assert_parse_error Float64, "0x1.1", "expected 'p' or 'P'" }
      it { assert_parse_error Float64, "0x.1", "expected 'p' or 'P'" }
      it { assert_parse_error Float64, "0x1p", "empty exponent" }
      it { assert_parse_error Float64, "0x1p+", "empty exponent" }
      it { assert_parse_error Float64, "0x1p-", "empty exponent" }
      it { assert_parse_error Float64, "0x1p2147483648", "exponent overflow" }
      it { assert_parse_error Float64, "0x1p2147483650", "exponent overflow" }
      it { assert_parse_error Float64, "0x1p+2147483648", "exponent overflow" }
      it { assert_parse_error Float64, "0x1p+2147483650", "exponent overflow" }
      it { assert_parse_error Float64, "0x1p-2147483648", "exponent overflow" }
      it { assert_parse_error Float64, "0x1p-2147483650", "exponent overflow" }
      it { assert_parse_error Float64, "0x1p0 ", "trailing characters" }
      it { assert_parse_error Float64, "0x1p0_f32", "trailing characters" }
      it { assert_parse_error Float64, "0x1p0_f64", "trailing characters" }
      it { assert_parse_error Float64, "0x1p0f", "trailing characters" }
      it { assert_parse_error Float64, "NaN ", "expected '0'" }
      it { assert_parse_error Float64, "- Infinity", "expected '0'" }
    end
  end

  describe "#to_hexfloat" do
    describe "special cases" do
      it { assert_to_s 0.0, "0x0p+0" }
      it { assert_to_s -0.0, "-0x0p+0" }
      it { assert_to_s Float64::INFINITY, "Infinity" }
      it { assert_to_s -Float64::INFINITY, "-Infinity" }
      it { assert_to_s Float64::NAN, "NaN" }
      it { assert_to_s 1.447509765625, "0x1.729p+0" }
      it { assert_to_s -1.447509765625, "-0x1.729p+0" }
    end

    describe "corner cases" do
      it { assert_to_s 1.447265625, "0x1.728p+0" }                                   # instead of "2.e5p-1"
      it { assert_to_s Float64::MIN_SUBNORMAL, "0x0.0000000000001p-1022" }           # instead of "1p-1074"
      it { assert_to_s Float64::MIN_POSITIVE.prev_float, "0x0.fffffffffffffp-1022" } # max subnormal
      it { assert_to_s Float64::MIN_POSITIVE, "0x1p-1022" }                          # min normal
      it { assert_to_s Float64::MAX, "0x1.fffffffffffffp+1023" }                     # max normal
    end

    describe "exponents" do
      it { assert_to_s 1.8227805048890994e-304, "0x1p-1009" }
      it { assert_to_s 1.8665272370064378e-301, "0x1p-999" }
      it { assert_to_s 1.5777218104420236e-30, "0x1p-99" }
      it { assert_to_s 0.001953125, "0x1p-9" }
      it { assert_to_s 1.0, "0x1p+0" }
      it { assert_to_s 512.0, "0x1p+9" }
      it { assert_to_s 6.338253001141147e+29, "0x1p+99" }
      it { assert_to_s 5.357543035931337e+300, "0x1p+999" }
      it { assert_to_s 5.486124068793689e+303, "0x1p+1009" }
    end

    describe "hexits" do
      it { assert_to_s 1.0044444443192333, "0x1.01234567p+0" }
      it { assert_to_s 1.5377777775283903, "0x1.89abcdefp+0" }
    end

    describe "trimming" do
      it { assert_to_s 1.0000000000000022, "0x1.000000000000ap+0" }
      it { assert_to_s 1.0000000000000355, "0x1.00000000000ap+0" }
      it { assert_to_s 1.0000000000005684, "0x1.0000000000ap+0" }
      it { assert_to_s 1.000000000009095, "0x1.000000000ap+0" }
      it { assert_to_s 1.0000000001455192, "0x1.00000000ap+0" }
      it { assert_to_s 1.0000000023283064, "0x1.0000000ap+0" }
      it { assert_to_s 1.000000037252903, "0x1.000000ap+0" }
      it { assert_to_s 1.0000005960464478, "0x1.00000ap+0" }
      it { assert_to_s 1.000009536743164, "0x1.0000ap+0" }
      it { assert_to_s 1.000152587890625, "0x1.000ap+0" }
      it { assert_to_s 1.00244140625, "0x1.00ap+0" }
      it { assert_to_s 1.0390625, "0x1.0ap+0" }
      it { assert_to_s 1.625, "0x1.ap+0" }
      it { assert_to_s 1.0, "0x1p+0" }
    end
  end
end

describe Float32 do
  describe ".parse_hexfloat" do
    it { Float32.parse_hexfloat("0x123p+0").should eq(291_f32) }
    it { Float32.parse_hexfloat("0x123.0p+0").should eq(291_f32) }
    it { Float32.parse_hexfloat("0x123p0").should eq(291_f32) }

    it { Float32.parse_hexfloat("0x123.p0").should eq(291_f32) }
    it { Float32.parse_hexfloat("0x.123p12").should eq(291_f32) }
    it { Float32.parse_hexfloat("0x123.456p7").should eq(37282.6875_f32) }

    it { Float32.parse_hexfloat("+0x123p+0").should eq(291_f32) }
    it { Float32.parse_hexfloat("-0x123p-0").should eq(-291_f32) }

    it { Float32.parse_hexfloat("0XABCDEFP+0").should eq(11259375_f32) }

    it { Float32.parse_hexfloat("0x1.a0000400p+0").should eq(1.6250002_f32) } # exact
    it { Float32.parse_hexfloat("0x1.a0000401p+0").should eq(1.6250002_f32) } # below midpoint, round down
    it { Float32.parse_hexfloat("0x1.a0000500p+0").should eq(1.6250002_f32) } # midpoint, round down to even
    it { Float32.parse_hexfloat("0x1.a0000501p+0").should eq(1.6250004_f32) } # above midpoint, round up
    it { Float32.parse_hexfloat("0x1.a0000600p+0").should eq(1.6250004_f32) } # exact
    it { Float32.parse_hexfloat("0x1.a0000601p+0").should eq(1.6250004_f32) } # below midpoint, round down
    it { Float32.parse_hexfloat("0x1.a0000700p+0").should eq(1.6250005_f32) } # midpoint, round up to even
    it { Float32.parse_hexfloat("0x1.a0000701p+0").should eq(1.6250005_f32) } # above midpoint, round up

    it { Float32.parse_hexfloat("0x1.0000040p+0").should eq(1.0000002_f32) } # exact
    it { Float32.parse_hexfloat("0x1.0000041p+0").should eq(1.0000002_f32) } # below midpoint, round down
    it { Float32.parse_hexfloat("0x1.0000050p+0").should eq(1.0000002_f32) } # midpoint, round down to even
    it { Float32.parse_hexfloat("0x1.0000051p+0").should eq(1.0000004_f32) } # above midpoint, round up
    it { Float32.parse_hexfloat("0x1.0000060p+0").should eq(1.0000004_f32) } # exact
    it { Float32.parse_hexfloat("0x1.0000061p+0").should eq(1.0000004_f32) } # below midpoint, round down
    it { Float32.parse_hexfloat("0x1.0000070p+0").should eq(1.0000005_f32) } # midpoint, round up to even
    it { Float32.parse_hexfloat("0x1.0000071p+0").should eq(1.0000005_f32) } # above midpoint, round up

    it { Float32.parse_hexfloat("0x1.a0000400000000000000000p+0").should eq(1.6250002_f32) } # exact
    it { Float32.parse_hexfloat("0x1.a0000400000000000000001p+0").should eq(1.6250002_f32) } # below midpoint, round down
    it { Float32.parse_hexfloat("0x1.a0000500000000000000000p+0").should eq(1.6250002_f32) } # midpoint, round down to even
    it { Float32.parse_hexfloat("0x1.a0000500000000000000001p+0").should eq(1.6250004_f32) } # above midpoint, round up
    it { Float32.parse_hexfloat("0x1.a0000600000000000000000p+0").should eq(1.6250004_f32) } # exact
    it { Float32.parse_hexfloat("0x1.a0000600000000000000001p+0").should eq(1.6250004_f32) } # below midpoint, round down
    it { Float32.parse_hexfloat("0x1.a0000700000000000000000p+0").should eq(1.6250005_f32) } # midpoint, round up to even
    it { Float32.parse_hexfloat("0x1.a0000700000000000000001p+0").should eq(1.6250005_f32) } # above midpoint, round up

    it { Float32.parse_hexfloat("0x1a0000400000000000p+0").should eq(4.796154e+20_f32) }  # exact
    it { Float32.parse_hexfloat("0x1a0000401000000000p+0").should eq(4.796154e+20_f32) }  # below midpoint, round down
    it { Float32.parse_hexfloat("0x1a0000500000000000p+0").should eq(4.796154e+20_f32) }  # midpoint, round down to even
    it { Float32.parse_hexfloat("0x1a0000501000000000p+0").should eq(4.7961545e+20_f32) } # above midpoint, round up
    it { Float32.parse_hexfloat("0x1a0000600000000000p+0").should eq(4.7961545e+20_f32) } # exact
    it { Float32.parse_hexfloat("0x1a0000601000000000p+0").should eq(4.7961545e+20_f32) } # below midpoint, round down
    it { Float32.parse_hexfloat("0x1a0000700000000000p+0").should eq(4.796155e+20_f32) }  # midpoint, round up to even
    it { Float32.parse_hexfloat("0x1a0000701000000000p+0").should eq(4.796155e+20_f32) }  # above midpoint, round up

    it { Float32.parse_hexfloat("0x.00000000000000001a0000400p+0").should eq(5.505715e-21_f32) }  # exact
    it { Float32.parse_hexfloat("0x.00000000000000001a0000401p+0").should eq(5.505715e-21_f32) }  # below midpoint, round down
    it { Float32.parse_hexfloat("0x.00000000000000001a0000500p+0").should eq(5.505715e-21_f32) }  # midpoint, round down to even
    it { Float32.parse_hexfloat("0x.00000000000000001a0000501p+0").should eq(5.5057154e-21_f32) } # above midpoint, round up
    it { Float32.parse_hexfloat("0x.00000000000000001a0000600p+0").should eq(5.5057154e-21_f32) } # exact
    it { Float32.parse_hexfloat("0x.00000000000000001a0000601p+0").should eq(5.5057154e-21_f32) } # below midpoint, round down
    it { Float32.parse_hexfloat("0x.00000000000000001a0000700p+0").should eq(5.5057158e-21_f32) } # midpoint, round up to even
    it { Float32.parse_hexfloat("0x.00000000000000001a0000701p+0").should eq(5.5057158e-21_f32) } # above midpoint, round up

    describe "values close to zero" do
      it { Float32.parse_hexfloat("0x0.7p-149").should eq(Float32.zero) }
      it { Float32.parse_hexfloat("0x0.8p-149").should eq(Float32.zero) }
      it { Float32.parse_hexfloat("0x0.9p-149").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x0.fp-149").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x1.0p-149").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x1.1p-149").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x1.7p-149").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x1.8p-149").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0x1.9p-149").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0x1.fp-149").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0x2.0p-149").should eq(Float32::MIN_SUBNORMAL * 2) }

      it { Float32.parse_hexfloat("0x0.fp-150").should eq(Float32.zero) }
      it { Float32.parse_hexfloat("0x1.0p-150").should eq(Float32.zero) }
      it { Float32.parse_hexfloat("0x1.1p-150").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x1.fp-150").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x2.0p-150").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x2.1p-150").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x2.fp-150").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x3.0p-150").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0x3.1p-150").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0x3.fp-150").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0x4.0p-150").should eq(Float32::MIN_SUBNORMAL * 2) }

      it { Float32.parse_hexfloat("0x1.fp-151").should eq(Float32.zero) }
      it { Float32.parse_hexfloat("0x2.0p-151").should eq(Float32.zero) }
      it { Float32.parse_hexfloat("0x2.1p-151").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x3.fp-151").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x4.0p-151").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x4.1p-151").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x5.fp-151").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x6.0p-151").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0x6.1p-151").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0x7.fp-151").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0x8.0p-151").should eq(Float32::MIN_SUBNORMAL * 2) }

      it { Float32.parse_hexfloat("0x3.fp-152").should eq(Float32.zero) }
      it { Float32.parse_hexfloat("0x4.0p-152").should eq(Float32.zero) }
      it { Float32.parse_hexfloat("0x4.1p-152").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x7.fp-152").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x8.0p-152").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0x8.1p-152").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0xb.fp-152").should eq(Float32::MIN_SUBNORMAL) }
      it { Float32.parse_hexfloat("0xc.0p-152").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0xc.1p-152").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0xf.fp-152").should eq(Float32::MIN_SUBNORMAL * 2) }
      it { Float32.parse_hexfloat("0x10.0p-152").should eq(Float32::MIN_SUBNORMAL * 2) }
    end

    describe "values close to MIN_POSITIVE and MAX" do
      it { Float32.parse_hexfloat("0x7.fffffp-129").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x8.00000p-129").should eq(Float32::MIN_POSITIVE) }

      it { Float32.parse_hexfloat("0x0.fffffep-126").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x0.ffffffp-126").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x1.000000p-126").should eq(Float32::MIN_POSITIVE) }

      it { Float32.parse_hexfloat("0x1.fffffcp-127").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x1.fffffdp-127").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x1.fffffep-127").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x1.ffffffp-127").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x2.000000p-127").should eq(Float32::MIN_POSITIVE) }

      it { Float32.parse_hexfloat("0x3.fffff8p-128").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x3.fffff9p-128").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x3.fffffbp-128").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x3.fffffcp-128").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x3.fffffdp-128").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x3.fffffep-128").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x3.ffffffp-128").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x4.000000p-128").should eq(Float32::MIN_POSITIVE) }

      it { Float32.parse_hexfloat("0x7.fffff0p-129").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x7.fffff1p-129").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x7.fffff7p-129").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x7.fffff8p-129").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x7.fffff9p-129").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x7.fffffbp-129").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x7.fffffcp-129").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x7.fffffdp-129").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x7.ffffffp-129").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x8.000000p-129").should eq(Float32::MIN_POSITIVE) }

      it { Float32.parse_hexfloat("0x0.fffffe0p-126").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x0.fffffe1p-126").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x0.fffffefp-126").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x0.ffffff0p-126").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x0.ffffff1p-126").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x0.ffffff7p-126").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x0.ffffff8p-126").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x0.ffffff9p-126").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x0.fffffffp-126").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x1.0000000p-126").should eq(Float32::MIN_POSITIVE) }

      it { Float32.parse_hexfloat("0x1.fffffc0p-127").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x1.fffffc1p-127").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x1.fffffdfp-127").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x1.fffffe0p-127").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x1.fffffe1p-127").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x1.fffffefp-127").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x1.ffffff0p-127").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x1.ffffff1p-127").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x1.fffffffp-127").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x2.0000000p-127").should eq(Float32::MIN_POSITIVE) }

      it { Float32.parse_hexfloat("0x3.fffff80p-128").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x3.fffff81p-128").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x3.fffffbfp-128").should eq(Float32::MIN_POSITIVE.prev_float) }
      it { Float32.parse_hexfloat("0x3.fffffc0p-128").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x3.fffffc1p-128").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x3.fffffdfp-128").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x3.fffffe0p-128").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x3.fffffe1p-128").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x3.fffffffp-128").should eq(Float32::MIN_POSITIVE) }
      it { Float32.parse_hexfloat("0x4.0000000p-128").should eq(Float32::MIN_POSITIVE) }

      it { Float32.parse_hexfloat("0x0.ffffffp+128").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x1.000000p+128").should eq(Float32::INFINITY) }

      it { Float32.parse_hexfloat("0x1.fffffep+127").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x1.ffffffp+127").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x2.000000p+127").should eq(Float32::INFINITY) }

      it { Float32.parse_hexfloat("0x3.fffffcp+126").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x3.fffffdp+126").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x3.fffffep+126").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x3.ffffffp+126").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x4.000000p+126").should eq(Float32::INFINITY) }

      it { Float32.parse_hexfloat("0x7.fffff8p+125").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x7.fffff9p+125").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x7.fffffbp+125").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x7.fffffcp+125").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x7.fffffdp+125").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x7.ffffffp+125").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x8.000000p+125").should eq(Float32::INFINITY) }

      it { Float32.parse_hexfloat("0x0.ffffff0p+128").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x0.ffffff1p+128").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x0.ffffff7p+128").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x0.ffffff8p+128").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x0.ffffff9p+128").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x0.fffffffp+128").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x1.0000000p+128").should eq(Float32::INFINITY) }

      it { Float32.parse_hexfloat("0x1.fffffe0p+127").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x1.fffffe1p+127").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x1.fffffefp+127").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x1.ffffff0p+127").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x1.ffffff1p+127").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x1.fffffffp+127").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x2.0000000p+127").should eq(Float32::INFINITY) }

      it { Float32.parse_hexfloat("0x3.fffffc0p+126").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x3.fffffc1p+126").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x3.fffffdfp+126").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x3.fffffe0p+126").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x3.fffffe1p+126").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x3.fffffffp+126").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x4.0000000p+126").should eq(Float32::INFINITY) }

      it { Float32.parse_hexfloat("0x7.fffff80p+125").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x7.fffff81p+125").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x7.fffffbfp+125").should eq(Float32::MAX) }
      it { Float32.parse_hexfloat("0x7.fffffc0p+125").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x7.fffffc1p+125").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x7.fffffffp+125").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("0x8.0000000p+125").should eq(Float32::INFINITY) }
    end

    describe "special cases" do
      it { Float32.parse_hexfloat("-0x0p+0").to_s.should eq("-0.0") } # sign bit must be negative

      it { Float32.parse_hexfloat("inf").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("INF").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("infinity").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("INFINITY").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("+Infinity").should eq(Float32::INFINITY) }
      it { Float32.parse_hexfloat("-iNF").should eq(-Float32::INFINITY) }

      it { Float32.parse_hexfloat("nan").nan?.should be_true }
      it { Float32.parse_hexfloat("NAN").nan?.should be_true }
      it { Float32.parse_hexfloat("+NaN").nan?.should be_true }
      it { Float32.parse_hexfloat("-nAn").nan?.should be_true }
    end

    describe "invalid hexfloats" do
      it { assert_parse_error Float32, "", "expected '0'" }
      it { assert_parse_error Float32, " ", "expected '0'" }
      it { assert_parse_error Float32, "1", "expected '0'" }
      it { assert_parse_error Float32, "0", "expected 'x' or 'X'" }
      it { assert_parse_error Float32, "01", "expected 'x' or 'X'" }
      it { assert_parse_error Float32, "0x", "expected at least one digit" }
      it { assert_parse_error Float32, "0x.", "expected at least one digit" }
      it { assert_parse_error Float32, "0xp", "expected at least one digit" }
      it { assert_parse_error Float32, "0x.p", "expected at least one digit" }
      it { assert_parse_error Float32, "0x1", "expected 'p' or 'P'" }
      it { assert_parse_error Float32, "0x1.", "expected 'p' or 'P'" }
      it { assert_parse_error Float32, "0x1.1", "expected 'p' or 'P'" }
      it { assert_parse_error Float32, "0x.1", "expected 'p' or 'P'" }
      it { assert_parse_error Float32, "0x1p", "empty exponent" }
      it { assert_parse_error Float32, "0x1p+", "empty exponent" }
      it { assert_parse_error Float32, "0x1p-", "empty exponent" }
      it { assert_parse_error Float32, "0x1p2147483648", "exponent overflow" }
      it { assert_parse_error Float32, "0x1p2147483650", "exponent overflow" }
      it { assert_parse_error Float32, "0x1p+2147483648", "exponent overflow" }
      it { assert_parse_error Float32, "0x1p+2147483650", "exponent overflow" }
      it { assert_parse_error Float32, "0x1p-2147483648", "exponent overflow" }
      it { assert_parse_error Float32, "0x1p-2147483650", "exponent overflow" }
      it { assert_parse_error Float32, "0x1p0 ", "trailing characters" }
      it { assert_parse_error Float32, "0x1p0_f32", "trailing characters" }
      it { assert_parse_error Float32, "0x1p0_f64", "trailing characters" }
      it { assert_parse_error Float32, "0x1p0f", "trailing characters" }
      it { assert_parse_error Float32, "NaN ", "expected '0'" }
      it { assert_parse_error Float32, "- Infinity", "expected '0'" }
    end
  end

  describe "#to_hexfloat" do
    describe "special cases" do
      it { assert_to_s 0.0_f32, "0x0p+0" }
      it { assert_to_s -0.0_f32, "-0x0p+0" }
      it { assert_to_s Float32::INFINITY, "Infinity" }
      it { assert_to_s -Float32::INFINITY, "-Infinity" }
      it { assert_to_s Float32::NAN, "NaN" }
      it { assert_to_s 1.4475098_f32, "0x1.729p+0" }
      it { assert_to_s -1.4475098_f32, "-0x1.729p+0" }
    end

    describe "corner cases" do
      it { assert_to_s 1.4472656_f32, "0x1.728p+0" }                         # instead of "2.e5p-1"
      it { assert_to_s Float32::MIN_SUBNORMAL, "0x0.000002p-126" }           # instead of "1p-1074"
      it { assert_to_s Float32::MIN_POSITIVE.prev_float, "0x0.fffffep-126" } # max subnormal
      it { assert_to_s Float32::MIN_POSITIVE, "0x1p-126" }                   # min normal
      it { assert_to_s Float32::MAX, "0x1.fffffep+127" }                     # max normal
    end

    describe "exponents" do
      it { assert_to_s 1.540744e-33_f32, "0x1p-109" }
      it { assert_to_s 1.5777218e-30_f32, "0x1p-99" }
      it { assert_to_s 0.001953125_f32, "0x1p-9" }
      it { assert_to_s 1.0_f32, "0x1p+0" }
      it { assert_to_s 512.0_f32, "0x1p+9" }
      it { assert_to_s 6.338253e+29_f32, "0x1p+99" }
      it { assert_to_s 6.490371e+32_f32, "0x1p+109" }
    end

    describe "hexits" do
      it { assert_to_s 1.0044403_f32, "0x1.0123p+0" }
      it { assert_to_s 1.2711029_f32, "0x1.4567p+0" }
      it { assert_to_s 1.5377655_f32, "0x1.89abp+0" }
      it { assert_to_s 1.8044281_f32, "0x1.cdefp+0" }
    end

    describe "trimming" do
      it { assert_to_s 1.0000006_f32, "0x1.00000ap+0" }
      it { assert_to_s 1.0000095_f32, "0x1.0000ap+0" }
      it { assert_to_s 1.0001526_f32, "0x1.000ap+0" }
      it { assert_to_s 1.0390625_f32, "0x1.0ap+0" }
      it { assert_to_s 1.0024414_f32, "0x1.00ap+0" }
      it { assert_to_s 1.625_f32, "0x1.ap+0" }
      it { assert_to_s 1.0_f32, "0x1p+0" }
    end
  end
end
