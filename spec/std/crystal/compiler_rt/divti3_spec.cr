require "spec"
require "../../../../src/crystal/compiler_rt/divti3"
require "../../../../src/crystal/compiler_rt/i128_info"

# Ported from compiler-rt:test/builtins/Unit/divti3_test.c

private def test__divti3(a : (Int128 | Int128RT), b : (Int128 | Int128RT), expected : (Int128 | Int128RT), file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __divti3(a.to_i128, b.to_i128).should eq(expected.to_i128), file, line
  end
end

describe "__divti3" do
  test__divti3(0_i128, 1_i128, 0_i128)
  test__divti3(0_i128, Int128RT[1_i128].negate!, 0_i128)
  test__divti3(2_i128, 1_i128, 2_i128)
  test__divti3(2_i128, Int128RT[1_i128].negate!, Int128RT[2_i128].negate!)
  test__divti3(Int128RT[2_i128].negate!, 1_i128, Int128RT[2_i128].negate!)
  test__divti3(Int128RT[2_i128].negate!, Int128RT[1_i128].negate!, 2_i128)
  # test__divti3(Int128RT[0x0000000000000000_i64, 0x8000000000000000_u64].all, 1_i128, Int128RT[0x0000000000000000_i64, 0x8000000000000000_u64].all)
  # test__divti3(Int128RT[0x0000000000000000_i64, 0x8000000000000000_u64].all, Int128RT[1_i128].negate!, Int128RT[0x0000000000000000_i64, 0x8000000000000000_u64].all)
  # test__divti3(Int128RT[0x0000000000000000_i64, 0x8000000000000000_u64].all, Int128RT[2_i128].negate!, Int128RT[0x0000000000000000_i64, 0x4000000000000000_u64].all)
  # test__divti3(Int128RT[0x0000000000000000_i64, 0x8000000000000000_u64].all, 2_i128, Int128RT[0x0000000000000000_i64, 0xC000000000000000_u64].all)
end
