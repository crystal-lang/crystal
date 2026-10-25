require "../../../spec_helper"

{% skip_file unless LibLLVM::BUILT_TARGETS.includes?(:powerpc) %}
LLVM.init_powerpc

private def test(msg, triple, variant, &block : Crystal::ABI, LLVM::Context, Crystal::Program ->)
  it msg do
    program = Crystal::Program.new
    program.codegen_target = Crystal::Codegen::Target.new(triple)
    abi = Crystal::ABI::PPC64.new(program.llvm_typer, variant)
    ctx = program.llvm_typer.llvm_context
    block.call(abi, ctx, program)
  end
end

private def test(msg, &block : Crystal::ABI, LLVM::Context, Crystal::Program ->)
  test msg, "ppc64le-unknown-linux-gnu", Crystal::ABI::PPC64::ELFv1, &block
end

class Crystal::ABI
  describe PPC64 do
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
        abi.align(ctx.int8.pointer).should eq(8)
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
        abi.size(ctx.int8.pointer).should eq(8)
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
          attr = type.signed? ? LLVM::Attribute::SExt : LLVM::Attribute::ZExt if type.bits < 64

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
          attr = base_type.signed? ? LLVM::Attribute::SExt : LLVM::Attribute::ZExt if base_type.bits < 64

          info = abi.abi_info([enum_type], enum_type)
          info.arg_types.should eq [ArgType.direct(ty, attr: attr)]
          info.return_type.should eq(ArgType.direct(ty, attr: attr))
        end
      end

      [
        {"ppc64-unknown-linux-gnu", PPC64::ELFv1},
        {"ppc64-unknown-freebsd", PPC64::ELFv2},
        {"ppc64le-unknown-linux-gnu", PPC64::ELFv1},
        {"ppc64le-unknown-linux-musl", PPC64::ELFv2},
      ].each do |(triple, variant)|
        describe "#{triple} ELFv#{variant}" do
          test "classifies structs smaller than 64 bits", triple, variant do |abi, ctx, program|
            type = program.extern_struct_of([program.int8, program.int16])
            ty = program.llvm_typer.llvm_type(type)

            info = abi.abi_info([type], type)
            info.arg_types.should eq [ArgType.direct(ty, ctx.int32)]

            case variant
            when PPC64::ELFv1
              info.return_type.should eq(ArgType.indirect(ty, LLVM::Attribute::StructRet))
            when PPC64::ELFv2
              info.return_type.should eq(ArgType.direct(ty, ctx.int32))
            end
          end

          test "places small aggregate contents in the least-significant register bits", triple, variant do |abi, ctx, program|
            (1..8).each do |bytes|
              type = program.extern_struct_of([program.static_array_of(program.uint8, bytes)])
              ty = program.llvm_typer.llvm_type(type)
              cast = ctx.int(bytes * 8)

              info = abi.abi_info([type], type)
              info.arg_types.should eq [ArgType.direct(ty, cast)]

              case variant
              when PPC64::ELFv1
                info.return_type.should eq(ArgType.indirect(ty, LLVM::Attribute::StructRet))
              when PPC64::ELFv2
                info.return_type.should eq(ArgType.direct(ty, cast))
              end
            end
          end

          test "classifies structs between 64 and 128 bits", triple, variant do |abi, ctx, program|
            [2, 3, 4].each do |count|
              type = program.extern_struct_of(Array(Type).new(count, program.int32))
              ty = program.llvm_typer.llvm_type(type)
              cast = count == 2 ? ctx.int64 : ctx.int64.array(2)

              info = abi.abi_info([type], type)
              info.arg_types.should eq [ArgType.direct(ty, cast)]

              case variant
              when PPC64::ELFv1
                info.return_type.should eq(ArgType.indirect(ty, LLVM::Attribute::StructRet))
              when PPC64::ELFv2
                info.return_type.should eq(ArgType.direct(ty, cast))
              end
            end
          end

          test "classifies 128-bit structs aligned to 16 bytes", triple, variant do |abi, ctx, program|
            type = program.extern_struct_of([program.int128])
            ty = program.llvm_typer.llvm_type(type)

            info = abi.abi_info([type], type)
            info.arg_types.should eq [ArgType.direct(ty, ctx.int128.array(1))]

            case variant
            when PPC64::ELFv1
              info.return_type.should eq(ArgType.indirect(ty, LLVM::Attribute::StructRet))
            when PPC64::ELFv2
              info.return_type.should eq(ArgType.direct(ty, ctx.int128.array(1)))
            end
          end

          test "classifies homogeneous float structs smaller than 64 bits", triple, variant do |abi, ctx, program|
            type = program.extern_struct_of([program.float32])
            ty = program.llvm_typer.llvm_type(type)

            info = abi.abi_info([type], type)
            info.arg_types.should eq [ArgType.direct(ty, ctx.float.array(1))]

            case variant
            when PPC64::ELFv1
              info.return_type.should eq(ArgType.indirect(ty, LLVM::Attribute::StructRet))
            when PPC64::ELFv2
              info.return_type.should eq(ArgType.direct(ty, ctx.float.array(1)))
            end
          end

          test "classifies homogeneous float structs between 64 and 128 bits", triple, variant do |abi, ctx, program|
            [
              {program.float32, 2},
              {program.float32, 3},
              {program.float32, 4},
              {program.float64, 1},
              {program.float64, 2},
            ].each do |element_type, count|
              type = program.extern_struct_of(Array(Type).new(count, element_type))
              ty = program.llvm_typer.llvm_type(type)

              if variant == PPC64::ELFv2 || count == 1
                cast = program.llvm_typer.llvm_type(element_type).array(count)
              else
                cast = abi.size(ty) == 8 ? ctx.int64 : ctx.int64.array(2)
              end

              info = abi.abi_info([type], type)
              info.arg_types.should eq [ArgType.direct(ty, cast)]

              case variant
              when PPC64::ELFv1
                info.return_type.should eq(ArgType.indirect(ty, LLVM::Attribute::StructRet))
              when PPC64::ELFv2
                info.return_type.should eq(ArgType.direct(ty, cast))
              end
            end
          end

          test "classifies homogeneous float structs larger than 128 bits", triple, variant do |abi, ctx, program|
            [
              {program.float32, 5},
              {program.float32, 8},
              {program.float32, 9},
              {program.float64, 3},
              {program.float64, 8},
              {program.float64, 9},
            ].each do |element_type, count|
              type = program.extern_struct_of(Array(Type).new(count, element_type))
              ty = program.llvm_typer.llvm_type(type)

              if variant == PPC64::ELFv2 && count <= 8
                cast = program.llvm_typer.llvm_type(element_type).array(count)
                ret = ArgType.direct(ty, cast)
              else
                cast = ctx.int64.array((abi.size(ty) + 7) // 8)
                ret = ArgType.indirect(ty, LLVM::Attribute::StructRet)
              end

              info = abi.abi_info([type], type)
              info.arg_types.should eq [ArgType.direct(ty, cast)]
              info.return_type.should eq(ret)
            end
          end

          test "passes every doubleword of large aggregate arguments", triple, variant do |abi, ctx, program|
            [3, 4, 9].each do |count|
              type = program.extern_struct_of(Array(Type).new(count, program.int64))
              ty = program.llvm_typer.llvm_type(type)

              info = abi.abi_info([type], type)
              info.arg_types.should eq [ArgType.direct(ty, ctx.int64.array(count))]
              info.return_type.should eq(ArgType.indirect(ty, LLVM::Attribute::StructRet))
            end
          end

          test "rounds packed aggregate arguments up to a whole doubleword", triple, variant do |abi, ctx, program|
            type = program.extern_struct_of([program.int64, program.int64, program.int8], packed: true)
            ty = program.llvm_typer.llvm_type(type)

            info = abi.abi_info([type], program.nil)
            info.arg_types.should eq [ArgType.direct(ty, ctx.int64.array(3))]
          end

          test "passes every quadword of aggregate arguments aligned to 16 bytes", triple, variant do |abi, ctx, program|
            [1, 2, 3].each do |count|
              type = program.extern_struct_of(Array(Type).new(count, program.int128))
              ty = program.llvm_typer.llvm_type(type)

              info = abi.abi_info([type], program.nil)
              info.arg_types.should eq [ArgType.direct(ty, ctx.int128.array(count))]
            end
          end

          test "includes tail padding in arguments aligned to 16 bytes", triple, variant do |abi, ctx, program|
            type = program.extern_struct_of([program.int128, program.int64])
            ty = program.llvm_typer.llvm_type(type)

            info = abi.abi_info([type], program.nil)
            info.arg_types.should eq [ArgType.direct(ty, ctx.int128.array(2))]
          end
        end
      end
    end
  end
end
