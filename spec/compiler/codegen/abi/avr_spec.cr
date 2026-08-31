require "spec"
require "llvm"
require "compiler/crystal/codegen/abi/avr"

{% if LibLLVM::BUILT_TARGETS.includes?(:avr) %}
  LLVM.init_avr
{% end %}

private def abi
  triple = "avr-unknown-unknown-atmega328p"
  target = LLVM::Target.from_triple(triple)
  machine = target.create_target_machine(triple)
  machine.enable_global_isel = false
  Crystal::ABI::AVR.new(machine)
end

private def test(msg, &block : Crystal::ABI, LLVM::Context ->)
  it msg do
    abi = abi()
    ctx = LLVM::Context.new
    block.call(abi, ctx)
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
        {% for bits in [1, 8, 16, 32, 64] %}
          test "int{{ bits }}" do |abi, ctx|
            arg_type = ArgType.direct(ctx.int{{ bits }})
            info = abi.abi_info([ctx.int{{ bits }}], ctx.int{{ bits }}, true, ctx)
            info.arg_types.size.should eq(1)
            info.arg_types[0].should eq(arg_type)
            info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
            info.return_type.should eq(arg_type)
            info.return_type.kind.should eq(Crystal::ABI::ArgKind::Direct)
          end
        {% end %}

        test "float" do |abi, ctx|
          arg_type = ArgType.direct(ctx.float)
          info = abi.abi_info([ctx.float], ctx.float, true, ctx)
          info.arg_types.size.should eq(1)
          info.arg_types[0].should eq(arg_type)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.return_type.should eq(arg_type)
          info.return_type.kind.should eq(Crystal::ABI::ArgKind::Direct)
        end

        test "double" do |abi, ctx|
          arg_type = ArgType.direct(ctx.double)
          info = abi.abi_info([ctx.double], ctx.double, true, ctx)
          info.arg_types.size.should eq(1)
          info.arg_types[0].should eq(arg_type)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.return_type.should eq(arg_type)
          info.return_type.kind.should eq(Crystal::ABI::ArgKind::Direct)
        end

        test "multiple arguments" do |abi, ctx|
          args = Array.new(9) { ctx.int16 }
          info = abi.abi_info(args, ctx.int8, false, ctx)
          info.arg_types.size.should eq(9)
          info.arg_types.each(&.kind.should eq(Crystal::ABI::ArgKind::Direct))
        end

        test "multiple arguments above registers" do |abi, ctx|
          args = Array.new(5) { ctx.int32 }
          info = abi.abi_info(args, ctx.int8, false, ctx)
          info.arg_types.size.should eq(5)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[1].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[2].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[3].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[4].kind.should eq(Crystal::ABI::ArgKind::Indirect)
        end

        test "struct args within 18 bytes" do |abi, ctx|
          args = [
            ctx.int8,                           # rounded to 2 bytes
            ctx.struct([ctx.int32, ctx.int32]), # 8 bytes
            ctx.struct([ctx.int32, ctx.int32]), # 8 bytes
          ]
          info = abi.abi_info(args, ctx.void, false, ctx)
          info.arg_types.size.should eq(3)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[1].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[2].kind.should eq(Crystal::ABI::ArgKind::Direct)
        end

        test "struct args over 18 bytes" do |abi, ctx|
          args = [
            ctx.int32,                          # 4 bytes
            ctx.struct([ctx.int32, ctx.int32]), # 8 bytes
            ctx.struct([ctx.int32, ctx.int32]), # 8 bytes
          ]
          info = abi.abi_info(args, ctx.void, false, ctx)
          info.arg_types.size.should eq(3)
          info.arg_types[0].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[1].kind.should eq(Crystal::ABI::ArgKind::Direct)
          info.arg_types[2].kind.should eq(Crystal::ABI::ArgKind::Indirect)
        end

        test "returns struct within 8 bytes" do |abi, ctx|
          rty = ctx.struct([ctx.int32, ctx.int32])
          info = abi.abi_info([] of LLVM::Type, rty, true, ctx)
          info.return_type.kind.should eq(Crystal::ABI::ArgKind::Direct)
        end

        test "returns struct over 8 bytes" do |abi, ctx|
          rty = ctx.struct([ctx.int32, ctx.int32, ctx.int8])
          info = abi.abi_info([] of LLVM::Type, rty, true, ctx)
          info.return_type.kind.should eq(Crystal::ABI::ArgKind::Indirect)
        end
      end
    {% end %}
  end
end
