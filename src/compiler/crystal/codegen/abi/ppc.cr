# Based on https://github.com/rust-lang/rust/blob/d3e1ccdf40ae7b7a6dc81edc073d80dad7b66f75/compiler/rustc_target/src/callconv/powerpc.rs
require "../abi"

class Crystal::ABI::PPC < Crystal::ABI
  def initialize(@llvm_typer : LLVMTyper)
    @linux = @llvm_typer.target_machine.triple =~ /-linux-(?:musl|gnu|uclibc)/
    super(llvm_typer)
  end

  def align(type : LLVM::Type) : Int32
    align(type, 4)
  end

  def size(type : LLVM::Type) : Int32
    size(type, 4)
  end

  protected def llvm_context
    @llvm_typer.llvm_context
  end

  def abi_info(args_types : Array(Type), return_type : Type) : FunctionType
    args_tys = args_types.map { |arg_type| compute_arg_type(arg_type) }
    ret_ty = compute_return_type(return_type)
    FunctionType.new(args_tys, ret_ty)
  end

  private def compute_arg_type(arg_type)
    aty = @llvm_typer.llvm_c_type(arg_type)
    if size(aty) == 0
      if @linux
        ArgType.indirect(aty, LLVM::Attribute::ByVal)
      else
        ArgType.ignore(aty)
      end
    else
      classify(arg_type, aty, is_ret: false)
    end
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
        ArgType.direct(ty, attr: LLVM::Attribute::ZExt)
      when IntegerType
        extend_int(type, ty)
      when EnumType
        extend_int(type.base_type, ty)
      else
        raise "BUG: unexpected integer type #{type}"
      end
    when LLVM::Type::Kind::Pointer, LLVM::Type::Kind::Double, LLVM::Type::Kind::Float
      ArgType.direct(ty)
    else
      attr = is_ret ? LLVM::Attribute::StructRet : LLVM::Attribute::ByVal
      ArgType.indirect(ty, attr)
    end
  end

  # Values shorter than a word are sign or zero-extended as necessary.
  private def extend_int(type : IntegerType, ty)
    attr = type.signed? ? LLVM::Attribute::SExt : LLVM::Attribute::ZExt if type.bits < 32
    ArgType.direct(ty, attr: attr)
  end
end
