{% skip_file unless flag?(:compile_rt) %}

require "spec"
require "../../../../src/crystal/compiler_rt/multi3.cr"

# Ported from compiler-rt:test/builtins/Unit/multi3_test.c

private def test__multi3(a : (Int128 | Int128RT), b : (Int128 | Int128RT), expected : (Int128 | Int128RT), file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __multi3(a.to_i128, b.to_i128).should eq(expected.to_i128), file, line
  end
end

describe "__multi3" do
  test__multi3(0_i128, 0_i128, 0_i128)
  test__multi3(0_i128, 1_i128, 0_i128)
  test__multi3(1_i128, 0_i128, 0_i128)
  test__multi3(0_i128, 10_i128, 0_i128)
  test__multi3(10_i128, 0_i128, 0_i128)
  test__multi3(0_i128, 81985529216486895_i128, 0_i128)
  test__multi3(81985529216486895_i128, 0_i128, 0_i128)
  test__multi3(0_i128, Int128RT[1_i128].negate!, 0_i128)
  test__multi3(Int128RT[1_i128].negate!, 0_i128, 0_i128)
  test__multi3(0_i128, Int128RT[10_i128].negate!, 0_i128)
  test__multi3(Int128RT[10_i128].negate!, 0_i128, 0_i128)
  test__multi3(0_i128, Int128RT[81985529216486895_i128].negate!, 0_i128)
  test__multi3(Int128RT[81985529216486895_i128].negate!, 0_i128, 0_i128)
  test__multi3(1_i128, 1_i128, 1_i128)
  test__multi3(1_i128, 10_i128, 10_i128)
  test__multi3(10_i128, 1_i128, 10_i128)
  test__multi3(1_i128, 81985529216486895_i128, 81985529216486895_i128)
  test__multi3(81985529216486895_i128, 1_i128, 81985529216486895_i128)
  test__multi3(1_i128, Int128RT[1_i128].negate!, Int128RT[1_i128].negate!)
  test__multi3(1_i128, Int128RT[10_i128].negate!, Int128RT[10_i128].negate!)
  test__multi3(Int128RT[10_i128].negate!, 1_i128, Int128RT[10_i128].negate!)
  test__multi3(1_i128, Int128RT[81985529216486895_i128].negate!, Int128RT[81985529216486895_i128].negate!)
  test__multi3(Int128RT[81985529216486895_i128].negate!, 1_i128, Int128RT[81985529216486895_i128].negate!)
  test__multi3(3037000499_i128, 3037000499_i128, 9223372030926249001_i128)
  test__multi3(Int128RT[3037000499_i128].negate!, 3037000499_i128, Int128RT[9223372030926249001_i128].negate!)
  test__multi3(3037000499_i128, Int128RT[3037000499_i128].negate!, Int128RT[9223372030926249001_i128].negate!)
  test__multi3(Int128RT[3037000499_i128].negate!, Int128RT[3037000499_i128].negate!, 9223372030926249001_i128)
  test__multi3(4398046511103_i128, 2097152_i128, 9223372036852678656_i128)
  test__multi3(Int128RT[4398046511103_i128].negate!, 2097152_i128, Int128RT[9223372036852678656_i128].negate!)
  test__multi3(4398046511103_i128, Int128RT[2097152_i128].negate!, Int128RT[9223372036852678656_i128].negate!)
  test__multi3(Int128RT[4398046511103_i128].negate!, Int128RT[2097152_i128].negate!, 9223372036852678656_i128)
  test__multi3(2097152_i128, 4398046511103_i128, 9223372036852678656_i128)
  test__multi3(Int128RT[2097152_i128].negate!, 4398046511103_i128, Int128RT[9223372036852678656_i128].negate!)
  test__multi3(2097152_i128, Int128RT[4398046511103_i128].negate!, Int128RT[9223372036852678656_i128].negate!)
  test__multi3(Int128RT[2097152_i128].negate!, Int128RT[4398046511103_i128].negate!, 9223372036852678656_i128)
  test__multi3(Int128RT[0x00000000000000B5_i64, 0x04F333F9DE5BE000_u64].all, Int128RT[0x0000000000000000_i64, 0x00B504F333F9DE5B_u64].all, Int128RT[0x7FFFFFFFFFFFF328_i64, 0xDF915DA296E8A000_u64].all)
end
