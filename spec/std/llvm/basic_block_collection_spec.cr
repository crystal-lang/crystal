require "spec"
require "llvm"

describe LLVM::BasicBlockCollection do
  it "counts basic blocks in declarations and function bodies" do
    ctx = LLVM::Context.new
    mod = ctx.new_module("test")
    function = mod.functions.add("test", [] of LLVM::Type, ctx.void)
    blocks = function.basic_blocks

    blocks.size.should eq(0)
    blocks.append("entry")
    blocks.size.should eq(1)
    blocks.append("exit")
    blocks.size.should eq(2)
  end
end
