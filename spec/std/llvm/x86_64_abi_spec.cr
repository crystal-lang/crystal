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
        expect(abi.align(LLVM::Int1)).to be_a(::Int32)
        expect(abi.align(LLVM::Int1)).to eq(1)
        expect(abi.align(LLVM::Int8)).to eq(1)
        expect(abi.align(LLVM::Int16)).to eq(2)
        expect(abi.align(LLVM::Int32)).to eq(4)
        expect(abi.align(LLVM::Int64)).to eq(8)
      end

      it "for pointer" do
        expect(abi.align(LLVM::Int8.pointer)).to eq(8)
      end

      it "for float" do
        expect(abi.align(LLVM::Float)).to eq(4)
      end

      it "for double" do
        expect(abi.align(LLVM::Double)).to eq(8)
      end

      it "for struct" do
        expect(abi.align(LLVM::Type.struct([LLVM::Int32, LLVM::Int64]))).to eq(8)
        expect(abi.align(LLVM::Type.struct([LLVM::Int8, LLVM::Int16]))).to eq(2)
      end

      it "for packed struct" do
        expect(abi.align(LLVM::Type.struct([LLVM::Int32, LLVM::Int64], packed: true))).to eq(1)
      end

      it "for array" do
        expect(abi.align(LLVM::Int16.array(10))).to eq(2)
      end
    end

    describe "size" do
      it "for integer" do
        expect(abi.size(LLVM::Int1)).to be_a(::Int32)
        expect(abi.size(LLVM::Int1)).to eq(1)
        expect(abi.size(LLVM::Int8)).to eq(1)
        expect(abi.size(LLVM::Int16)).to eq(2)
        expect(abi.size(LLVM::Int32)).to eq(4)
        expect(abi.size(LLVM::Int64)).to eq(8)
      end

      it "for pointer" do
        expect(abi.size(LLVM::Int8.pointer)).to eq(8)
      end

      it "for float" do
        expect(abi.size(LLVM::Float)).to eq(4)
      end

      it "for double" do
        expect(abi.size(LLVM::Double)).to eq(8)
      end

      it "for struct" do
        expect(abi.size(LLVM::Type.struct([LLVM::Int32, LLVM::Int64]))).to eq(16)
        expect(abi.size(LLVM::Type.struct([LLVM::Int16, LLVM::Int8]))).to eq(4)
        expect(abi.size(LLVM::Type.struct([LLVM::Int32, LLVM::Int8, LLVM::Int8]))).to eq(8)
      end

      it "for packed struct" do
        expect(abi.size(LLVM::Type.struct([LLVM::Int32, LLVM::Int64], packed: true))).to eq(12)
      end

      it "for array" do
        expect(abi.size(LLVM::Int16.array(10))).to eq(20)
      end
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

      it "does with structs less than 64 bits" do
        str = LLVM::Type.struct([LLVM::Int8, LLVM::Int16])
        arg_types = [str]
        return_type = str

        info = abi.abi_info(arg_types, return_type, true)
        expect(info.arg_types.length).to eq(1)

        expect(info.arg_types[0]).to eq(ArgType.direct(str, cast: LLVM::Type.struct([LLVM::Int64])))
        expect(info.return_type).to eq(ArgType.direct(str, cast: LLVM::Type.struct([LLVM::Int64])))
      end

      it "does with structs between 64 and 128 bits" do
        str = LLVM::Type.struct([LLVM::Int64, LLVM::Int16])
        arg_types = [str]
        return_type = str

        info = abi.abi_info(arg_types, return_type, true)
        expect(info.arg_types.length).to eq(1)

        expect(info.arg_types[0]).to eq(ArgType.direct(str, cast: LLVM::Type.struct([LLVM::Int64, LLVM::Int64])))
        expect(info.return_type).to eq(ArgType.direct(str, cast: LLVM::Type.struct([LLVM::Int64, LLVM::Int64])))
      end

      it "does with structs between 64 and 128 bits" do
        str = LLVM::Type.struct([LLVM::Int64, LLVM::Int64, LLVM::Int8])
        arg_types = [str]
        return_type = str

        info = abi.abi_info(arg_types, return_type, true)
        expect(info.arg_types.length).to eq(1)

        expect(info.arg_types[0]).to eq(ArgType.indirect(str, Attribute::ByVal))
        expect(info.return_type).to eq(ArgType.indirect(str, Attribute::StructRet))
      end
    end
  end
end
