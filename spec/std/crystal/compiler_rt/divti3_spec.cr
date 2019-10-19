require "spec"
require "../../../../src/crystal/compiler_rt/divti3.cr"

# Ported from compiler-rt:test/builtins/Unit/divti3_test.c

private def test__divti3(a : Int128, b : Int128, expected : Int128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __divti3(a, b).should eq(expected), file, line
  end
end

private HEX_8000000000000000 = 0_i128 << 0x8000000000000000
private HEX_4000000000000000 = 0_i128 << 0x4000000000000000
private HEX_C000000000000000 = 0_i128 << 0xC000000000000000

describe "__divti3" do
  test__divti3(0_i128, 1_i128, 0_i128)
  # test__divti3(0_i128, -1_i128, 0_i128)
  test__divti3(2_i128, 1_i128, 2_i128)
  # test__divti3(2_i128, -1_i128, -2_i128)
  # test__divti3(-2_i128, 1_i128, -2_i128)
  # test__divti3(-2_i128, -1_i128, 2_i128)
  test__divti3(HEX_8000000000000000, 1_i128, HEX_8000000000000000)
  # test__divti3(HEX_8000000000000000, -1_i128, HEX_8000000000000000)
  # test__divti3(HEX_8000000000000000, -2_i128, HEX_4000000000000000)
  test__divti3(HEX_8000000000000000, 2_i128, HEX_C000000000000000)
end
