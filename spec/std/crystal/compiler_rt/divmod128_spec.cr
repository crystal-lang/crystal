require "./spec_helper"

# Ported from:
# - https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/test/builtins/Unit/umodti3_test.c
# - https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/test/builtins/Unit/udivti3_test.c
# - https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/test/builtins/Unit/modti3_test.c
# - https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/test/builtins/Unit/divti3_test.c

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

describe "__divti3" do
  test__divti3(0, 1, 0)
  test__divti3(0, -1, 0)
  test__divti3(2, 1, 2)
  test__divti3(2, -1, -2)
  test__divti3(-2, 1, -2)
  test__divti3(-2, -1, 2)
  test__divti3(0x80000000000000000000000000000000_u128.to_i128!, 1, 0x80000000000000000000000000000000_u128.to_i128!)
  test__divti3(0x80000000000000000000000000000000_u128.to_i128!, -1, 0x80000000000000000000000000000000_u128.to_i128!)
  test__divti3(0x80000000000000000000000000000000_u128.to_i128!, -2, 0x40000000000000000000000000000000_i128)
  test__divti3(0x80000000000000000000000000000000_u128.to_i128!, 2, 0xC0000000000000000000000000000000_u128.to_i128!)
end

describe "__modti3" do
  test__modti3(0, 1, 0)
  test__modti3(0, -1, 0)

  test__modti3(5, 3, 2)
  test__modti3(5, -3, 2)
  test__modti3(-5, 3, -2)
  test__modti3(-5, -3, -2)

  test__modti3(0x80000000000000000000000000000000_u128.to_i128!, 1, 0)
  test__modti3(0x80000000000000000000000000000000_u128.to_i128!, -1, 0)
  test__modti3(0x80000000000000000000000000000000_u128.to_i128!, 2, 0)
  test__modti3(0x80000000000000000000000000000000_u128.to_i128!, -2, 0)
  test__modti3(0x80000000000000000000000000000000_u128.to_i128!, 3, -2)
  test__modti3(0x80000000000000000000000000000000_u128.to_i128!, -3, -2)
end

describe "__udivti3" do
  test__udivti3(0, 1, 0)
  test__udivti3(2, 1, 2)

  test__udivti3(0x08000000000000000_u128, 1, 0x08000000000000000_u128)
  test__udivti3(0x08000000000000000_u128, 2, 0x04000000000000000_u128)
  test__udivti3(0xffffffffffffffffffffffffffffffff_u128, 2, 0x7fffffffffffffffffffffffffffffff_u128)
end

describe "__umodti3" do
  test__umodti3(0, 1, 0)
  test__umodti3(2, 1, 0)

  test__umodti3(0x08000000000000000_u128, 1, 0)
  test__umodti3(0x08000000000000000_u128, 2, 0)
  test__umodti3(0xffffffffffffffffffffffffffffffff_u128, 2, 1)
end
