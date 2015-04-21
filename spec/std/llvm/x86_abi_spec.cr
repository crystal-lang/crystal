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
      expect(abi.size(LLVM::Int32)).to eq(4)
    end

    it "does align" do
      expect(abi.align(LLVM::Int32)).to eq(4)
    end

    describe "abi_info" do
      it "does with primitives" do
        arg_types = [LLVM::Int32, LLVM::Int64]
        return_type = LLVM::Int8
        info = abi.abi_info(arg_types, return_type, true)
        expect(info.arg_types.length).to eq(2)

        expect(info.arg_types[0]).to eq(ArgType.direct(LLVM::Int32))
        expect(info.arg_types[1]).to eq(ArgType.direct(LLVM::Int64))
        expect(info.return_type).to eq(ArgType.direct(LLVM::Int8))
      end
    end
  end
end
