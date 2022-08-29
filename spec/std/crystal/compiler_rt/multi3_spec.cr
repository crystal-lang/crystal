require "spec"
require "crystal/compiler_rt/multi3"

# Ported from https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/test/builtins/Unit/multi3_test.c

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
    0x00000000000000B504F333F9DE5BE000_i128,
    0x000000000000000000B504F333F9DE5B_i128
  ).should eq 0x7FFFFFFFFFFFF328DF915DA296E8A000_i128
end
