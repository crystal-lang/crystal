require "spec"
require "crystal/compiler_rt/pow"

# Ported from https://github.com/llvm/llvm-project/blob/2e9df860468425645dcd1b241c5dbf76c072e314/compiler-rt/test/builtins/Unit/powidf2_test.c

it ".__powidf2" do
  __powidf2(0, 0).should eq 1
  __powidf2(1, 0).should eq 1
  __powidf2(1.5, 0).should eq 1
  __powidf2(2, 0).should eq 1
  __powidf2(Float64::INFINITY, 0).should eq 1
  __powidf2(-0.0, 0).should eq 1
  __powidf2(-1, 0).should eq 1
  __powidf2(-1.5, 0).should eq 1
  __powidf2(-2, 0).should eq 1
  __powidf2(-Float64::INFINITY, 0).should eq 1
  __powidf2(0, 1).should eq 0
  __powidf2(0, 2).should eq 0
  __powidf2(0, 3).should eq 0
  __powidf2(0, 4).should eq 0
  __powidf2(0, Int32::MAX - 1).should eq 0
  __powidf2(0, Int32::MAX).should eq 0
  __powidf2(-0.0, 1).should eq -0.0
  __powidf2(-0.0, 2).should eq 0
  __powidf2(-0.0, 3).should eq -0.0
  __powidf2(-0.0, 4).should eq 0
  __powidf2(-0.0, Int32::MAX - 1).should eq 0
  __powidf2(-0.0, Int32::MAX).should eq -0.0
  __powidf2(1, 1).should eq 1
  __powidf2(1, 2).should eq 1
  __powidf2(1, 3).should eq 1
  __powidf2(1, 4).should eq 1
  __powidf2(1, Int32::MAX - 1).should eq 1
  __powidf2(1, Int32::MAX).should eq 1
  __powidf2(Float64::INFINITY, 1).should eq Float64::INFINITY
  __powidf2(Float64::INFINITY, 2).should eq Float64::INFINITY
  __powidf2(Float64::INFINITY, 3).should eq Float64::INFINITY
  __powidf2(Float64::INFINITY, 4).should eq Float64::INFINITY
  __powidf2(Float64::INFINITY, Int32::MAX - 1).should eq Float64::INFINITY
  __powidf2(Float64::INFINITY, Int32::MAX).should eq Float64::INFINITY
  __powidf2(-Float64::INFINITY, 1).should eq -Float64::INFINITY
  __powidf2(-Float64::INFINITY, 2).should eq Float64::INFINITY
  __powidf2(-Float64::INFINITY, 3).should eq -Float64::INFINITY
  __powidf2(-Float64::INFINITY, 4).should eq Float64::INFINITY
  __powidf2(-Float64::INFINITY, Int32::MAX - 1).should eq Float64::INFINITY
  __powidf2(-Float64::INFINITY, Int32::MAX).should eq -Float64::INFINITY
  __powidf2(0, -1).should eq Float64::INFINITY
  __powidf2(0, -2).should eq Float64::INFINITY
  __powidf2(0, -3).should eq Float64::INFINITY
  __powidf2(0, -4).should eq Float64::INFINITY
  __powidf2(0, Int32::MIN + 2).should eq Float64::INFINITY
  __powidf2(0, Int32::MIN + 1).should eq Float64::INFINITY
  __powidf2(0, Int32::MIN).should eq Float64::INFINITY
  __powidf2(-0.0, -1).should eq -Float64::INFINITY
  __powidf2(-0.0, -2).should eq Float64::INFINITY
  __powidf2(-0.0, -3).should eq -Float64::INFINITY
  __powidf2(-0.0, -4).should eq Float64::INFINITY
  __powidf2(-0.0, Int32::MIN + 2).should eq Float64::INFINITY
  __powidf2(-0.0, Int32::MIN + 1).should eq -Float64::INFINITY
  __powidf2(-0.0, Int32::MIN).should eq Float64::INFINITY
  __powidf2(1, -1).should eq 1
  __powidf2(1, -2).should eq 1
  __powidf2(1, -3).should eq 1
  __powidf2(1, -4).should eq 1
  __powidf2(1, Int32::MIN + 2).should eq 1
  __powidf2(1, Int32::MIN + 1).should eq 1
  __powidf2(1, Int32::MIN).should eq 1
  __powidf2(Float64::INFINITY, -1).should eq 0
  __powidf2(Float64::INFINITY, -2).should eq 0
  __powidf2(Float64::INFINITY, -3).should eq 0
  __powidf2(Float64::INFINITY, -4).should eq 0
  __powidf2(Float64::INFINITY, Int32::MIN + 2).should eq 0
  __powidf2(Float64::INFINITY, Int32::MIN + 1).should eq 0
  __powidf2(Float64::INFINITY, Int32::MIN).should eq 0
  __powidf2(-Float64::INFINITY, -1).should eq -0.0
  __powidf2(-Float64::INFINITY, -2).should eq 0
  __powidf2(-Float64::INFINITY, -3).should eq -0.0
  __powidf2(-Float64::INFINITY, -4).should eq 0
  __powidf2(-Float64::INFINITY, Int32::MIN + 2).should eq 0
  __powidf2(-Float64::INFINITY, Int32::MIN + 1).should eq -0.0
  __powidf2(-Float64::INFINITY, Int32::MIN).should eq 0
  __powidf2(2, 10).should eq 1024.0
  __powidf2(-2, 10).should eq 1024.0
  __powidf2(2, -10).should eq 1/1024.0
  __powidf2(-2, -10).should eq 1/1024.0
  __powidf2(2, 19).should eq 524288.0
  __powidf2(-2, 19).should eq -524288.0
  __powidf2(2, -19).should eq 1/524288.0
  __powidf2(-2, -19).should eq -1/524288.0
  __powidf2(2, 31).should eq 2147483648.0
  __powidf2(-2, 31).should eq -2147483648.0
  __powidf2(2, -31).should eq 1/2147483648.0
  __powidf2(-2, -31).should eq -1/2147483648.0
end
