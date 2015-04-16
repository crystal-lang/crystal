require "spec"
require "llvm"

LLVM.init_x86

private def abi
  triple = LLVM.default_target_triple
  target = LLVM::Target.from_triple(triple)
  machine = target.create_target_machine(triple)
  LLVM::ABI::X86_64.new(machine)
end

class LLVM::ABI
  describe X86_64 do
    describe "align" do
      it "for integer" do
        abi.align(LLVM::Int1).should be_a(::Int32)
        abi.align(LLVM::Int1).should eq(1)
        abi.align(LLVM::Int8).should eq(1)
        abi.align(LLVM::Int16).should eq(2)
        abi.align(LLVM::Int32).should eq(4)
        abi.align(LLVM::Int64).should eq(8)
      end

      it "for pointer" do
        abi.align(LLVM::Int8.pointer).should eq(8)
      end

      it "for float" do
        abi.align(LLVM::Float).should eq(4)
      end

      it "for double" do
        abi.align(LLVM::Double).should eq(8)
      end

      it "for struct" do
        abi.align(LLVM::Type.struct([LLVM::Int32, LLVM::Int64])).should eq(8)
        abi.align(LLVM::Type.struct([LLVM::Int8, LLVM::Int16])).should eq(2)
      end

      it "for packed struct" do
        abi.align(LLVM::Type.struct([LLVM::Int32, LLVM::Int64], packed: true)).should eq(1)
      end

      it "for array" do
        abi.align(LLVM::Int16.array(10)).should eq(2)
      end
    end

    describe "size" do
      it "for integer" do
        abi.size(LLVM::Int1).should be_a(::Int32)
        abi.size(LLVM::Int1).should eq(1)
        abi.size(LLVM::Int8).should eq(1)
        abi.size(LLVM::Int16).should eq(2)
        abi.size(LLVM::Int32).should eq(4)
        abi.size(LLVM::Int64).should eq(8)
      end

      it "for pointer" do
        abi.size(LLVM::Int8.pointer).should eq(8)
      end

      it "for float" do
        abi.size(LLVM::Float).should eq(4)
      end

      it "for double" do
        abi.size(LLVM::Double).should eq(8)
      end

      it "for struct" do
        abi.size(LLVM::Type.struct([LLVM::Int32, LLVM::Int64])).should eq(16)
        abi.size(LLVM::Type.struct([LLVM::Int16, LLVM::Int8])).should eq(4)
        abi.size(LLVM::Type.struct([LLVM::Int32, LLVM::Int8, LLVM::Int8])).should eq(8)
      end

      it "for packed struct" do
        abi.size(LLVM::Type.struct([LLVM::Int32, LLVM::Int64], packed: true)).should eq(12)
      end

      it "for array" do
        abi.size(LLVM::Int16.array(10)).should eq(20)
      end
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

      it "does with structs less than 64 bits" do
        str = LLVM::Type.struct([LLVM::Int8, LLVM::Int16])
        arg_types = [str]
        return_type = str

        info = abi.abi_info(arg_types, return_type, true)
        info.arg_types.length.should eq(1)

        arg_type = info.arg_types[0]
        arg_type.kind.should eq(ArgKind::Direct)
        arg_type.type.should eq(str)
        arg_type.cast.should eq(LLVM::Type.struct([LLVM::Int64]))
        arg_type.pad.should be_nil
        arg_type.attr.should be_nil

        ret_type = info.return_type
        ret_type.kind.should eq(ArgKind::Direct)
        ret_type.type.should eq(str)
        ret_type.cast.should eq(LLVM::Type.struct([LLVM::Int64]))
        ret_type.pad.should be_nil
        ret_type.attr.should be_nil
      end

      it "does with structs between 64 and 128 bits" do
        str = LLVM::Type.struct([LLVM::Int64, LLVM::Int16])
        arg_types = [str]
        return_type = str

        info = abi.abi_info(arg_types, return_type, true)
        info.arg_types.length.should eq(1)

        arg_type = info.arg_types[0]
        arg_type.kind.should eq(ArgKind::Direct)
        arg_type.type.should eq(str)
        arg_type.cast.should eq(LLVM::Type.struct([LLVM::Int64, LLVM::Int64]))
        arg_type.pad.should be_nil
        arg_type.attr.should be_nil

        ret_type = info.return_type
        ret_type.kind.should eq(ArgKind::Direct)
        ret_type.type.should eq(str)
        ret_type.cast.should eq(LLVM::Type.struct([LLVM::Int64, LLVM::Int64]))
        ret_type.pad.should be_nil
        ret_type.attr.should be_nil
      end

      it "does with structs between 64 and 128 bits" do
        str = LLVM::Type.struct([LLVM::Int64, LLVM::Int64, LLVM::Int8])
        arg_types = [str]
        return_type = str

        info = abi.abi_info(arg_types, return_type, true)
        info.arg_types.length.should eq(1)

        arg_type = info.arg_types[0]
        arg_type.kind.should eq(ArgKind::Indirect)
        arg_type.type.should eq(str)
        arg_type.cast.should be_nil
        arg_type.pad.should be_nil
        arg_type.attr.should eq(Attribute::ByVal)

        ret_type = info.return_type
        ret_type.kind.should eq(ArgKind::Indirect)
        ret_type.type.should eq(str)
        ret_type.cast.should be_nil
        ret_type.pad.should be_nil
        ret_type.attr.should eq(Attribute::StructRet)
      end
    end
  end
end
