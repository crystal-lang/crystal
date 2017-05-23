require "../abi"

# Based on https://github.com/rust-lang/rust/blob/dfe8bd10fe6763e0a1d5d55fa2574ecba27d3e2e/src/librustc_trans/cabi_arm.rs
class LLVM::ABI::ARM < LLVM::ABI
  def abi_info(atys : Array(Type), rty : Type, ret_def : Bool, context : Context)
    ret_ty = compute_return_type(rty, ret_def, context)
    arg_tys = compute_arg_types(atys, context)
    FunctionType.new(arg_tys, ret_ty)
  end

  def align(type : Type)
    align(type, 4)
  end

  def size(type : Type)
    size(type, 4)
  end

  def register?(type)
    case type.kind
    when Type::Kind::Integer, Type::Kind::Float, Type::Kind::Double, Type::Kind::Pointer
      true
    else
      false
    end
  end

  private def compute_return_type(rty, ret_def, context)
    if !ret_def
      ArgType.direct(context.void)
    elsif register?(rty)
      non_struct(rty, context)
    else
      case size(rty)
      when 1
        ArgType.direct(rty, context.int8)
      when 2
        ArgType.direct(rty, context.int16)
      when 3, 4
        ArgType.direct(rty, context.int32)
      else
        ArgType.indirect(rty, LLVM::Attribute::StructRet)
      end
    end
  end

  private def compute_arg_types(atys, context)
    atys.map do |aty|
      if register?(aty)
        non_struct(aty, context)
      else
        if align(aty) <= 4
          ArgType.direct(aty, context.int32.array(((size(aty) + 3) / 4).to_u64))
        else
          ArgType.direct(aty, context.int64.array(((size(aty) + 7) / 8).to_u64))
        end
      end
    end
  end

  private def non_struct(type, context)
    attr = type == context.int1 ? LLVM::Attribute::ZExt : nil
    ArgType.direct(type, attr: attr)
  end
end
