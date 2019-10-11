require "spec"

# Ported from compiler-rt:test/builtins/Unit/divti3_test.c

private def test__divti3(a : Int128, b : Int128, expected : Int128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __divti3(a, b).should eq(expected), file, line
  end
end

private HEX_0_8000000000000000 = 0x8000000000000000.to_i128!
private HEX_0_4000000000000000 = 0x4000000000000000.to_i128!
private HEX_0_C000000000000000 = 0xC000000000000000.to_i128!

describe "__divti3" do
  test__divti3(0_i128, 1_i128, 0_i128)
  test__divti3(0_i128, -1_i128, 0_i128)
  test__divti3(2_i128, 1_i128, 2_i128)
  test__divti3(2_i128, -1_i128, -2_i128)
  test__divti3(-2_i128, 1_i128, -2_i128)
  test__divti3(-2_i128, -1_i128, 2_i128)
  test__divti3(HEX_0_8000000000000000, 1, HEX_0_8000000000000000)
  test__divti3(HEX_0_8000000000000000, -1, HEX_0_8000000000000000)
  test__divti3(HEX_0_8000000000000000, -2, HEX_0_4000000000000000)
  test__divti3(HEX_0_8000000000000000, 2, HEX_0_C000000000000000)
end
