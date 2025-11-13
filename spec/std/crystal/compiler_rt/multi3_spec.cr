require "spec"
require "crystal/compiler_rt/multi3"

# Ported from https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/test/builtins/Unit/multi3_test.c

# TODO: Replace helper methods with literals once possible

private def make_ti(a : Int128, b : Int128)
  (a << 64) + b
end

it ".__multi3" do
  __multi3(0, 0).should eq 0
  __multi3(0, 1).should eq 0
  __multi3(1, 0).should eq 0
  __multi3(0, 10).should eq 0
  __multi3(10, 0).should eq 0
  __multi3(0, 81985529216486895).should eq 0
  __multi3(81985529216486895, 0).should eq 0
  __multi3(0, -1).should eq 0
  __multi3(-1, 0).should eq 0
  __multi3(0, -10).should eq 0
  __multi3(-10, 0).should eq 0
  __multi3(0, -81985529216486895).should eq 0
  __multi3(-81985529216486895, 0).should eq 0
  __multi3(1, 1).should eq 1
  __multi3(1, 10).should eq 10
  __multi3(10, 1).should eq 10
  __multi3(1, 81985529216486895).should eq 81985529216486895
  __multi3(81985529216486895, 1).should eq 81985529216486895
  __multi3(1, -1).should eq -1
  __multi3(1, -10).should eq -10
  __multi3(-10, 1).should eq -10
  __multi3(1, -81985529216486895).should eq -81985529216486895
  __multi3(-81985529216486895, 1).should eq -81985529216486895
  __multi3(3037000499, 3037000499).should eq 9223372030926249001
  __multi3(-3037000499, 3037000499).should eq -9223372030926249001
  __multi3(3037000499, -3037000499).should eq -9223372030926249001
  __multi3(-3037000499, -3037000499).should eq 9223372030926249001
  __multi3(4398046511103, 2097152).should eq 9223372036852678656
  __multi3(-4398046511103, 2097152).should eq -9223372036852678656
  __multi3(4398046511103, -2097152).should eq -9223372036852678656
  __multi3(-4398046511103, -2097152).should eq 9223372036852678656
  __multi3(2097152, 4398046511103).should eq 9223372036852678656
  __multi3(-2097152, 4398046511103).should eq -9223372036852678656
  __multi3(2097152, -4398046511103).should eq -9223372036852678656
  __multi3(-2097152, -4398046511103).should eq 9223372036852678656
  __multi3(
    make_ti(0x00000000000000B5, 0x04F333F9DE5BE000),
    make_ti(0x0000000000000000, 0x00B504F333F9DE5B)
  ).should eq make_ti(0x7FFFFFFFFFFFF328u64, 0xDF915DA296E8A000u64)
end
