require "spec"

# Ported from compiler-rt:test/builtins/Unit/mulodi4_test.c

private def test__mulodi4(a : Int64, b : Int64, expected : Int64, expected_overflow : Int32, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual_overflow : Int32 = 0
    actual = __mulodi4(a, b, pointerof(actual_overflow))
    actual_overflow.should eq(expected_overflow), file, line
    if !expected_overflow
      actual.should eq(expected), file, line
    end
  end
end

private HEX_0_7FFFFFFFFFFFFFFF = 0x7FFFFFFFFFFFFFFF.to_i64!
private HEX_0_8000000000000001 = 0x8000000000000001.to_i64!
private HEX_0_8000000000000000 = 0x8000000000000000.to_i64!

describe "__mulodi4" do
  test__mulodi4(0, 0, 0, 0)
  test__mulodi4(0, 1, 0, 0)
  test__mulodi4(1, 0, 0, 0)
  test__mulodi4(0, 10, 0, 0)
  test__mulodi4(10, 0, 0, 0)
  test__mulodi4(0, 81985529216486895, 0, 0)
  test__mulodi4(81985529216486895, 0, 0, 0)
  test__mulodi4(0, -1, 0, 0)
  test__mulodi4(-1, 0, 0, 0)
  test__mulodi4(0, -10, 0, 0)
  test__mulodi4(-10, 0, 0, 0)
  test__mulodi4(0, -81985529216486895, 0, 0)
  test__mulodi4(-81985529216486895, 0, 0, 0)
  test__mulodi4(1, 1, 1, 0)
  test__mulodi4(1, 10, 10, 0)
  test__mulodi4(10, 1, 10, 0)
  test__mulodi4(1, 81985529216486895, 81985529216486895, 0)
  test__mulodi4(81985529216486895, 1, 81985529216486895, 0)
  test__mulodi4(1, -1, -1, 0)
  test__mulodi4(1, -10, -10, 0)
  test__mulodi4(-10, 1, -10, 0)
  test__mulodi4(1, -81985529216486895, -81985529216486895, 0)
  test__mulodi4(-81985529216486895, 1, -81985529216486895, 0)
  test__mulodi4(3037000499, 3037000499, 9223372030926249001, 0)
  test__mulodi4(-3037000499, 3037000499, -9223372030926249001, 0)
  test__mulodi4(3037000499, -3037000499, -9223372030926249001, 0)
  test__mulodi4(-3037000499, -3037000499, 9223372030926249001, 0)
  test__mulodi4(4398046511103, 2097152, 9223372036852678656, 0)
  test__mulodi4(-4398046511103, 2097152, -9223372036852678656, 0)
  test__mulodi4(4398046511103, -2097152, -9223372036852678656, 0)
  test__mulodi4(-4398046511103, -2097152, 9223372036852678656, 0)
  test__mulodi4(2097152, 4398046511103, 9223372036852678656, 0)
  test__mulodi4(-2097152, 4398046511103, -9223372036852678656, 0)
  test__mulodi4(2097152, -4398046511103, -9223372036852678656, 0)
  test__mulodi4(-2097152, -4398046511103, 9223372036852678656, 0)
  test__mulodi4(HEX_0_7FFFFFFFFFFFFFFF, -2, 2, 1)
  test__mulodi4(-2, HEX_0_7FFFFFFFFFFFFFFF, 2, 1)
  test__mulodi4(HEX_0_7FFFFFFFFFFFFFFF, -1, HEX_0_8000000000000001, 0)
  test__mulodi4(-1, HEX_0_7FFFFFFFFFFFFFFF, HEX_0_8000000000000001, 0)
  test__mulodi4(HEX_0_7FFFFFFFFFFFFFFF, 0, 0, 0)
  test__mulodi4(0, HEX_0_7FFFFFFFFFFFFFFF, 0, 0)
  test__mulodi4(HEX_0_7FFFFFFFFFFFFFFF, 1, HEX_0_7FFFFFFFFFFFFFFF, 0)
  test__mulodi4(1, HEX_0_7FFFFFFFFFFFFFFF, HEX_0_7FFFFFFFFFFFFFFF, 0)
  test__mulodi4(HEX_0_7FFFFFFFFFFFFFFF, 2, HEX_0_8000000000000001, 1)
  test__mulodi4(2, HEX_0_7FFFFFFFFFFFFFFF, HEX_0_8000000000000001, 1)
  test__mulodi4(HEX_0_8000000000000000, -2, HEX_0_8000000000000000, 1)
  test__mulodi4(-2, HEX_0_8000000000000000, HEX_0_8000000000000000, 1)
  test__mulodi4(HEX_0_8000000000000000, -1, HEX_0_8000000000000000, 1)
  test__mulodi4(-1, HEX_0_8000000000000000, HEX_0_8000000000000000, 1)
  test__mulodi4(HEX_0_8000000000000000, 0, 0, 0)
  test__mulodi4(0, HEX_0_8000000000000000, 0, 0)
  test__mulodi4(HEX_0_8000000000000000, 1, HEX_0_8000000000000000, 0)
  test__mulodi4(1, HEX_0_8000000000000000, HEX_0_8000000000000000, 0)
  test__mulodi4(HEX_0_8000000000000000, 2, HEX_0_8000000000000000, 1)
  test__mulodi4(2, HEX_0_8000000000000000, HEX_0_8000000000000000, 1)
  test__mulodi4(HEX_0_8000000000000001, -2, HEX_0_8000000000000001, 1)
  test__mulodi4(-2, HEX_0_8000000000000001, HEX_0_8000000000000001, 1)
  test__mulodi4(HEX_0_8000000000000001, -1, HEX_0_7FFFFFFFFFFFFFFF, 0)
  test__mulodi4(-1, HEX_0_8000000000000001, HEX_0_7FFFFFFFFFFFFFFF, 0)
  test__mulodi4(HEX_0_8000000000000001, 0, 0, 0)
  test__mulodi4(0, HEX_0_8000000000000001, 0, 0)
  test__mulodi4(HEX_0_8000000000000001, 1, HEX_0_8000000000000001, 0)
  test__mulodi4(1, HEX_0_8000000000000001, HEX_0_8000000000000001, 0)
  test__mulodi4(HEX_0_8000000000000001, 2, HEX_0_8000000000000000, 1)
  test__mulodi4(2, HEX_0_8000000000000001, HEX_0_8000000000000000, 1)
end
