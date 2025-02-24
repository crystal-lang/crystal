require "./spec_helper"

# Ported from https://github.com/llvm/llvm-project/tree/82b74363a943b570c4ee7799d5f3ee4b3e7163a5/compiler-rt/test/builtins/Unit

private def test__fixdfti(a : Float64, expected : Int128, *, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __fixdfti(a)
    actual.should eq(expected), file: file, line: line
  end
end

private def test__fixsfti(a : Float32, expected : Int128, *, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __fixsfti(a)
    actual.should eq(expected), file: file, line: line
  end
end

private def test__fixunsdfti(a : Float64, expected : UInt128, *, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __fixunsdfti(a)
    actual.should eq(expected), file: file, line: line
  end
end

private def test__fixunssfti(a : Float32, expected : UInt128, *, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __fixunssfti(a)
    actual.should eq(expected), file: file, line: line
  end
end

describe "__fixdfti" do
  test__fixdfti(0.0, 0)

  test__fixdfti(0.5, 0)
  test__fixdfti(0.99, 0)
  test__fixdfti(1.0, 1)
  test__fixdfti(1.5, 1)
  test__fixdfti(1.99, 1)
  test__fixdfti(2.0, 2)
  test__fixdfti(2.01, 2)
  test__fixdfti(-0.5, 0)
  test__fixdfti(-0.99, 0)
  test__fixdfti(-1.0, -1)
  test__fixdfti(-1.5, -1)
  test__fixdfti(-1.99, -1)
  test__fixdfti(-2.0, -2)
  test__fixdfti(-2.01, -2)

  test__fixdfti(hexfloat("0x1.FFFFFEp+62"), 0x7FFFFF8000000000_u64)
  test__fixdfti(hexfloat("0x1.FFFFFCp+62"), 0x7FFFFF0000000000_u64)

  test__fixdfti(hexfloat("-0x1.FFFFFEp+62"), make_ti(0xFFFFFFFFFFFFFFFF_u64, 0x8000008000000000_u64))
  test__fixdfti(hexfloat("-0x1.FFFFFCp+62"), make_ti(0xFFFFFFFFFFFFFFFF_u64, 0x8000010000000000_u64))

  test__fixdfti(hexfloat("0x1.FFFFFFFFFFFFFp+62"), 0x7FFFFFFFFFFFFC00_u64)
  test__fixdfti(hexfloat("0x1.FFFFFFFFFFFFEp+62"), 0x7FFFFFFFFFFFF800_u64)

  test__fixdfti(hexfloat("-0x1.FFFFFFFFFFFFFp+62"), make_ti(0xFFFFFFFFFFFFFFFF_u64, 0x8000000000000400_u64))
  test__fixdfti(hexfloat("-0x1.FFFFFFFFFFFFEp+62"), make_ti(0xFFFFFFFFFFFFFFFF_u64, 0x8000000000000800_u64))

  test__fixdfti(hexfloat("0x1.FFFFFFFFFFFFFp+126"), make_ti(0x7FFFFFFFFFFFFC00_u64, 0))
  test__fixdfti(hexfloat("0x1.FFFFFFFFFFFFEp+126"), make_ti(0x7FFFFFFFFFFFF800_u64, 0))

  test__fixdfti(hexfloat("-0x1.FFFFFFFFFFFFFp+126"), make_ti(0x8000000000000400_u64, 0))
  test__fixdfti(hexfloat("-0x1.FFFFFFFFFFFFEp+126"), make_ti(0x8000000000000800_u64, 0))
end

describe "__fixsfti" do
  test__fixsfti(0.0_f32, 0)

  test__fixsfti(0.5_f32, 0)
  test__fixsfti(0.99_f32, 0)
  test__fixsfti(1.0_f32, 1)
  test__fixsfti(1.5_f32, 1)
  test__fixsfti(1.99_f32, 1)
  test__fixsfti(2.0_f32, 2)
  test__fixsfti(2.01_f32, 2)
  test__fixsfti(-0.5_f32, 0)
  test__fixsfti(-0.99_f32, 0)
  test__fixsfti(-1.0_f32, -1)
  test__fixsfti(-1.5_f32, -1)
  test__fixsfti(-1.99_f32, -1)
  test__fixsfti(-2.0_f32, -2)
  test__fixsfti(-2.01_f32, -2)

  test__fixsfti(hexfloat("0x1.FFFFFEp+62_f32"), 0x7FFFFF8000000000_u64)
  test__fixsfti(hexfloat("0x1.FFFFFCp+62_f32"), 0x7FFFFF0000000000_u64)

  test__fixsfti(hexfloat("-0x1.FFFFFEp+62_f32"), make_ti(0xFFFFFFFFFFFFFFFF_u64, 0x8000008000000000_u64))
  test__fixsfti(hexfloat("-0x1.FFFFFCp+62_f32"), make_ti(0xFFFFFFFFFFFFFFFF_u64, 0x8000010000000000_u64))

  test__fixsfti(hexfloat("0x1.FFFFFEp+126_f32"), make_ti(0x7FFFFF8000000000_u64, 0))
  test__fixsfti(hexfloat("0x1.FFFFFCp+126_f32"), make_ti(0x7FFFFF0000000000_u64, 0))

  test__fixsfti(hexfloat("-0x1.FFFFFEp+126_f32"), make_ti(0x8000008000000000_u64, 0))
  test__fixsfti(hexfloat("-0x1.FFFFFCp+126_f32"), make_ti(0x8000010000000000_u64, 0))
end

describe "__fixunsdfti" do
  test__fixunsdfti(0.0, 0)

  test__fixunsdfti(0.5, 0)
  test__fixunsdfti(0.99, 0)
  test__fixunsdfti(1.0, 1)
  test__fixunsdfti(1.5, 1)
  test__fixunsdfti(1.99, 1)
  test__fixunsdfti(2.0, 2)
  test__fixunsdfti(2.01, 2)
  test__fixunsdfti(-0.5, 0)
  test__fixunsdfti(-0.99, 0)

  test__fixunsdfti(hexfloat("0x1.FFFFFEp+62"), 0x7FFFFF8000000000_u64)
  test__fixunsdfti(hexfloat("0x1.FFFFFCp+62"), 0x7FFFFF0000000000_u64)

  test__fixunsdfti(hexfloat("0x1.FFFFFFFFFFFFFp+63"), 0xFFFFFFFFFFFFF800_u64)
  test__fixunsdfti(hexfloat("0x1.0000000000000p+63"), 0x8000000000000000_u64)
  test__fixunsdfti(hexfloat("0x1.FFFFFFFFFFFFFp+62"), 0x7FFFFFFFFFFFFC00_u64)
  test__fixunsdfti(hexfloat("0x1.FFFFFFFFFFFFEp+62"), 0x7FFFFFFFFFFFF800_u64)

  test__fixunsdfti(hexfloat("0x1.FFFFFFFFFFFFFp+127"), make_tu(0xFFFFFFFFFFFFF800_u64, 0))
  test__fixunsdfti(hexfloat("0x1.0000000000000p+127"), make_tu(0x8000000000000000_u64, 0))
  test__fixunsdfti(hexfloat("0x1.FFFFFFFFFFFFFp+126"), make_tu(0x7FFFFFFFFFFFFC00_u64, 0))
  test__fixunsdfti(hexfloat("0x1.FFFFFFFFFFFFEp+126"), make_tu(0x7FFFFFFFFFFFF800_u64, 0))
  test__fixunsdfti(hexfloat("0x1.0000000000000p+128"), make_tu(0xFFFFFFFFFFFFFFFF_u64, 0xFFFFFFFFFFFFFFFF_u64))
end

describe "__fixunssfti" do
  test__fixunssfti(0.0_f32, 0)

  test__fixunssfti(0.5_f32, 0)
  test__fixunssfti(0.99_f32, 0)
  test__fixunssfti(1.0_f32, 1)
  test__fixunssfti(1.5_f32, 1)
  test__fixunssfti(1.99_f32, 1)
  test__fixunssfti(2.0_f32, 2)
  test__fixunssfti(2.01_f32, 2)
  test__fixunssfti(-0.5_f32, 0)
  test__fixunssfti(-0.99_f32, 0)

  test__fixunssfti(hexfloat("0x1.FFFFFEp+63_f32"), 0xFFFFFF0000000000_u64)
  test__fixunssfti(hexfloat("0x1.000000p+63_f32"), 0x8000000000000000_u64)
  test__fixunssfti(hexfloat("0x1.FFFFFEp+62_f32"), 0x7FFFFF8000000000_u64)
  test__fixunssfti(hexfloat("0x1.FFFFFCp+62_f32"), 0x7FFFFF0000000000_u64)

  test__fixunssfti(hexfloat("0x1.FFFFFEp+127_f32"), make_tu(0xFFFFFF0000000000_u64, 0))
  test__fixunssfti(hexfloat("0x1.000000p+127_f32"), make_tu(0x8000000000000000_u64, 0))
  test__fixunssfti(hexfloat("0x1.FFFFFEp+126_f32"), make_tu(0x7FFFFF8000000000_u64, 0))
  test__fixunssfti(hexfloat("0x1.FFFFFCp+126_f32"), make_tu(0x7FFFFF0000000000_u64, 0))
end
