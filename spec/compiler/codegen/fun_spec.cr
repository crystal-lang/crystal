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

  it "keeps fun defined before a lib fun declaration with the same name (#17917)" do
    run(<<-CRYSTAL, Int32).should eq(2)
      fun foo(x : Int32) : Int32
        x &+ 1
      end

      lib LibFoo
        fun foo(x : Int32) : Int32
      end

      LibFoo.foo(1)
      CRYSTAL
  end

  it "keeps fun defined after a lib fun declaration with the same name" do
    run(<<-CRYSTAL, Int32).should eq(2)
      lib LibFoo
        fun foo(x : Int32) : Int32
      end

      fun foo(x : Int32) : Int32
        x &+ 1
      end

      LibFoo.foo(1)
      CRYSTAL
  end

  it "returns void from `__crystal_main` in non-evaluated code" do
    mod = codegen(<<-CRYSTAL, inject_primitives: false)
      struct Foo
        @x = 1
        @y = ""
        @z = ""
        @w = ""
      end

      Foo.new
      CRYSTAL

    mod.to_s.should contain("define void @__crystal_main")
  end
end
