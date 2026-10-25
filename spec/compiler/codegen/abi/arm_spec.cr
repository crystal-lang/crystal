require "../../../spec_helper"

{% if LibLLVM::BUILT_TARGETS.includes?(:arm) %}
  LLVM.init_arm
{% end %}

private def test(msg, &block : Crystal::ABI, LLVM::Context, Crystal::Program ->)
  it msg do
    program = Crystal::Program.new
    program.codegen_target = Crystal::Codegen::Target.new("arm-unknown-linux-gnueabihf")
    abi = Crystal::ABI::ARM.new(program.llvm_typer)
    ctx = program.llvm_typer.llvm_context
    block.call(abi, ctx, program)
  end
end

class Crystal::ABI
  describe ARM do
    {% if LibLLVM::BUILT_TARGETS.includes?(:arm) %}
      describe "align" do
        test "for integer" do |abi, ctx|
          abi.align(ctx.int1).should be_a(::Int32)
          abi.align(ctx.int1).should eq(1)
          abi.align(ctx.int8).should eq(1)
          abi.align(ctx.int16).should eq(2)
          abi.align(ctx.int32).should eq(4)
          abi.align(ctx.int64).should eq(8)
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
        test "does with primitives" do |abi, ctx, program|
          arg_types = [program.int32, program.int64]
          return_type = program.int8
          info = abi.abi_info(arg_types, return_type)
          info.arg_types.size.should eq(2)

          info.arg_types[0].should eq(ArgType.direct(ctx.int32))
          info.arg_types[1].should eq(ArgType.direct(ctx.int64))
          info.return_type.should eq(ArgType.direct(ctx.int8))
        end

        test "does with structs less than 64 bits" do |abi, ctx, program|
          str = program.extern_struct_of([program.int8, program.int16])
          arg_types = [str]
          return_type = str

          info = abi.abi_info(arg_types, return_type)
          info.arg_types.size.should eq(1)

          llvm_str = program.llvm_typer.llvm_type(str)
          info.arg_types[0].should eq(ArgType.direct(llvm_str, cast: ctx.int32.array(1)))
          info.return_type.should eq(ArgType.direct(llvm_str, cast: ctx.int32))
        end

        test "does with structs between 64 and 128 bits" do |abi, ctx, program|
          str = program.extern_struct_of([program.int64, program.int16])
          arg_types = [str]
          return_type = str

          info = abi.abi_info(arg_types, return_type)
          info.arg_types.size.should eq(1)

          llvm_str = program.llvm_typer.llvm_type(str)
          info.arg_types[0].should eq(ArgType.direct(llvm_str, cast: ctx.int64.array(2)))
          info.return_type.should eq(ArgType.indirect(llvm_str, LLVM::Attribute::StructRet))
        end

        test "does with structs larger than 128 bits" do |abi, ctx, program|
          str = program.extern_struct_of([program.int64, program.int64, program.int8])
          arg_types = [str]
          return_type = str

          info = abi.abi_info(arg_types, return_type)
          info.arg_types.size.should eq(1)

          llvm_str = program.llvm_typer.llvm_type(str)
          info.arg_types[0].should eq(ArgType.direct(llvm_str, cast: ctx.int64.array(3)))
          info.return_type.should eq(ArgType.indirect(llvm_str, LLVM::Attribute::StructRet))
        end
      end
    {% end %}
  end
end
