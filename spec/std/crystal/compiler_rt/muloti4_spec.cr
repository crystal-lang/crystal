require "spec"
require "../../../../src/crystal/compiler_rt/muloti4"
require "../../../../src/crystal/compiler_rt/i128_info"

# Ported from compiler-rt:test/builtins/Unit/muloti4_test.c

private def test__muloti4(a : Int128, b : Int128, expected : Int128, expected_overflow : Int32, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual_overflow : Int32 = 0
    actual = __muloti4(a, b, pointerof(actual_overflow))
    actual_overflow.should eq(expected_overflow), file, line
    if !expected_overflow
      actual.should eq(expected), file, line
    end
  end
end

HEX_1 = Int128RT[0x00000000000000B5, 0x04F333F9DE5BE000].all
HEX_2 = Int128RT[0x0000000000000000, 0x00B504F333F9DE5B].all
HEX_3 = Int128RT[0x7FFFFFFFFFFFF328, 0xDF915DA296E8A000].all
HEX_4 = Int128RT[0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF].all
HEX_5 = Int128RT[0x8000000000000000, 0x0000000000000001].all
HEX_6 = Int128RT[0x8000000000000000, 0x0000000000000000].all

describe "__muloti4" do
  test__muloti4(0_i128, 0_i128, 0_i128, 0)
  test__muloti4(0_i128, 1_i128, 0_i128, 0)
  test__muloti4(1_i128, 0_i128, 0_i128, 0)
  test__muloti4(0_i128, 10_i128, 0_i128, 0)
  test__muloti4(10_i128, 0_i128, 0_i128, 0)
  test__muloti4(0_i128, 81985529216486895_i128, 0_i128, 0)
  test__muloti4(81985529216486895_i128, 0_i128, 0_i128, 0)
  # test__muloti4(0_i128, -1_i128, 0_i128, 0)
  # test__muloti4(-1_i128, 0_i128, 0_i128, 0)
  # test__muloti4(0_i128, -10_i128, 0_i128, 0)
  # test__muloti4(-10_i128, 0_i128, 0_i128, 0)
  # test__muloti4(0_i128, -81985529216486895_i128, 0_i128, 0)
  # test__muloti4(-81985529216486895_i128, 0_i128, 0_i128, 0)
  test__muloti4(1_i128, 1_i128, 1_i128, 0)
  test__muloti4(1_i128, 10_i128, 10_i128, 0)
  test__muloti4(10_i128, 1_i128, 10_i128, 0)
  test__muloti4(1_i128, 81985529216486895_i128, 81985529216486895_i128, 0)
  test__muloti4(81985529216486895_i128, 1_i128, 81985529216486895_i128, 0)
  # test__muloti4(1_i128, -1_i128, -1_i128, 0)
  # test__muloti4(1_i128, -10_i128, -10_i128, 0)
  # test__muloti4(-10_i128, 1_i128, -10_i128, 0)
  # test__muloti4(1_i128, -81985529216486895_i128, -81985529216486895_i128, 0)
  # test__muloti4(-81985529216486895_i128, 1_i128, -81985529216486895_i128, 0)
  test__muloti4(3037000499_i128, 3037000499_i128, 9223372030926249001_i128, 0)
  # test__muloti4(-3037000499_i128, 3037000499_i128, -9223372030926249001_i128, 0)
  # test__muloti4(3037000499_i128, -3037000499_i128, -9223372030926249001_i128, 0)
  # test__muloti4(-3037000499_i128, -3037000499_i128, 9223372030926249001_i128, 0)
  test__muloti4(4398046511103_i128, 2097152_i128, 9223372036852678656_i128, 0)
  # test__muloti4(-4398046511103_i128, 2097152_i128, -9223372036852678656_i128, 0)
  # test__muloti4(4398046511103_i128, -2097152_i128, -9223372036852678656_i128, 0)
  # test__muloti4(-4398046511103_i128, -2097152_i128, 9223372036852678656_i128, 0)
  test__muloti4(2097152_i128, 4398046511103_i128, 9223372036852678656_i128, 0)
  # test__muloti4(-2097152_i128, 4398046511103_i128, -9223372036852678656_i128, 0)
  # test__muloti4(2097152_i128, -4398046511103_i128, -9223372036852678656_i128, 0)
  # test__muloti4(-2097152_i128, -4398046511103_i128, 9223372036852678656_i128, 0)
  # test__muloti4(HEX_1, HEX_2, HEX_3, 0) ## NOTE: does not seem to work in c
  # test__muloti4(HEX_4, -2_i128, HEX_5, 1)
  # test__muloti4(-2_i128, HEX_4, HEX_5, 1)
  # test__muloti4(HEX_4, -1_i128, HEX_5, 0)
  # test__muloti4(-1_i128, HEX_4, HEX_5, 0)
  test__muloti4(HEX_4, 0_i128, 0_i128, 0)
  test__muloti4(0_i128, HEX_4, 0_i128, 0)
  test__muloti4(HEX_4, 1_i128, HEX_4, 0)
  test__muloti4(1_i128, HEX_4, HEX_4, 0)
  test__muloti4(HEX_4, 2_i128, HEX_5, 1)
  test__muloti4(2_i128, HEX_4, HEX_5, 1)
  # test__muloti4(HEX_6, -2_i128, HEX_6, 1)
  # test__muloti4(-2_i128, HEX_6, HEX_6, 1)
  # test__muloti4(HEX_6, -1_i128, HEX_6, 1)
  # test__muloti4(-1_i128, HEX_6, HEX_6, 1)
  test__muloti4(HEX_6, 0_i128, 0_i128, 0)
  test__muloti4(0_i128, HEX_6, 0_i128, 0)
  test__muloti4(HEX_6, 1_i128, HEX_6, 0)
  test__muloti4(1_i128, HEX_6, HEX_6, 0)
  test__muloti4(HEX_6, 2_i128, HEX_6, 1)
  test__muloti4(2_i128, HEX_6, HEX_6, 1)
  # test__muloti4(HEX_5, -2_i128, HEX_5, 1)
  # test__muloti4(-2_i128, HEX_5, HEX_5, 1)
  # test__muloti4(HEX_5, -1_i128, HEX_4, 0)
  # test__muloti4(-1_i128, HEX_5, HEX_4, 0)
  test__muloti4(HEX_5, 0_i128, 0_i128, 0)
  test__muloti4(0_i128, HEX_5, 0_i128, 0)
  test__muloti4(HEX_5, 1_i128, HEX_5, 0)
  test__muloti4(1_i128, HEX_5, HEX_5, 0)
  test__muloti4(HEX_5, 2_i128, HEX_6, 1)
  test__muloti4(2_i128, HEX_5, HEX_6, 1)
end
