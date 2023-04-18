require "./spec_helper"

# Ported from https://github.com/llvm/llvm-project/tree/82b74363a943b570c4ee7799d5f3ee4b3e7163a5/compiler-rt/test/builtins/Unit

private def test__floattidf(a : Int128, expected : Float64, *, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __floattidf(a)
    actual.should eq(expected), file: file, line: line
  end
end

private def test__floattisf(a : Int128, expected : Float32, *, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __floattisf(a)
    actual.should eq(expected), file: file, line: line
  end
end

private def test__floatuntidf(a : UInt128, expected : Float64, *, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __floatuntidf(a)
    actual.should eq(expected), file: file, line: line
  end
end

private def test__floatuntisf(a : UInt128, expected : Float32, *, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __floatuntisf(a)
    actual.should eq(expected), file: file, line: line
  end
end

describe "__floattidf" do
  test__floattidf(0, 0.0)
  test__floattidf(1, 1.0)
  test__floattidf(2, 2.0)
  test__floattidf(20, 20.0)
  test__floattidf(-1, -1.0)
  test__floattidf(-2, -2.0)
  test__floattidf(-20, -20.0)

  test__floattidf(0x7FFFFF8000000000_u64, hexfloat("0x1.FFFFFEp+62"))
  test__floattidf(0x7FFFFFFFFFFFF800_u64, hexfloat("0x1.FFFFFFFFFFFFEp+62"))
  test__floattidf(0x7FFFFF0000000000_u64, hexfloat("0x1.FFFFFCp+62"))
  test__floattidf(0x7FFFFFFFFFFFF000_u64, hexfloat("0x1.FFFFFFFFFFFFCp+62"))

  test__floattidf(make_ti(0x8000008000000000_u64, 0), -hexfloat("0x1.FFFFFEp+126"))
  test__floattidf(make_ti(0x8000000000000800_u64, 0), -hexfloat("0x1.FFFFFFFFFFFFEp+126"))
  test__floattidf(make_ti(0x8000010000000000_u64, 0), -hexfloat("0x1.FFFFFCp+126"))
  test__floattidf(make_ti(0x8000000000001000_u64, 0), -hexfloat("0x1.FFFFFFFFFFFFCp+126"))

  test__floattidf(make_ti(0x8000000000000000_u64, 0), -hexfloat("0x1.000000p+127"))
  test__floattidf(make_ti(0x8000000000000001_u64, 0), -hexfloat("0x1.000000p+127"))

  test__floattidf(0x0007FB72E8000000_u64, hexfloat("0x1.FEDCBAp+50"))

  test__floattidf(0x0007FB72EA000000_u64, hexfloat("0x1.FEDCBA8p+50"))
  test__floattidf(0x0007FB72EB000000_u64, hexfloat("0x1.FEDCBACp+50"))
  test__floattidf(0x0007FB72EBFFFFFF_u64, hexfloat("0x1.FEDCBAFFFFFFCp+50"))
  test__floattidf(0x0007FB72EC000000_u64, hexfloat("0x1.FEDCBBp+50"))
  test__floattidf(0x0007FB72E8000001_u64, hexfloat("0x1.FEDCBA0000004p+50"))

  test__floattidf(0x0007FB72E6000000_u64, hexfloat("0x1.FEDCB98p+50"))
  test__floattidf(0x0007FB72E7000000_u64, hexfloat("0x1.FEDCB9Cp+50"))
  test__floattidf(0x0007FB72E7FFFFFF_u64, hexfloat("0x1.FEDCB9FFFFFFCp+50"))
  test__floattidf(0x0007FB72E4000001_u64, hexfloat("0x1.FEDCB90000004p+50"))
  test__floattidf(0x0007FB72E4000000_u64, hexfloat("0x1.FEDCB9p+50"))

  test__floattidf(0x023479FD0E092DC0_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floattidf(0x023479FD0E092DA1_u64, hexfloat("0x1.1A3CFE870496Dp+57"))
  test__floattidf(0x023479FD0E092DB0_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floattidf(0x023479FD0E092DB8_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floattidf(0x023479FD0E092DB6_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floattidf(0x023479FD0E092DBF_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floattidf(0x023479FD0E092DC1_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floattidf(0x023479FD0E092DC7_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floattidf(0x023479FD0E092DC8_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floattidf(0x023479FD0E092DCF_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floattidf(0x023479FD0E092DD0_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floattidf(0x023479FD0E092DD1_u64, hexfloat("0x1.1A3CFE870496Fp+57"))
  test__floattidf(0x023479FD0E092DD8_u64, hexfloat("0x1.1A3CFE870496Fp+57"))
  test__floattidf(0x023479FD0E092DDF_u64, hexfloat("0x1.1A3CFE870496Fp+57"))
  test__floattidf(0x023479FD0E092DE0_u64, hexfloat("0x1.1A3CFE870496Fp+57"))

  test__floattidf(make_ti(0x023479FD0E092DC0_u64, 0), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(make_ti(0x023479FD0E092DA1_u64, 1), hexfloat("0x1.1A3CFE870496Dp+121"))
  test__floattidf(make_ti(0x023479FD0E092DB0_u64, 2), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(make_ti(0x023479FD0E092DB8_u64, 3), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(make_ti(0x023479FD0E092DB6_u64, 4), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(make_ti(0x023479FD0E092DBF_u64, 5), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(make_ti(0x023479FD0E092DC1_u64, 6), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(make_ti(0x023479FD0E092DC7_u64, 7), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(make_ti(0x023479FD0E092DC8_u64, 8), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(make_ti(0x023479FD0E092DCF_u64, 9), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(make_ti(0x023479FD0E092DD0_u64, 0), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(make_ti(0x023479FD0E092DD1_u64, 11), hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floattidf(make_ti(0x023479FD0E092DD8_u64, 12), hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floattidf(make_ti(0x023479FD0E092DDF_u64, 13), hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floattidf(make_ti(0x023479FD0E092DE0_u64, 14), hexfloat("0x1.1A3CFE870496Fp+121"))
end

describe "__floattisf" do
  test__floattisf(0, 0.0_f32)

  test__floattisf(1, 1.0_f32)
  test__floattisf(2, 2.0_f32)
  test__floattisf(-1, -1.0_f32)
  test__floattisf(-2, -2.0_f32)

  test__floattisf(0x7FFFFF8000000000_u64, hexfloat("0x1.FFFFFEp+62_f32"))
  test__floattisf(0x7FFFFF0000000000_u64, hexfloat("0x1.FFFFFCp+62_f32"))

  test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF_u64, 0x8000008000000000_u64), hexfloat("-0x1.FFFFFEp+62_f32"))
  test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF_u64, 0x8000010000000000_u64), hexfloat("-0x1.FFFFFCp+62_f32"))

  test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF_u64, 0x8000000000000000_u64), hexfloat("-0x1.000000p+63_f32"))
  test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF_u64, 0x8000000000000001_u64), hexfloat("-0x1.000000p+63_f32"))

  test__floattisf(0x0007FB72E8000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))

  test__floattisf(0x0007FB72EA000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floattisf(0x0007FB72EB000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floattisf(0x0007FB72EBFFFFFF_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floattisf(0x0007FB72EC000000_u64, hexfloat("0x1.FEDCBCp+50_f32"))
  test__floattisf(0x0007FB72E8000001_u64, hexfloat("0x1.FEDCBAp+50_f32"))

  test__floattisf(0x0007FB72E6000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floattisf(0x0007FB72E7000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floattisf(0x0007FB72E7FFFFFF_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floattisf(0x0007FB72E4000001_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floattisf(0x0007FB72E4000000_u64, hexfloat("0x1.FEDCB8p+50_f32"))

  test__floattisf(make_ti(0x0007FB72E8000000_u64, 0), hexfloat("0x1.FEDCBAp+114_f32"))

  test__floattisf(make_ti(0x0007FB72EA000000_u64, 0), hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(make_ti(0x0007FB72EB000000_u64, 0), hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(make_ti(0x0007FB72EBFFFFFF_u64, 0), hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(make_ti(0x0007FB72EC000000_u64, 0), hexfloat("0x1.FEDCBCp+114_f32"))
  test__floattisf(make_ti(0x0007FB72E8000001_u64, 0), hexfloat("0x1.FEDCBAp+114_f32"))

  test__floattisf(make_ti(0x0007FB72E6000000_u64, 0), hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(make_ti(0x0007FB72E7000000_u64, 0), hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(make_ti(0x0007FB72E7FFFFFF_u64, 0), hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(make_ti(0x0007FB72E4000001_u64, 0), hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(make_ti(0x0007FB72E4000000_u64, 0), hexfloat("0x1.FEDCB8p+114_f32"))
end

describe "__floatuntidf" do
  test__floatuntidf(0, 0.0)

  test__floatuntidf(1, 1.0)
  test__floatuntidf(2, 2.0)
  test__floatuntidf(20, 20.0)

  test__floatuntidf(0x7FFFFF8000000000_u64, hexfloat("0x1.FFFFFEp+62"))
  test__floatuntidf(0x7FFFFFFFFFFFF800_u64, hexfloat("0x1.FFFFFFFFFFFFEp+62"))
  test__floatuntidf(0x7FFFFF0000000000_u64, hexfloat("0x1.FFFFFCp+62"))
  test__floatuntidf(0x7FFFFFFFFFFFF000_u64, hexfloat("0x1.FFFFFFFFFFFFCp+62"))

  test__floatuntidf(make_tu(0x8000008000000000_u64, 0), hexfloat("0x1.000001p+127"))
  test__floatuntidf(make_tu(0x8000000000000800_u64, 0), hexfloat("0x1.0000000000001p+127"))
  test__floatuntidf(make_tu(0x8000010000000000_u64, 0), hexfloat("0x1.000002p+127"))
  test__floatuntidf(make_tu(0x8000000000001000_u64, 0), hexfloat("0x1.0000000000002p+127"))

  test__floatuntidf(make_tu(0x8000000000000000_u64, 0), hexfloat("0x1.000000p+127"))
  test__floatuntidf(make_tu(0x8000000000000001_u64, 0), hexfloat("0x1.0000000000000002p+127"))

  test__floatuntidf(0x0007FB72E8000000_u64, hexfloat("0x1.FEDCBAp+50"))

  test__floatuntidf(0x0007FB72EA000000_u64, hexfloat("0x1.FEDCBA8p+50"))
  test__floatuntidf(0x0007FB72EB000000_u64, hexfloat("0x1.FEDCBACp+50"))
  test__floatuntidf(0x0007FB72EBFFFFFF_u64, hexfloat("0x1.FEDCBAFFFFFFCp+50"))
  test__floatuntidf(0x0007FB72EC000000_u64, hexfloat("0x1.FEDCBBp+50"))
  test__floatuntidf(0x0007FB72E8000001_u64, hexfloat("0x1.FEDCBA0000004p+50"))

  test__floatuntidf(0x0007FB72E6000000_u64, hexfloat("0x1.FEDCB98p+50"))
  test__floatuntidf(0x0007FB72E7000000_u64, hexfloat("0x1.FEDCB9Cp+50"))
  test__floatuntidf(0x0007FB72E7FFFFFF_u64, hexfloat("0x1.FEDCB9FFFFFFCp+50"))
  test__floatuntidf(0x0007FB72E4000001_u64, hexfloat("0x1.FEDCB90000004p+50"))
  test__floatuntidf(0x0007FB72E4000000_u64, hexfloat("0x1.FEDCB9p+50"))

  test__floatuntidf(0x023479FD0E092DC0_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floatuntidf(0x023479FD0E092DA1_u64, hexfloat("0x1.1A3CFE870496Dp+57"))
  test__floatuntidf(0x023479FD0E092DB0_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floatuntidf(0x023479FD0E092DB8_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floatuntidf(0x023479FD0E092DB6_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floatuntidf(0x023479FD0E092DBF_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floatuntidf(0x023479FD0E092DC1_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floatuntidf(0x023479FD0E092DC7_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floatuntidf(0x023479FD0E092DC8_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floatuntidf(0x023479FD0E092DCF_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floatuntidf(0x023479FD0E092DD0_u64, hexfloat("0x1.1A3CFE870496Ep+57"))
  test__floatuntidf(0x023479FD0E092DD1_u64, hexfloat("0x1.1A3CFE870496Fp+57"))
  test__floatuntidf(0x023479FD0E092DD8_u64, hexfloat("0x1.1A3CFE870496Fp+57"))
  test__floatuntidf(0x023479FD0E092DDF_u64, hexfloat("0x1.1A3CFE870496Fp+57"))
  test__floatuntidf(0x023479FD0E092DE0_u64, hexfloat("0x1.1A3CFE870496Fp+57"))

  test__floatuntidf(make_tu(0x023479FD0E092DC0_u64, 0), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DA1_u64, 1), hexfloat("0x1.1A3CFE870496Dp+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DB0_u64, 2), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DB8_u64, 3), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DB6_u64, 4), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DBF_u64, 5), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DC1_u64, 6), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DC7_u64, 7), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DC8_u64, 8), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DCF_u64, 9), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DD0_u64, 0), hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DD1_u64, 11), hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DD8_u64, 12), hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DDF_u64, 13), hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floatuntidf(make_tu(0x023479FD0E092DE0_u64, 14), hexfloat("0x1.1A3CFE870496Fp+121"))
end

describe "__floatuntisf" do
  test__floatuntisf(0, 0.0_f32)

  test__floatuntisf(1, 1.0_f32)
  test__floatuntisf(2, 2.0_f32)
  test__floatuntisf(20, 20.0_f32)

  test__floatuntisf(0x7FFFFF8000000000_u64, hexfloat("0x1.FFFFFEp+62_f32"))
  test__floatuntisf(0x7FFFFF0000000000_u64, hexfloat("0x1.FFFFFCp+62_f32"))

  test__floatuntisf(make_tu(0x8000008000000000_u64, 0), hexfloat("0x1.000000p+127_f32")) # inexact hexfloat changed
  test__floatuntisf(make_tu(0x8000000000000800_u64, 0), hexfloat("0x1.0p+127_f32"))
  test__floatuntisf(make_tu(0x8000010000000000_u64, 0), hexfloat("0x1.000002p+127_f32"))

  test__floatuntisf(make_tu(0x8000000000000000_u64, 0), hexfloat("0x1.000000p+127_f32"))

  test__floatuntisf(0x0007FB72E8000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))

  test__floatuntisf(0x0007FB72EA000000_u64, hexfloat("0x1.FEDCBAp+50_f32")) # inexact hexfloat changed
  test__floatuntisf(0x0007FB72EB000000_u64, hexfloat("0x1.FEDCBAp+50_f32")) # inexact hexfloat changed

  test__floatuntisf(0x0007FB72EC000000_u64, hexfloat("0x1.FEDCBCp+50_f32")) # inexact hexfloat changed

  test__floatuntisf(0x0007FB72E6000000_u64, hexfloat("0x1.FEDCBAp+50_f32")) # inexact hexfloat changed
  test__floatuntisf(0x0007FB72E7000000_u64, hexfloat("0x1.FEDCBAp+50_f32")) # inexact hexfloat changed
  test__floatuntisf(0x0007FB72E4000000_u64, hexfloat("0x1.FEDCB8p+50_f32")) # inexact hexfloat changed

  test__floatuntisf(0xFFFFFFFFFFFFFFFE_u64, hexfloat("0x1p+64_f32"))
  test__floatuntisf(0xFFFFFFFFFFFFFFFF_u64, hexfloat("0x1p+64_f32"))

  test__floatuntisf(0x0007FB72E8000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))

  test__floatuntisf(0x0007FB72EA000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floatuntisf(0x0007FB72EB000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floatuntisf(0x0007FB72EBFFFFFF_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floatuntisf(0x0007FB72EC000000_u64, hexfloat("0x1.FEDCBCp+50_f32"))
  test__floatuntisf(0x0007FB72E8000001_u64, hexfloat("0x1.FEDCBAp+50_f32"))

  test__floatuntisf(0x0007FB72E6000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floatuntisf(0x0007FB72E7000000_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floatuntisf(0x0007FB72E7FFFFFF_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floatuntisf(0x0007FB72E4000001_u64, hexfloat("0x1.FEDCBAp+50_f32"))
  test__floatuntisf(0x0007FB72E4000000_u64, hexfloat("0x1.FEDCB8p+50_f32"))

  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCB90000000000001_u64), hexfloat("0x1.FEDCBAp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBA0000000000000_u64), hexfloat("0x1.FEDCBAp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBAFFFFFFFFFFFFF_u64), hexfloat("0x1.FEDCBAp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBB0000000000000_u64), hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBB0000000000001_u64), hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBBFFFFFFFFFFFFF_u64), hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBC0000000000000_u64), hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBC0000000000001_u64), hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBD0000000000000_u64), hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBD0000000000001_u64), hexfloat("0x1.FEDCBEp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBDFFFFFFFFFFFFF_u64), hexfloat("0x1.FEDCBEp+76_f32"))
  test__floatuntisf(make_tu(0x0000000000001FED_u64, 0xCBE0000000000000_u64), hexfloat("0x1.FEDCBEp+76_f32"))
end
