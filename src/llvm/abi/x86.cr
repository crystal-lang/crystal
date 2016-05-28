require "../abi"

# Based on https://github.com/rust-lang/rust/blob/master/src/librustc_trans/trans/cabi_x86.rs
class LLVM::ABI::X86 < LLVM::ABI
  def abi_info(atys : Array(Type), rty : Type, ret_def : Bool)
    ret_ty = compute_return_type(rty, ret_def)
    arg_tys = compute_arg_types(atys)
    FunctionType.new arg_tys, ret_ty
  end

  def size(type : Type)
    target_data.abi_size(type).to_i32
  end

  def align(type : Type)
    target_data.abi_alignment(type).to_i32
  end

  private def compute_return_type(rty, ret_def)
    if !ret_def
      ArgType.direct(LLVM::Void)
    elsif rty.kind == LLVM::Type::Kind::Struct
      # Returning a structure. Most often, this will use
      # a hidden first argument. On some platforms, though,
      # small structs are returned as integers.
      #
      # Some links:
      # http://www.angelcode.com/dev/callconv/callconv.html
      # Clang's ABI handling is in lib/CodeGen/TargetInfo.cpp

      if osx? || windows?
        case target_data.abi_size(rty)
        when 1 then ret_ty = ret_value(rty, LLVM::Int8)
        when 2 then ret_ty = ret_value(rty, LLVM::Int16)
        when 4 then ret_ty = ret_value(rty, LLVM::Int32)
        when 8 then ret_ty = ret_value(rty, LLVM::Int64)
        else        ret_ty = ret_pointer(rty)
        end
      else
        ret_pointer(rty)
      end
    else
      non_struct(rty)
    end
  end

  private def compute_arg_types(atys)
    atys.map do |t|
      case t.kind
      when Type::Kind::Struct
        size = target_data.abi_size(t)
        if size == 0
          ArgType.ignore(t)
        else
          ArgType.indirect(t, LLVM::Attribute::ByVal)
        end
      else
        non_struct(t)
      end
    end
  end

  private def ret_value(type, cast)
    ArgType.direct(type, cast)
  end

  private def ret_pointer(type)
    ArgType.indirect(type, LLVM::Attribute::StructRet)
  end

  private def non_struct(type)
    attr = type == LLVM::Int1 ? LLVM::Attribute::ZExt : nil
    ArgType.direct(type, attr: attr)
  end
end
