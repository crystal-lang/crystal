require "../../spec_helper"

describe "Codegen: fun" do
  it "sets external linkage by default" do
    mod = codegen(<<-CRYSTAL, inject_primitives: false, single_module: false)
    fun foo; end
    fun __crystal_foo; end
    CRYSTAL
    mod.functions["foo"].linkage.should eq(LLVM::Linkage::External)
    mod.functions["__crystal_foo"].linkage.should eq(LLVM::Linkage::External)
  end

  it "sets internal linkage to __crystal_ funs when compiling to single module" do
    mod = codegen(<<-CRYSTAL, inject_primitives: false, single_module: true)
    fun foo; end
    fun __crystal_foo; end
    CRYSTAL
    mod.functions["foo"].linkage.should eq(LLVM::Linkage::External)
    mod.functions["__crystal_foo"].linkage.should eq(LLVM::Linkage::Internal)
  end
end
