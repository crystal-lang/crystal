# Based on https://github.com/rust-lang/rust/blob/122cbd043833a1d7540cc5f99c458bfca2d3c525/compiler/rustc_target/src/callconv/powerpc64.rs
require "../abi"

class Crystal::ABI::PPC64 < Crystal::ABI
  ELFv1 = 1
  ELFv2 = 2

  # AIX not implemented

  def initialize(@llvm_typer : LLVMTyper, @variant : Int32)
    super(llvm_typer)
  end

  def align(type : LLVM::Type) : Int32
    align(type, 8)
  end

  def size(type : LLVM::Type) : Int32
    size(type, 8)
  end

  protected def llvm_context
    @llvm_typer.llvm_context
  end

  def abi_info(args_types : Array(Type), return_type : Type) : FunctionType
    arg_tys = args_types.map do |arg_type|
      aty = @llvm_typer.llvm_c_type(arg_type)
      classify(arg_type, aty, is_ret: false)
    end

    ret_ty = compute_return_type(return_type)
    FunctionType.new(arg_tys, ret_ty)
  end

  private def compute_return_type(return_type)
    rty = @llvm_typer.llvm_c_return_type(return_type)
    if rty.void?
      ArgType.direct(llvm_context.void)
    else
      classify(return_type, rty, is_ret: true)
    end
  end

  private def classify(type, ty, is_ret)
    case ty.kind
    when LLVM::Type::Kind::Integer
      case type
      when BoolType
        return ArgType.direct(ty, attr: LLVM::Attribute::ZExt)
      when IntegerType
        return extend_int(type, ty)
      when EnumType
        return extend_int(type.base_type, ty)
      else
        raise "BUG: unexpected integer type #{type}"
      end
    when LLVM::Type::Kind::Pointer, LLVM::Type::Kind::Double, LLVM::Type::Kind::Float
      return ArgType.direct(ty)
    end

    # The ELFv1 ABI doesn't return aggregates in registers.
    if is_ret && @variant == ELFv1
      return ArgType.indirect(ty, LLVM::Attribute::StructRet)
    end

    if agg = homogeneous_aggregate?(ty)
      uty, count = agg
      return ArgType.direct(ty, uty.array(count))
    end

    size = self.size(ty)
    bitsize = size * 8

    if is_ret && bitsize > 128
      # Non-homogeneous aggregates larger than two doublewords are returned
      # indirectly.
      ArgType.indirect(ty, LLVM::Attribute::StructRet)
    elsif bitsize <= 64
      # Aggregates smaller than a doubleword should appear in the
      # least-significant bits of the parameter doubleword.
      cast = size.zero? ? llvm_context.int64 : llvm_context.int(bitsize)
      ArgType.direct(ty, cast: cast)
    else
      # Aggregates larger than i64 should be padded at the tail to fill out a
      # whole number of i64s or i128s, depending on the aggregate alignment.
      # Always use an array for this, even if there is only a single element.
      cast = if align(ty) > 8
               llvm_context.int128.array((size + 15) // 16)
             else
               llvm_context.int64.array((size + 7) // 8)
             end
      ArgType.direct(ty, cast)
    end
  end

  # Values shorter than a doubleword are sign or zero-extended as necessary.
  private def extend_int(type : IntegerType, ty)
    attr = type.signed? ? LLVM::Attribute::SExt : LLVM::Attribute::ZExt if type.bits < 64
    ArgType.direct(ty, attr: attr)
  end

  # TODO: reduce duplication with ABI::AArch64
  private def homogeneous_aggregate?(ty) : {LLVM::Type, UInt64}?
    agg =
      case ty.kind
      when LLVM::Type::Kind::Float, LLVM::Type::Kind::Double
        return {ty, 1_u64}
      when LLVM::Type::Kind::Array
        homogeneous_array?(ty)
      when LLVM::Type::Kind::Struct
        homogeneous_struct?(ty)
      end
    return unless agg

    # ELFv1 allows 1 member
    # ELFv2 allows 8 members
    registers = @variant == ELFv1 ? 1 : 8
    agg if size(ty) <= size(agg[0]) * registers
  end

  private def homogeneous_array?(ty) : {LLVM::Type, UInt64}?
    count = ty.array_size.to_u64
    return if count == 0

    if agg = homogeneous_aggregate?(ty.element_type)
      {agg[0], count * agg[1]}
    end
  end

  private def homogeneous_struct?(ty) : {LLVM::Type, UInt64}?
    uty = nil
    count = 0_u64

    ty.struct_element_types.each do |ety|
      return unless agg = homogeneous_aggregate?(ety)

      if !uty
        # memorize first member
        uty, count = agg
      else
        # compare following members to the first
        return unless uty == agg[0]
        count += agg[1]
      end
    end
    return unless uty

    # check no padding
    if size(ty) == size(uty) * count
      {uty, count}
    end
  end
end
