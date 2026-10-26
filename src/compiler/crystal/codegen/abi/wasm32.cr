require "../abi"

class Crystal::ABI::Wasm32 < Crystal::ABI
  def abi_info(args_types : Array(Type), return_type : Type) : FunctionType
    atys = args_types.map { |aty| @llvm_typer.llvm_c_type(aty) }
    rty = @llvm_typer.llvm_c_return_type(return_type)
    ret_def = !rty.void?

    ret_ty = compute_return_type(rty, ret_def)
    arg_tys = compute_arg_types(atys)
    FunctionType.new(arg_tys, ret_ty)
  end

  def align(type : LLVM::Type)
    @llvm_typer.align_of(type).to_i32
  end

  def size(type : LLVM::Type)
    @llvm_typer.size_of(type).to_i32
  end

  private def aggregate?(type)
    case type.kind
    when .struct?, .array?
      true
    else
      false
    end
  end

  private def compute_return_type(rty, ret_def)
    if aggregate?(rty)
      ArgType.indirect(rty, LLVM::Attribute::ByVal)
    else
      ArgType.direct(rty)
    end
  end

  private def compute_arg_types(atys)
    atys.map do |t|
      if aggregate?(t)
        ArgType.indirect(t, LLVM::Attribute::ByVal)
      else
        ArgType.direct(t)
      end
    end
  end
end
