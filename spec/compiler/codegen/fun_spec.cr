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

  # `1` alone is inlined and never emitted, so the body is a call. The symbol
  # spelling is what these examples check.
  {% if flag?(:msvc) %}
    it "encodes @ in symbol names" do
      mod = codegen(<<-CRYSTAL)
        class Foo
          def bar
            1 &+ 1
          end
        end

        class Bar < Foo
        end

        Bar.new.bar
        CRYSTAL

      mod.functions[".2A.Bar.40.Foo.23.bar.3A.Int32"]?.should_not be_nil
      mod.functions.each do |func|
        func.name.should_not contain("@")
      end
    end
  {% else %}
    it "encodes @ in an inherited method name" do
      mod = codegen(<<-CRYSTAL)
        class Foo
          def bar
            1 &+ 1
          end
        end

        class Bar < Foo
        end

        Bar.new.bar
        CRYSTAL

      mod.functions["*Bar.40.Foo#bar:Int32"]?.should_not be_nil
      mod.functions["*Bar@Foo#bar:Int32"]?.should be_nil
    end

    it "keeps a method name that has no @" do
      mod = codegen(<<-CRYSTAL)
        class Foo
          def foo
            1 &+ 1
          end
        end

        Foo.new.foo
        CRYSTAL

      mod.functions["*Foo#foo:Int32"]?.should_not be_nil
    end

    it "encodes @ in a proc literal name" do
      mod = codegen(<<-CRYSTAL)
        ->{ 1 }
        CRYSTAL

      proc_name = ""
      mod.functions.each do |func|
        if func.name.starts_with?("~proc")
          proc_name = func.name
          break
        end
      end
      proc_name.should contain(".40.")
      proc_name.should_not contain("@")
    end
  {% end %}

  it "preserves a versioned external symbol name" do
    mod = codegen(<<-CRYSTAL, inject_primitives: false)
      lib LibC
        fun answer = "answer@GLIBC_2.2.5" : Int32
      end

      LibC.answer
      CRYSTAL

    mod.functions["answer@GLIBC_2.2.5"]?.should_not be_nil
  end
end
