{% skip_file unless flag?(:bits32) %}

require "spec"

# Ported from compiler-rt:test/builtins/Unit/modti3_test.c

private def test__modti3(a : Int128, b : Int128, expected : Int128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __modti3(a, b).should eq(expected), file, line
  end
end

private HEX_0_8000000000000000 = 0x8000000000000000.to_i128!

describe "__modti3" do
  test__modti3(0_i128, 1_i128, 0_i128)
  test__modti3(0_i128, -1_i128, 0_i128)
  test__modti3(5_i128, 3_i128, 2_i128)
  test__modti3(5_i128, -3_i128, 2_i128)
  test__modti3(-5_i128, 3_i128, -2_i128)
  test__modti3(-5_i128, -3_i128, -2_i128)
  test__modti3(HEX_0_8000000000000000, 1_i128, 0x0.to_i128!)
  test__modti3(HEX_0_8000000000000000, -1_i128, 0x0.to_i128!)
  test__modti3(HEX_0_8000000000000000, 2_i128, 0x0.to_i128!)
  test__modti3(HEX_0_8000000000000000, -2_i128, 0x0.to_i128!)
  test__modti3(HEX_0_8000000000000000, 3_i128, 2_i128)
  test__modti3(HEX_0_8000000000000000, -3_i128, 2_i128)
end
