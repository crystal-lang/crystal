require "spec"
require "llvm"

LLVM.init_x86

private def abi
  triple = LLVM.default_target_triple
  target = LLVM::Target.from_triple(triple)
  machine = target.create_target_machine(triple)
  LLVM::ABI::X86.new(machine)
end

class LLVM::ABI
  describe X86 do
    it "does size" do
      abi.size(LLVM::Int32).should eq(4)
    end

    it "does align" do
      abi.align(LLVM::Int32).should eq(4)
    end

    describe "abi_info" do
      it "does with primitives" do
        arg_types = [LLVM::Int32, LLVM::Int64]
        return_type = LLVM::Int8
        info = abi.abi_info(arg_types, return_type, true)
        info.arg_types.size.should eq(2)

        info.arg_types[0].should eq(ArgType.direct(LLVM::Int32))
        info.arg_types[1].should eq(ArgType.direct(LLVM::Int64))
        info.return_type.should eq(ArgType.direct(LLVM::Int8))
      end
    end
  end
end
