require "spec"
require "../../../../src/crystal/compiler_rt/modti3"
require "../../../../src/crystal/compiler_rt/i128_info"

# Ported from compiler-rt:test/builtins/Unit/modti3_test.c

private def test__modti3(a : (Int128 | Int128RT), b : (Int128 | Int128RT), expected : (Int128 | Int128RT), file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __modti3(a.to_i128, b.to_i128).should eq(expected.to_i128), file, line
  end
end

describe "__modti3" do
  test__modti3(0_i128, 1_i128, 0_i128)
  test__modti3(0_i128, Int128RT[1_i128].negate!, 0_i128)
  test__modti3(5_i128, 3_i128, 2_i128)
  test__modti3(5_i128, Int128RT[3_i128].negate!, 2_i128)
  test__modti3(Int128RT[5_i128].negate!, 3_i128, Int128RT[2_i128].negate!)
  test__modti3(Int128RT[5_i128].negate!, Int128RT[3_i128].negate!, Int128RT[2_i128].negate!)
  test__modti3(Int128RT[0x0000000000000000, 0x8000000000000000].all, 1_i128, 0_i128)
  test__modti3(Int128RT[0x0000000000000000, 0x8000000000000000].all, Int128RT[1_i128].negate!, 0x0.to_i128!)
  test__modti3(Int128RT[0x0000000000000000, 0x8000000000000000].all, 2_i128, 0_i128)
  test__modti3(Int128RT[0x0000000000000000, 0x8000000000000000].all, Int128RT[2_i128].negate!, 0x0.to_i128!)
  # test__modti3(Int128RT[0x0000000000000000, 0x8000000000000000].all, 3_i128, 2_i128)
  # test__modti3(Int128RT[0x0000000000000000, 0x8000000000000000].all, Int128RT[3_i128].negate!, 2_i128)
end
