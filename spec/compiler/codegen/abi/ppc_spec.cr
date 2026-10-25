require "../../../spec_helper"

{% skip_file unless LibLLVM::BUILT_TARGETS.includes?(:powerpc) %}
LLVM.init_powerpc

private def test(msg, &block : Crystal::ABI, LLVM::Context, Crystal::Program ->)
  it msg do
    program = Crystal::Program.new
    program.codegen_target = Crystal::Codegen::Target.new("ppc-unknown-linux-gnu")
    abi = Crystal::ABI::PPC.new(program.llvm_typer)
    ctx = program.llvm_typer.llvm_context
    block.call(abi, ctx, program)
  end
end

class Crystal::ABI
  describe PPC do
    describe "align" do
      test "for integer" do |abi, ctx|
        abi.align(ctx.int1).should be_a(::Int32)
        abi.align(ctx.int1).should eq(1)
        abi.align(ctx.int8).should eq(1)
        abi.align(ctx.int16).should eq(2)
        abi.align(ctx.int32).should eq(4)
        abi.align(ctx.int64).should eq(8)
        abi.align(ctx.int128).should eq(16)
      end

      test "for pointer" do |abi, ctx|
        abi.align(ctx.int8.pointer).should eq(4)
      end

      test "for float" do |abi, ctx|
        abi.align(ctx.float).should eq(4)
      end

      test "for double" do |abi, ctx|
        abi.align(ctx.double).should eq(8)
      end

      test "for struct" do |abi, ctx|
        abi.align(ctx.struct([ctx.int32, ctx.int64])).should eq(8)
        abi.align(ctx.struct([ctx.int8, ctx.int16])).should eq(2)
      end

      test "for packed struct" do |abi, ctx|
        abi.align(ctx.struct([ctx.int32, ctx.int64], packed: true)).should eq(1)
      end

      test "for array" do |abi, ctx|
        abi.align(ctx.int16.array(10)).should eq(2)
      end
    end

    describe "size" do
      test "for integer" do |abi, ctx|
        abi.size(ctx.int1).should be_a(::Int32)
        abi.size(ctx.int1).should eq(1)
        abi.size(ctx.int8).should eq(1)
        abi.size(ctx.int16).should eq(2)
        abi.size(ctx.int32).should eq(4)
        abi.size(ctx.int64).should eq(8)
        abi.size(ctx.int128).should eq(16)
      end

      test "for pointer" do |abi, ctx|
        abi.size(ctx.int8.pointer).should eq(4)
      end

      test "for float" do |abi, ctx|
        abi.size(ctx.float).should eq(4)
      end

      test "for double" do |abi, ctx|
        abi.size(ctx.double).should eq(8)
      end

      test "for struct" do |abi, ctx|
        abi.size(ctx.struct([ctx.int32, ctx.int64])).should eq(16)
        abi.size(ctx.struct([ctx.int16, ctx.int8])).should eq(4)
        abi.size(ctx.struct([ctx.int32, ctx.int8, ctx.int8])).should eq(8)
      end

      test "for packed struct" do |abi, ctx|
        abi.size(ctx.struct([ctx.int32, ctx.int64], packed: true)).should eq(12)
      end

      test "for array" do |abi, ctx|
        abi.size(ctx.int16.array(10)).should eq(20)
      end
    end

    describe "abi_info" do
      test "classifies bool" do |abi, ctx, program|
        info = abi.abi_info([program.bool], program.bool)
        info.arg_types.should eq [ArgType.direct(ctx.int1, attr: LLVM::Attribute::ZExt)]
        info.return_type.should eq(ArgType.direct(ctx.int1, attr: LLVM::Attribute::ZExt))
      end

      test "classifies integers" do |abi, ctx, program|
        [
          program.int8, program.uint8,
          program.int16, program.uint16,
          program.int32, program.uint32,
          program.int64, program.uint64,
          program.int128, program.uint128,
        ].each do |type|
          ty = ctx.int(type.bits)
          attr = type.signed? ? LLVM::Attribute::SExt : LLVM::Attribute::ZExt if type.bits < 32

          info = abi.abi_info([type], type)
          info.arg_types.should eq [ArgType.direct(ty, attr: attr)]
          info.return_type.should eq(ArgType.direct(ty, attr: attr))
        end
      end

      test "classifies enums using their integer type" do |abi, ctx, program|
        [
          program.int8, program.uint8,
          program.int16, program.uint16,
          program.int32, program.uint32,
          program.int64, program.uint64,
          program.int128, program.uint128,
        ].each do |base_type|
          enum_type = EnumType.new(program, program, "TestEnum", base_type)
          ty = ctx.int(base_type.bits)
          attr = base_type.signed? ? LLVM::Attribute::SExt : LLVM::Attribute::ZExt if base_type.bits < 32

          info = abi.abi_info([enum_type], enum_type)
          info.arg_types.should eq [ArgType.direct(ty, attr: attr)]
          info.return_type.should eq(ArgType.direct(ty, attr: attr))
        end
      end

      test "does with structs less than 64 bits" do |abi, ctx, program|
        str = program.extern_struct_of([program.int8, program.int16])
        arg_types = [str]
        return_type = str

        info = abi.abi_info(arg_types, return_type)
        info.arg_types.size.should eq(1)

        llvm_str = program.llvm_typer.llvm_type(str)
        info.arg_types[0].should eq(ArgType.indirect(llvm_str, attr: LLVM::Attribute::ByVal))
        info.return_type.should eq(ArgType.indirect(llvm_str, attr: LLVM::Attribute::StructRet))
      end

      test "does with structs between 64 and 128 bits" do |abi, ctx, program|
        str = program.extern_struct_of([program.int64, program.int16])
        arg_types = [str]
        return_type = str

        info = abi.abi_info(arg_types, return_type)
        info.arg_types.size.should eq(1)

        llvm_str = program.llvm_typer.llvm_type(str)
        info.arg_types[0].should eq(ArgType.indirect(llvm_str, attr: LLVM::Attribute::ByVal))
        info.return_type.should eq(ArgType.indirect(llvm_str, attr: LLVM::Attribute::StructRet))
      end

      test "does with structs larger than 128 bits" do |abi, ctx, program|
        str = program.extern_struct_of([program.int64, program.int64, program.int8])
        arg_types = [str]
        return_type = str

        info = abi.abi_info(arg_types, return_type)
        info.arg_types.size.should eq(1)

        llvm_str = program.llvm_typer.llvm_type(str)
        info.arg_types[0].should eq(ArgType.indirect(llvm_str, LLVM::Attribute::ByVal))
        info.return_type.should eq(ArgType.indirect(llvm_str, LLVM::Attribute::StructRet))
      end
    end
  end
end
