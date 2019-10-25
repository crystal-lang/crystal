require "spec"
require "../../../../src/crystal/compiler_rt/multi3.cr"

# Ported from compiler-rt:test/builtins/Unit/multi3_test.c

private def test__multi3(a : Int128, b : Int128, expected : Int128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __multi3(a, b).should eq(expected), file, line
  end
end

HEX_1 = Int128RT.new
HEX_1.info.low =  0x04F333F9DE5BE000
HEX_1.info.high = 181_i64                 # NOTE: in hex `0x00000000000000B5`

HEX_2 = Int128RT.new
HEX_2.info.low =  0x00B504F333F9DE5B
HEX_2.info.high = 0_i64                   # NOTE: in hex `0x0000000000000000`

HEX_3 = Int128RT.new
HEX_3.info.low =  0xDF915DA296E8A000
HEX_3.info.high = 9223372036854772520_i64 # NOTE: in hex `0x7FFFFFFFFFFFF328`

describe "__multi3" do
  test__multi3(0_i128, 0_i128, 0_i128)
  test__multi3(0_i128, 1_i128, 0_i128)
  test__multi3(1_i128, 0_i128, 0_i128)
  test__multi3(0_i128, 10_i128, 0_i128)
  test__multi3(10_i128, 0_i128, 0_i128)
  test__multi3(0_i128, 81985529216486895_i128, 0_i128)
  test__multi3(81985529216486895_i128, 0_i128, 0_i128)
  # test__multi3(0_i128, -1_i128, 0_i128)
  # test__multi3(-1_i128, 0_i128, 0_i128)
  # test__multi3(0_i128, -10_i128, 0_i128)
  # test__multi3(-10_i128, 0_i128, 0_i128)
  # test__multi3(0_i128, -81985529216486895_i128, 0_i128)
  # test__multi3(-81985529216486895_i128, 0_i128, 0_i128)
  test__multi3(1_i128, 1_i128, 1_i128)
  test__multi3(1_i128, 10_i128, 10_i128)
  test__multi3(10_i128, 1_i128, 10_i128)
  test__multi3(1_i128, 81985529216486895_i128, 81985529216486895_i128)
  test__multi3(81985529216486895_i128, 1_i128, 81985529216486895_i128)
  # test__multi3(1_i128, -1_i128, -1_i128)
  # test__multi3(1_i128, -10_i128, -10_i128)
  # test__multi3(-10_i128, 1_i128, -10_i128)
  # test__multi3(1_i128, -81985529216486895_i128, -81985529216486895_i128)
  # test__multi3(-81985529216486895_i128, 1_i128, -81985529216486895_i128)
  # test__multi3(-3037000499_i128, 3037000499_i128, -9223372030926249001_i128)
  # test__multi3(3037000499_i128, -3037000499_i128, -9223372030926249001_i128)
  # test__multi3(-3037000499_i128, -3037000499_i128, 9223372030926249001_i128)
  test__multi3(HEX_1.all, HEX_2.all, HEX_3.all)
end
