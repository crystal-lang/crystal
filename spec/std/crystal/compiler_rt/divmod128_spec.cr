require "spec"

# Specs ported from compiler-rt

private def test__divti3(a : Int128, b : Int128, expected : Int128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __divti3(a, b)
    actual.should eq(expected), file: file, line: line
  end
end

private def test__modti3(a : Int128, b : Int128, expected : Int128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __modti3(a, b)
    actual.should eq(expected), file: file, line: line
  end
end

private def test__udivti3(a : UInt128, b : UInt128, expected : UInt128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __udivti3(a, b)
    actual.should eq(expected), file: file, line: line
  end
end

private def test__umodti3(a : UInt128, b : UInt128, expected : UInt128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual = __umodti3(a, b)
    actual.should eq(expected), file: file, line: line
  end
end

private def test_u128_div_rem(a : UInt128, b : UInt128, expected_quo : UInt128, expected_rem : UInt128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual_quo, actual_rem = _u128_div_rem(a, b)
    actual_quo.should eq(expected_quo), file: file, line: line
    actual_rem.should eq(expected_rem), file: file, line: line
  end
end

# describe "_u128_div_rem" do
# # TODO (compiler-rt's specs are 15.4 MB big)
# end

describe "__divti3" do
  test__divti3(0_i128, 1_i128, 0_i128)
  test__divti3(0_i128, -1_i128, 0_i128)
  test__divti3(2_i128, 1_i128, 2_i128)
  test__divti3(2_i128, -1_i128, -2_i128)
  test__divti3(-2_i128, 1_i128, -2_i128)
  test__divti3(-2_i128, -1_i128, 2_i128)
  test__divti3(-170141183460469231731687303715884105728_i128, 1_i128, -170141183460469231731687303715884105728)
  test__divti3(-170141183460469231731687303715884105728_i128, -1_i128, -170141183460469231731687303715884105728)
  test__divti3(-170141183460469231731687303715884105728_i128, -2_i128, 85070591730234615865843651857942052864)
  test__divti3(-170141183460469231731687303715884105728_i128, 2_i128, -85070591730234615865843651857942052864)
end

describe "__modti3" do
  test__modti3(0_i128, 1_i128, 0_i128)
  test__modti3(0_i128, -1_i128, 0_i128)

  test__modti3(5_i128, 3_i128, 2_i128)
  test__modti3(5_i128, -3_i128, 2_i128)
  test__modti3(-5_i128, 3_i128, -2_i128)
  test__modti3(-5_i128, -3_i128, -2_i128)

  test__modti3(-170141183460469231731687303715884105728_i128, 1_i128, 0_i128)
  test__modti3(-170141183460469231731687303715884105728_i128, -1_i128, 0_i128)
  test__modti3(-170141183460469231731687303715884105728_i128, 2_i128, 0_i128)
  test__modti3(-170141183460469231731687303715884105728_i128, -2_i128, 0_i128)
  test__modti3(-170141183460469231731687303715884105728_i128, 3_i128, -2_i128)
  test__modti3(-170141183460469231731687303715884105728_i128, -3_i128, -2_i128)
end

describe "__udivti3" do
  test__udivti3(0_u128, 1_u128, 0_u128)
  test__udivti3(2_u128, 1_u128, 2_u128)

  test__udivti3(0x8000000000000000_u128, 1_u128, 0x8000000000000000_u128)
  test__udivti3(0x8000000000000000_u128, 2_u128, 0x4000000000000000_u128)
  test__udivti3(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, 2_u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128)
end

describe "__umodti3" do
  test__umodti3(0_u128, 1_u128, 0_u128)
  test__umodti3(2_u128, 1_u128, 0_u128)

  test__umodti3(0x8000000000000000_u128, 1_u128, 0_u128)
  test__umodti3(0x8000000000000000_u128, 2_u128, 0_u128)
  test__umodti3(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, 2_u128, 1_u128)
end
