require "spec"
require "../../../../src/crystal/compiler_rt/umodti3.cr"

# Ported from compiler-rt:test/builtins/Unit/umodti3_test.c

private def test__umodti3(a : UInt128, b : UInt128, expected : UInt128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __umodti3(a, b).should eq(expected), file, line
  end
end

private HEX_80000000000000000000000000000000 = StaticArray[0x8000000000000000, 0x0000000000000000_u64].unsafe_as(UInt128)
private HEX_FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF = StaticArray[0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF].unsafe_as(UInt128)

describe "__umodti3" do
  test__umodti3(0_u128, 1_u128, 0_u128)
  test__umodti3(2_u128, 1_u128, 0_u128)
  test__umodti3(HEX_80000000000000000000000000000000, 1_u128, 0_u128)
  test__umodti3(HEX_80000000000000000000000000000000, 2_u128, 0_u128)
  test__umodti3(HEX_FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 2_u128, 1_u128)
end
