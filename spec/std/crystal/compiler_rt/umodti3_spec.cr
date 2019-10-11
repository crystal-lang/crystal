{% skip_file if flag?(:bits32) %}

require "spec"

# Ported from compiler-rt:test/builtins/Unit/umodti3_test.c

private def test__umodti3(a : UInt128, b : UInt128, expected : UInt128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __umodti3(a, b).should eq(expected), file, line
  end
end

private HEX_0_80000000000000000000000000000000 = 0x80000000000000000000000000000000.to_u128!
private HEX_0_FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF.to_u128!

describe "__umodti3" do
  test__umodti3(0_u128, 1_u128, 0_u128)
  test__umodti3(2_u128, 1_u128, 0_u128)
  test__umodti3(HEX_0_80000000000000000000000000000000, 1_u128, 0x0.to_u128!)
  test__umodti3(HEX_0_80000000000000000000000000000000, 2_u128, 0x0.to_u128!)
  test__umodti3(HEX_0_FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 2_u128, 0x1.to_u128!)
end
