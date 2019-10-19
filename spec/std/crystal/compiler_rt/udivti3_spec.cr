require "spec"
require "../../../../src/crystal/compiler_rt/udivti3.cr"

# Ported from compiler-rt:test/builtins/Unit/udivti3_test.c

private def test__udivti3(a : UInt128, b : UInt128, expected : UInt128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __udivti3(a, b).should eq(expected), file, line
  end
end

private HEX_80000000000000000000000000000000 = StaticArray[0x8000000000000000, 0x0000000000000000].unsafe_as(UInt128)
private HEX_40000000000000000000000000000000 = StaticArray[0x4000000000000000, 0x0000000000000000].unsafe_as(UInt128)
# private HEX_FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF = StaticArray[0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF].unsafe_as(UInt128)
private HEX_7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF = StaticArray[0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF].unsafe_as(UInt128)

describe "__udivti3" do
  test__udivti3(0_u128, 1_u128, 0_u128)
  test__udivti3(2_u128, 1_u128, 2_u128)
  test__udivti3(HEX_80000000000000000000000000000000, 1, HEX_80000000000000000000000000000000)
  # test__udivti3(HEX_80000000000000000000000000000000, 2, HEX_40000000000000000000000000000000)
  # test__udivti3(HEX_FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 2, HEX_7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
end
