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
        info.arg_types.length.should eq(2)

        arg_type = info.arg_types[0]
        arg_type.kind.should eq(ArgKind::Direct)
        arg_type.type.should eq(LLVM::Int32)
        arg_type.cast.should be_nil
        arg_type.pad.should be_nil
        arg_type.attr.should be_nil

        arg_type = info.arg_types[1]
        arg_type.kind.should eq(ArgKind::Direct)
        arg_type.type.should eq(LLVM::Int64)
        arg_type.cast.should be_nil
        arg_type.pad.should be_nil
        arg_type.attr.should be_nil

        ret_type = info.return_type
        ret_type.kind.should eq(ArgKind::Direct)
        ret_type.type.should eq(LLVM::Int8)
        ret_type.cast.should be_nil
        ret_type.pad.should be_nil
        ret_type.attr.should be_nil
      end
    end
  end
end
