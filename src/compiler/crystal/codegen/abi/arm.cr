require "../abi"

# Based on https://github.com/rust-lang/rust/blob/dfe8bd10fe6763e0a1d5d55fa2574ecba27d3e2e/src/librustc_trans/cabi_arm.rs
class Crystal::ABI::ARM < Crystal::ABI
  def abi_info(args_types : Array(Type), return_type : Type) : FunctionType
    atys = args_types.map { |aty| @llvm_typer.llvm_c_type(aty) }
    rty = @llvm_typer.llvm_c_return_type(return_type)
    ret_def = !rty.void?

    ret_ty = compute_return_type(rty, ret_def)
    arg_tys = compute_arg_types(atys)
    FunctionType.new(arg_tys, ret_ty)
  end

  def align(type : LLVM::Type) : Int32
    align(type, 4)
  end

  def size(type : LLVM::Type) : Int32
    size(type, 4)
  end

  def register?(type) : Bool
    case type.kind
    when LLVM::Type::Kind::Integer, LLVM::Type::Kind::Float, LLVM::Type::Kind::Double, LLVM::Type::Kind::Pointer
      true
    else
      false
    end
  end

  private def compute_return_type(rty, ret_def)
    if !ret_def
      ArgType.direct(llvm_context.void)
    elsif register?(rty)
      non_struct(rty)
    else
      case size(rty)
      when 1
        ArgType.direct(rty, llvm_context.int8)
      when 2
        ArgType.direct(rty, llvm_context.int16)
      when 3, 4
        ArgType.direct(rty, llvm_context.int32)
      else
        ArgType.indirect(rty, LLVM::Attribute::StructRet)
      end
    end
  end

  private def compute_arg_types(atys)
    atys.map do |aty|
      if register?(aty)
        non_struct(aty)
      else
        if align(aty) <= 4
          ArgType.direct(aty, llvm_context.int32.array(((size(aty) + 3) // 4).to_u64))
        else
          ArgType.direct(aty, llvm_context.int64.array(((size(aty) + 7) // 8).to_u64))
        end
      end
    end
  end

  private def non_struct(type)
    attr = type == llvm_context.int1 ? LLVM::Attribute::ZExt : nil
    ArgType.direct(type, attr: attr)
  end
end
