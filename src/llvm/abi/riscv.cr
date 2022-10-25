require "../abi"

# Based on
# https://github.com/rust-lang/rust/blob/a6bd5ae57eb0421373a4f3aa69ac56fb5c549383/src/librustc_target/abi/call/riscv.rs
class LLVM::ABI::RISCV < LLVM::ABI

  def abi_info(atys : Array(Type), rty : Type, ret_def : Bool, context : Context) : LLVM::ABI::FunctionType
    xlen = target_data.abi_size(rty)
    ret_ty = compute_return_type(rty, context, xlen)
    arg_tys = atys.map { |aty| compute_arg_type(aty, context, xlen) }
    FunctionType.new(arg_tys, ret_ty)
  end

  def align(type : Type) : Int32
    align(type, 8)
  end

  def size(type : Type) : Int32
    size(type, 8)
  end

  private def compute_return_type(rty, context, xlen)
    size = size(rty)
    if size > 2 * xlen
      ArgType.indirect(rty, LLVM::Attribute::StructRet)
    end
    extend_intefer_width_to(rty, context, xlen)
  end

  private def compute_arg_type(rty, context, xlen)
    size = size(rty)
    if size > 2 * xlen
      ArgType.indirect(rty, LLVM::Attribute::StructRet)
    end
    extend_intefer_width_to(rty, context, xlen)
  end

  private def extend_intefer_width_to(type, context, xlen)
    attr = size(type) < xlen ? LLVM::Attribute::SExt : nil
    ArgType.direct(type, attr: attr)
  end

end
