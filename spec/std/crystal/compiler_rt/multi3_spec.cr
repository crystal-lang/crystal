require "spec"
require "../../../../src/crystal/compiler_rt/multi3.cr"

# Ported from compiler-rt:test/builtins/Unit/multi3_test.c

private def test__multi3(a : Int128, b : Int128, expected : Int128, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    __multi3(a, b).should eq(expected), file, line
  end
end

private HEX_81985529216486895000000000000000 = StaticArray[0x8198552921648689, 0x5000000000000000].unsafe_as(Int128)
private HEX_3037000499                       = 0x3037000499.to_i128!
private HEX_92233720309262490010000000000000 = StaticArray[0x9223372030926249, 0x0010000000000000].unsafe_as(Int128)
private HEX_4398046511103                    = 0x4398046511103.to_i128!
private HEX_2097152                          = 0x2097152.to_i128!
private HEX_92233720368526786560000000000000 = StaticArray[0x9223372036852678, 0x6560000000000000].unsafe_as(Int128)
private HEX_00000000000000B504F333F9DE5BE000 = StaticArray[0x00000000000000B5, 0x04F333F9DE5BE000].unsafe_as(Int128)
private HEX_000000000000000000B504F333F9DE5B = StaticArray[0x0000000000000000, 0x00B504F333F9DE5B].unsafe_as(Int128)
private HEX_7FFFFFFFFFFFF328DF915DA296E8A000 = StaticArray[0x7FFFFFFFFFFFF328, 0xDF915DA296E8A000].unsafe_as(Int128)

describe "__multi3" do
  test__multi3(0_i128, 0_i128, 0_i128)
  test__multi3(0_i128, 1_i128, 0_i128)
  test__multi3(1_i128, 0_i128, 0_i128)
  test__multi3(0_i128, 10_i128, 0_i128)
  test__multi3(10_i128, 0_i128, 0_i128)
  test__multi3(0_i128, HEX_81985529216486895000000000000000, 0_i128)
  test__multi3(HEX_81985529216486895000000000000000, 0_i128, 0_i128)
  # test__multi3(0_i128, -1_i128, 0_i128)
  # test__multi3(-1_i128, 0_i128, 0_i128)
  # test__multi3(0_i128, -10_i128, 0_i128)
  # test__multi3(-10_i128, 0_i128, 0_i128)
  # test__multi3(0_i128, -HEX_81985529216486895000000000000000, 0_i128)
  # test__multi3(-HEX_81985529216486895000000000000000, 0_i128, 0_i128)
  test__multi3(1_i128, 1_i128, 1_i128)
  test__multi3(1_i128, 10_i128, 10_i128)
  test__multi3(10_i128, 1_i128, 10_i128)
  #test__multi3(1_i128, HEX_81985529216486895000000000000000, HEX_81985529216486895000000000000000)
  # test__multi3(HEX_81985529216486895000000000000000, 1_i128, HEX_81985529216486895000000000000000)
  # test__multi3(1_i128, -1_i128, -1_i128)
  # test__multi3(1_i128, -10_i128, -10_i128)
  # test__multi3(-10_i128, 1_i128, -10_i128)
  # test__multi3(1_i128, -HEX_81985529216486895000000000000000, -HEX_81985529216486895000000000000000)
  # test__multi3(-HEX_81985529216486895000000000000000, 1_i128, -HEX_81985529216486895000000000000000)
  # test__multi3(HEX_3037000499, HEX_3037000499, HEX_92233720368526786560000000000000)
  # test__multi3(-HEX_3037000499, HEX_3037000499, -HEX_9223372030926249001)
  # test__multi3(HEX_3037000499, -HEX_3037000499, -HEX_9223372030926249001)
  # test__multi3(-HEX_3037000499, -HEX_3037000499, HEX_9223372030926249001)
  # test__multi3(HEX_4398046511103, HEX_2097152, HEX_92233720368526786560000000000000)
  # test__multi3(-HEX_4398046511103, HEX_2097152, -HEX_92233720368526786560000000000000)
  # test__multi3(HEX_4398046511103, -HEX_2097152, -HEX_92233720368526786560000000000000)
  # test__multi3(-HEX_4398046511103, -HEX_2097152, HEX_92233720368526786560000000000000)
  # test__multi3(HEX_2097152, HEX_4398046511103, HEX_92233720368526786560000000000000)
  # test__multi3(-HEX_2097152, HEX_4398046511103, -HEX_92233720368526786560000000000000)
  # test__multi3(HEX_2097152, -HEX_4398046511103, -HEX_92233720368526786560000000000000)
  # test__multi3(-HEX_2097152, -HEX_4398046511103, HEX_92233720368526786560000000000000)
  # test__multi3(HEX_00000000000000B504F333F9DE5BE000, HEX_000000000000000000B504F333F9DE5B, HEX_7FFFFFFFFFFFF328DF915DA296E8A000)
end
