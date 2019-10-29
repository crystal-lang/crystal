require "spec"
require "../../../../src/crystal/compiler_rt/umodti3"

# Ported from compiler-rt:test/builtins/Unit/umodti3_test.c

private def test__umodti3(a : (UInt128 | UInt128RT), b : (UInt128 | UInt128RT), expected : (UInt128 | UInt128RT), file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __umodti3(a.to_u128, b.to_u128).should eq(expected.to_u128), file, line
  end
end

describe "__umodti3" do
  test__umodti3(0_u128, 1_u128, 0_u128)
  test__umodti3(2_u128, 1_u128, 0_u128)
  test__umodti3(UInt128RT[0x0000000000000000_u64, 0x8000000000000000_u64], 1_u128, 0_u128)
  test__umodti3(UInt128RT[0x0000000000000000_u64, 0x8000000000000000_u64], 2_u128, 0_u128)
  test__umodti3(UInt128RT[0xFFFFFFFFFFFFFFFF_u64, 0xFFFFFFFFFFFFFFFF_u64], 2_u128, 1_u128)
end
