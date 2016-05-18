require "../abi"

class LLVM::ABI::ASMJS < LLVM::ABI

  def abi_info(atys : Array(Type), rty : Type, ret_def : Bool)
    ret_ty = compute_return_type(rty, ret_def)
    arg_tys = compute_arg_types(atys)
    FunctionType.new arg_tys, ret_ty
  end

  private def compute_return_type(rty, ret_def)
    case rty.kind
    when Type::Kind::Struct
      ArgType.indirect(rty, LLVM::Attribute::ByVal)
    when Type::Kind::Array
      ArgType.indirect(rty, LLVM::Attribute::ByVal)
    else
      ArgType.direct(rty)
    end
  end

  private def compute_arg_types(atys)
    atys.map do |t|
      ArgType.indirect(t, LLVM::Attribute::ByVal)
    end
  end

  def size(type : Type)
    target_data.abi_size(type)
  end

  def align(type : Type)
    target_data.abi_alignment(type)
  end

end
