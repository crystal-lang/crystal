require "spec"

# Ported from compiler-rt:test/builtins/Unit/muloti4_test.c

private def test__muloti4(a : Int128, b : Int128, expected : Int128, expected_overflow : Int32, file = __FILE__, line = __LINE__)
  it "passes compiler-rt builtins unit tests" do
    actual_overflow : Int32 = 0
    actual = __muloti4(a, b, pointerof(actual_overflow))
    actual_overflow.should eq(expected_overflow), file: file, line: line
    if !expected_overflow
      actual.should eq(expected), file: file, line: line
    end
  end
end

# TODO: Remove this helper in PR part 2

private def make_ti(a : Int128, b : Int128)
  (a << 64) + b
end

describe "__muloti4" do
  test__muloti4(0, 0, 0, 0)
  test__muloti4(0, 1, 0, 0)
  test__muloti4(1, 0, 0, 0)
  test__muloti4(0, 10, 0, 0)
  test__muloti4(10, 0, 0, 0)
  test__muloti4(0, 81985529216486895, 0, 0)
  test__muloti4(81985529216486895, 0, 0, 0)
  test__muloti4(0, -1, 0, 0)
  test__muloti4(-1, 0, 0, 0)
  test__muloti4(0, -10, 0, 0)
  test__muloti4(-10, 0, 0, 0)
  test__muloti4(0, -81985529216486895, 0, 0)
  test__muloti4(-81985529216486895, 0, 0, 0)
  test__muloti4(1, 1, 1, 0)
  test__muloti4(1, 10, 10, 0)
  test__muloti4(10, 1, 10, 0)
  test__muloti4(1, 81985529216486895, 81985529216486895, 0)
  test__muloti4(81985529216486895, 1, 81985529216486895, 0)
  test__muloti4(1, -1, -1, 0)
  test__muloti4(1, -10, -10, 0)
  test__muloti4(-10, 1, -10, 0)
  test__muloti4(1, -81985529216486895, -81985529216486895, 0)
  test__muloti4(-81985529216486895, 1, -81985529216486895, 0)
  test__muloti4(3037000499, 3037000499, 9223372030926249001, 0)
  test__muloti4(-3037000499, 3037000499, -9223372030926249001, 0)
  test__muloti4(3037000499, -3037000499, -9223372030926249001, 0)
  test__muloti4(-3037000499, -3037000499, 9223372030926249001, 0)
  test__muloti4(4398046511103, 2097152, 9223372036852678656, 0)
  test__muloti4(-4398046511103, 2097152, -9223372036852678656, 0)
  test__muloti4(4398046511103, -2097152, -9223372036852678656, 0)
  test__muloti4(-4398046511103, -2097152, 9223372036852678656, 0)
  test__muloti4(2097152, 4398046511103, 9223372036852678656, 0)
  test__muloti4(-2097152, 4398046511103, -9223372036852678656, 0)
  test__muloti4(2097152, -4398046511103, -9223372036852678656, 0)
  test__muloti4(-2097152, -4398046511103, 9223372036852678656, 0)
  test__muloti4(make_ti(0x00000000000000B5, 0x04F333F9DE5BE000),
    make_ti(0x0000000000000000, 0x00B504F333F9DE5B),
    make_ti(0x7FFFFFFFFFFFF328, 0xDF915DA296E8A000), 0)
  test__muloti4(make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
    -2,
    make_ti(0x8000000000000000, 0x0000000000000001), 1)
  test__muloti4(-2,
    make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
    make_ti(0x8000000000000000, 0x0000000000000001), 1)
  test__muloti4(make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
    -1,
    make_ti(0x8000000000000000, 0x0000000000000001), 0)
  test__muloti4(-1,
    make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
    make_ti(0x8000000000000000, 0x0000000000000001), 0)
  test__muloti4(make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
    0,
    0, 0)
  test__muloti4(0,
    make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
    0, 0)
  test__muloti4(make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
    1,
    make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF), 0)
  test__muloti4(1,
    make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
    make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF), 0)
  test__muloti4(make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
    2,
    make_ti(0x8000000000000000, 0x0000000000000001), 1)
  test__muloti4(2,
    make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
    make_ti(0x8000000000000000, 0x0000000000000001), 1)
  test__muloti4(make_ti(0x8000000000000000, 0x0000000000000000),
    -2,
    make_ti(0x8000000000000000, 0x0000000000000000), 1)
  test__muloti4(-2,
    make_ti(0x8000000000000000, 0x0000000000000000),
    make_ti(0x8000000000000000, 0x0000000000000000), 1)
  test__muloti4(make_ti(0x8000000000000000, 0x0000000000000000),
    -1,
    make_ti(0x8000000000000000, 0x0000000000000000), 1)
  test__muloti4(-1,
    make_ti(0x8000000000000000, 0x0000000000000000),
    make_ti(0x8000000000000000, 0x0000000000000000), 1)
  test__muloti4(make_ti(0x8000000000000000, 0x0000000000000000),
    0,
    0, 0)
  test__muloti4(0,
    make_ti(0x8000000000000000, 0x0000000000000000),
    0, 0)
  test__muloti4(make_ti(0x8000000000000000, 0x0000000000000000),
    1,
    make_ti(0x8000000000000000, 0x0000000000000000), 0)
  test__muloti4(1,
    make_ti(0x8000000000000000, 0x0000000000000000),
    make_ti(0x8000000000000000, 0x0000000000000000), 0)
  test__muloti4(make_ti(0x8000000000000000, 0x0000000000000000),
    2,
    make_ti(0x8000000000000000, 0x0000000000000000), 1)
  test__muloti4(2,
    make_ti(0x8000000000000000, 0x0000000000000000),
    make_ti(0x8000000000000000, 0x0000000000000000), 1)
  test__muloti4(make_ti(0x8000000000000000, 0x0000000000000001),
    -2,
    make_ti(0x8000000000000000, 0x0000000000000001), 1)
  test__muloti4(-2,
    make_ti(0x8000000000000000, 0x0000000000000001),
    make_ti(0x8000000000000000, 0x0000000000000001), 1)
  test__muloti4(make_ti(0x8000000000000000, 0x0000000000000001),
    -1,
    make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF), 0)
  test__muloti4(-1,
    make_ti(0x8000000000000000, 0x0000000000000001),
    make_ti(0x7FFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF), 0)
  test__muloti4(make_ti(0x8000000000000000, 0x0000000000000001),
    0,
    0, 0)
  test__muloti4(0,
    make_ti(0x8000000000000000, 0x0000000000000001),
    0, 0)
  test__muloti4(make_ti(0x8000000000000000, 0x0000000000000001),
    1,
    make_ti(0x8000000000000000, 0x0000000000000001), 0)
  test__muloti4(1,
    make_ti(0x8000000000000000, 0x0000000000000001),
    make_ti(0x8000000000000000, 0x0000000000000001), 0)
  test__muloti4(make_ti(0x8000000000000000, 0x0000000000000001),
    2,
    make_ti(0x8000000000000000, 0x0000000000000000), 1)
  test__muloti4(2,
    make_ti(0x8000000000000000, 0x0000000000000001),
    make_ti(0x8000000000000000, 0x0000000000000000), 1)
end
