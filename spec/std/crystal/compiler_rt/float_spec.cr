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

  test__floattidf(0x80000080000000000000008000000000_u128.to_i128!, -hexfloat("0x1.FFFFFEp+126"))
  test__floattidf(0x80000000000008000000008000000000_u128.to_i128!, -hexfloat("0x1.FFFFFFFFFFFFEp+126"))
  test__floattidf(0x80000100000000000000008000000000_u128.to_i128!, -hexfloat("0x1.FFFFFCp+126"))
  test__floattidf(0x80000000000010000000008000000000_u128.to_i128!, -hexfloat("0x1.FFFFFFFFFFFFCp+126"))

  test__floattidf(0x80000000000000000000008000000000_u128.to_i128!, -hexfloat("0x1.000000p+127"))
  test__floattidf(0x80000000000000010000008000000000_u128.to_i128!, -hexfloat("0x1.000000p+127"))

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

  test__floattidf(0x023479FD0E092DC00000000000000000_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(0x023479FD0E092DA10000000000000001_u128, hexfloat("0x1.1A3CFE870496Dp+121"))
  test__floattidf(0x023479FD0E092DB00000000000000002_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(0x023479FD0E092DB80000000000000003_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(0x023479FD0E092DB60000000000000004_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(0x023479FD0E092DBF0000000000000005_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(0x023479FD0E092DC10000000000000006_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(0x023479FD0E092DC70000000000000007_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(0x023479FD0E092DC80000000000000008_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(0x023479FD0E092DCF0000000000000009_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(0x023479FD0E092DD00000000000000000_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floattidf(0x023479FD0E092DD1000000000000000B_u128, hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floattidf(0x023479FD0E092DD8000000000000000C_u128, hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floattidf(0x023479FD0E092DDF000000000000000D_u128, hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floattidf(0x023479FD0E092DE0000000000000000E_u128, hexfloat("0x1.1A3CFE870496Fp+121"))
end

describe "__floattisf" do
  test__floattisf(0, 0.0_f32)

  test__floattisf(1, 1.0_f32)
  test__floattisf(2, 2.0_f32)
  test__floattisf(-1, -1.0_f32)
  test__floattisf(-2, -2.0_f32)

  test__floattisf(0x7FFFFF8000000000_u64, hexfloat("0x1.FFFFFEp+62_f32"))
  test__floattisf(0x7FFFFF0000000000_u64, hexfloat("0x1.FFFFFCp+62_f32"))

  test__floattisf(0xFFFFFFFFFFFFFFFF8000008000000000_u128.to_i128!, hexfloat("-0x1.FFFFFEp+62_f32"))
  test__floattisf(0xFFFFFFFFFFFFFFFF8000010000000000_u128.to_i128!, hexfloat("-0x1.FFFFFCp+62_f32"))

  test__floattisf(0xFFFFFFFFFFFFFFFF8000000000000000_u128.to_i128!, hexfloat("-0x1.000000p+63_f32"))
  test__floattisf(0xFFFFFFFFFFFFFFFF8000000000000001_u128.to_i128!, hexfloat("-0x1.000000p+63_f32"))

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

  test__floattisf(0x0007FB72E80000000000000000000000_i128, hexfloat("0x1.FEDCBAp+114_f32"))

  test__floattisf(0x0007FB72EA0000000000000000000000_i128, hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(0x0007FB72EB0000000000000000000000_i128, hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(0x0007FB72EBFFFFFF0000000000000000_i128, hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(0x0007FB72EC0000000000000000000000_i128, hexfloat("0x1.FEDCBCp+114_f32"))
  test__floattisf(0x0007FB72E80000010000000000000000_i128, hexfloat("0x1.FEDCBAp+114_f32"))

  test__floattisf(0x0007FB72E60000000000000000000000_i128, hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(0x0007FB72E70000000000000000000000_i128, hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(0x0007FB72E7FFFFFF0000000000000000_i128, hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(0x0007FB72E40000010000000000000000_i128, hexfloat("0x1.FEDCBAp+114_f32"))
  test__floattisf(0x0007FB72E40000000000000000000000_i128, hexfloat("0x1.FEDCB8p+114_f32"))
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

  test__floatuntidf(0x80000080000000000000000000000000_u128, hexfloat("0x1.000001p+127"))
  test__floatuntidf(0x80000000000008000000000000000000_u128, hexfloat("0x1.0000000000001p+127"))
  test__floatuntidf(0x80000100000000000000000000000000_u128, hexfloat("0x1.000002p+127"))
  test__floatuntidf(0x80000000000010000000000000000000_u128, hexfloat("0x1.0000000000002p+127"))

  test__floatuntidf(0x80000000000000000000000000000000_u128, hexfloat("0x1.000000p+127"))
  test__floatuntidf(0x80000000000000010000000000000000_u128, hexfloat("0x1.0000000000000002p+127"))

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

  test__floatuntidf(0x023479FD0E092DC00000000000000000_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(0x023479FD0E092DA10000000000000001_u128, hexfloat("0x1.1A3CFE870496Dp+121"))
  test__floatuntidf(0x023479FD0E092DB00000000000000002_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(0x023479FD0E092DB80000000000000003_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(0x023479FD0E092DB60000000000000004_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(0x023479FD0E092DBF0000000000000005_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(0x023479FD0E092DC10000000000000006_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(0x023479FD0E092DC70000000000000007_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(0x023479FD0E092DC80000000000000008_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(0x023479FD0E092DCF0000000000000009_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(0x023479FD0E092DD00000000000000000_u128, hexfloat("0x1.1A3CFE870496Ep+121"))
  test__floatuntidf(0x023479FD0E092DD1000000000000000B_u128, hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floatuntidf(0x023479FD0E092DD8000000000000000C_u128, hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floatuntidf(0x023479FD0E092DDF000000000000000D_u128, hexfloat("0x1.1A3CFE870496Fp+121"))
  test__floatuntidf(0x023479FD0E092DE0000000000000000E_u128, hexfloat("0x1.1A3CFE870496Fp+121"))
end

describe "__floatuntisf" do
  test__floatuntisf(0, 0.0_f32)

  test__floatuntisf(1, 1.0_f32)
  test__floatuntisf(2, 2.0_f32)
  test__floatuntisf(20, 20.0_f32)

  test__floatuntisf(0x7FFFFF8000000000_u64, hexfloat("0x1.FFFFFEp+62_f32"))
  test__floatuntisf(0x7FFFFF0000000000_u64, hexfloat("0x1.FFFFFCp+62_f32"))

  test__floatuntisf(0x80000080000000000000000000000000_u128, hexfloat("0x1.000000p+127_f32")) # inexact hexfloat changed
  test__floatuntisf(0x80000000000008000000000000000000_u128, hexfloat("0x1.0p+127_f32"))
  test__floatuntisf(0x80000100000000000000000000000000_u128, hexfloat("0x1.000002p+127_f32"))

  test__floatuntisf(0x80000000000000000000000000000000_u128, hexfloat("0x1.000000p+127_f32"))

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

  test__floatuntisf(0x0000000000001FEDCB90000000000001_u128, hexfloat("0x1.FEDCBAp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBA0000000000000_u128, hexfloat("0x1.FEDCBAp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBAFFFFFFFFFFFFF_u128, hexfloat("0x1.FEDCBAp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBB0000000000000_u128, hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBB0000000000001_u128, hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBBFFFFFFFFFFFFF_u128, hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBC0000000000000_u128, hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBC0000000000001_u128, hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBD0000000000000_u128, hexfloat("0x1.FEDCBCp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBD0000000000001_u128, hexfloat("0x1.FEDCBEp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBDFFFFFFFFFFFFF_u128, hexfloat("0x1.FEDCBEp+76_f32"))
  test__floatuntisf(0x0000000000001FEDCBE0000000000000_u128, hexfloat("0x1.FEDCBEp+76_f32"))
end
