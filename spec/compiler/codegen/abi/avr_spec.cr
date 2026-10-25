require "../../../spec_helper"

{% if LibLLVM::BUILT_TARGETS.includes?(:avr) %}
  LLVM.init_avr
{% end %}

private def test(msg, &block : Crystal::ABI, LLVM::Context, Crystal::Program ->)
  it msg do
    program = Crystal::Program.new
    program.codegen_target = Crystal::Codegen::Target.new("avr-unknown-unknown-atmega328p")
    program.target_machine = program.codegen_target.to_target_machine(cpu: "atmega328p")
    abi = Crystal::ABI::AVR.new(program.llvm_typer)
    ctx = program.llvm_typer.llvm_context
    block.call(abi, ctx, program)
  end
end

class Crystal::ABI
  describe AVR do
    {% if LibLLVM::BUILT_TARGETS.includes?(:avr) %}
      describe "align" do
        test "for integer" do |abi, ctx|
          abi.align(ctx.int1).should be_a(::Int32)
          abi.align(ctx.int1).should eq(1)
          abi.align(ctx.int8).should eq(1)
          abi.align(ctx.int16).should eq(1)
          abi.align(ctx.int32).should eq(1)
          abi.align(ctx.int64).should eq(1)
        end

        test "for pointer" do |abi, ctx|
          abi.align(ctx.int8.pointer).should eq(1)
        end

        test "for float" do |abi, ctx|
          abi.align(ctx.float).should eq(1)
        end

        test "for double" do |abi, ctx|
          abi.align(ctx.double).should eq(1)
        end

        test "for struct" do |abi, ctx|
          abi.align(ctx.struct([ctx.int32, ctx.int64])).should eq(1)
          abi.align(ctx.struct([ctx.int8, ctx.int16])).should eq(1)
        end

        test "for packed struct" do |abi, ctx|
          abi.align(ctx.struct([ctx.int32, ctx.int64], packed: true)).should eq(1)
        end

        test "for array" do |abi, ctx|
          abi.align(ctx.int16.array(10)).should eq(1)
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
          abi.size(ctx.int8.pointer).should eq(2)
        end

        test "for float" do |abi, ctx|
          abi.size(ctx.float).should eq(4)
        end

        test "for double" do |abi, ctx|
          abi.size(ctx.double).should eq(8)
        end

        test "for struct" do |abi, ctx|
          abi.size(ctx.struct([ctx.int32, ctx.int64])).should eq(12)
          abi.size(ctx.struct([ctx.int16, ctx.int8])).should eq(3)
          abi.size(ctx.struct([ctx.int32, ctx.int8, ctx.int8])).should eq(6)
        end

        test "for packed struct" do |abi, ctx|
          abi.size(ctx.struct([ctx.int32, ctx.int8], packed: true)).should eq(5)
        end

        test "for array" do |abi, ctx|
          abi.size(ctx.int16.array(10)).should eq(20)
        end
      end

      describe "abi_info" do
        test "int1" do |abi, ctx, program|
          arg_type = ArgType.direct(ctx.int1)
          info = abi.abi_info([program.bool], program.bool)
          info.arg_types.size.should eq(1)
          info.arg_types[0].should eq(arg_type)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.return_type.should eq(arg_type)
          info.return_type.kind.should eq(Crystal::ABI::ArgKind::Direct)
        end

        {% for bits in [8, 16, 32, 64] %}
          test "int{{bits}}" do |abi, ctx, program|
            arg_type = ArgType.direct(ctx.int{{bits}})
            info = abi.abi_info([program.int{{bits}}], program.int{{bits}})
            info.arg_types.size.should eq(1)
            info.arg_types[0].should eq(arg_type)
            info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
            info.return_type.should eq(arg_type)
            info.return_type.kind.should eq(Crystal::ABI::ArgKind::Direct)
          end
        {% end %}

        test "float" do |abi, ctx, program|
          arg_type = ArgType.direct(ctx.float)
          info = abi.abi_info([program.float32], program.float32)
          info.arg_types.size.should eq(1)
          info.arg_types[0].should eq(arg_type)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.return_type.should eq(arg_type)
          info.return_type.kind.should eq(Crystal::ABI::ArgKind::Direct)
        end

        test "double" do |abi, ctx, program|
          arg_type = ArgType.direct(ctx.double)
          info = abi.abi_info([program.float64], program.float64)
          info.arg_types.size.should eq(1)
          info.arg_types[0].should eq(arg_type)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.return_type.should eq(arg_type)
          info.return_type.kind.should eq(Crystal::ABI::ArgKind::Direct)
        end

        test "multiple arguments" do |abi, ctx, program|
          args = Array.new(9) { program.int16 }
          info = abi.abi_info(args, program.int8)
          info.arg_types.size.should eq(9)
          info.arg_types.each(&.kind.should eq(Crystal::ABI::ArgKind::Direct))
        end

        test "multiple arguments above registers" do |abi, ctx, program|
          args = Array.new(5) { program.int32 }
          info = abi.abi_info(args, program.int8)
          info.arg_types.size.should eq(5)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[1].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[2].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[3].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[4].kind.should eq(Crystal::ABI::ArgKind::Indirect)
        end

        test "struct args within 18 bytes" do |abi, ctx, program|
          args = [
            program.int8,                                             # rounded to 2 bytes
            program.extern_struct_of([program.int32, program.int32]), # 8 bytes
            program.extern_struct_of([program.int32, program.int32]), # 8 bytes
          ]
          info = abi.abi_info(args, program.void)
          info.arg_types.size.should eq(3)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[1].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[2].kind.should eq(Crystal::ABI::ArgKind::Direct)
        end

        test "struct args over 18 bytes" do |abi, ctx, program|
          args = [
            program.int32,                                            # 4 bytes
            program.extern_struct_of([program.int32, program.int32]), # 8 bytes
            program.extern_struct_of([program.int32, program.int32]), # 8 bytes
          ]
          info = abi.abi_info(args, program.void)
          info.arg_types.size.should eq(3)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[1].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[2].kind.should eq(Crystal::ABI::ArgKind::Indirect)
        end

        test "returns struct within 8 bytes" do |abi, ctx, program|
          rty = program.extern_struct_of([program.int32, program.int32])
          info = abi.abi_info([] of Crystal::Type, rty)
          info.return_type.kind.should eq(Crystal::ABI::ArgKind::Direct)
        end

        test "returns struct over 8 bytes" do |abi, ctx, program|
          rty = program.extern_struct_of([program.int32, program.int32, program.int8])
          info = abi.abi_info([] of Crystal::Type, rty)
          info.return_type.kind.should eq(Crystal::ABI::ArgKind::Indirect)
        end
      end
    {% end %}
  end
end
