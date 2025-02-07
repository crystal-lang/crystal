require "../../spec_helper"

describe "Codegen: fun" do
  it "sets linkage" do
    mod = codegen(<<-CRYSTAL, inject_primitives: false)
    fun foo
    end

    @[Linkage("external")]
    fun ext_foo
    end

    @[Linkage("internal")]
    fun int_foo
    end
    CRYSTAL

    mod.functions["foo"].linkage.should eq(LLVM::Linkage::External)
    mod.functions["ext_foo"].linkage.should eq(LLVM::Linkage::External)
    mod.functions["int_foo"].linkage.should eq(LLVM::Linkage::Internal)
  end
end
