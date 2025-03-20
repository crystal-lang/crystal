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

  it "defines same fun 3 or more times (#15523)" do
    run(<<-CRYSTAL, Int32).should eq(3)
      fun foo : Int32
        1
      end

      fun foo : Int32
        2
      end

      fun foo : Int32
        3
      end

      foo
      CRYSTAL
  end
end
