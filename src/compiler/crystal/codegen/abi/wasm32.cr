require "../abi"

class Crystal::ABI::Wasm32 < Crystal::ABI
  def abi_info(atys : Array(LLVM::Type), rty : LLVM::Type, ret_def : Bool, context : LLVM::Context)
    ret_ty = compute_return_type(rty, ret_def, context)
    arg_tys = compute_arg_types(atys, context)
    FunctionType.new(arg_tys, ret_ty)
  end

  def align(type : LLVM::Type)
    target_data.abi_alignment(type).to_i32
  end

  def size(type : LLVM::Type)
    target_data.abi_size(type).to_i32
  end

  private def aggregate?(type)
    case type.kind
    when .struct?, .array?
      true
    else
      false
    end
  end

  private def compute_return_type(rty, ret_def, context)
    if aggregate?(rty)
      ArgType.indirect(rty, LLVM::Attribute::ByVal)
    else
      ArgType.direct(rty)
    end
  end

  private def compute_arg_types(atys, context)
    atys.map do |t|
      if aggregate?(t)
        ArgType.indirect(t, LLVM::Attribute::ByVal)
      else
        ArgType.direct(t)
      end
    end
  end
end
