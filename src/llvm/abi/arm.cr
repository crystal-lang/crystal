require "../abi"

# Based on https://github.com/rust-lang/rust/blob/dfe8bd10fe6763e0a1d5d55fa2574ecba27d3e2e/src/librustc_trans/cabi_arm.rs
class LLVM::ABI::ARM < LLVM::ABI
  def abi_info(atys : Array(Type), rty : Type, ret_def : Bool)
    ret_ty = compute_return_type(rty, ret_def)
    arg_tys = compute_arg_types(atys)
    FunctionType.new(arg_tys, ret_ty)
  end

  def align(type : Type)
    case type.kind
    when Type::Kind::Integer
      (type.int_width + 7) / 8
    when Type::Kind::Float
      4
    when Type::Kind::Double
      8
    when Type::Kind::Pointer
      4
    when Type::Kind::Struct
      if type.packed_struct?
        1
      else
        type.struct_element_types.reduce(1) do |memo, elem|
          Math.max(memo, align(elem))
        end
      end
    when Type::Kind::Array
      align(type.element_type)
    else
      raise "Unhandled Type::Kind in align: #{type.kind}"
    end
  end

  def size(type : Type)
    case type.kind
    when Type::Kind::Integer
      (type.int_width + 7) / 8
    when Type::Kind::Float
      4
    when Type::Kind::Double
      8
    when Type::Kind::Pointer
      4
    when Type::Kind::Struct
      if type.packed_struct?
        type.struct_element_types.reduce(0) do |memo, elem|
          memo + size(elem)
        end
      else
        size = type.struct_element_types.reduce(0) do |memo, elem|
          align(memo, elem) + size(elem)
        end
        align(size, type)
      end
    when Type::Kind::Array
      size(type.element_type) * type.array_size
    else
      raise "Unhandled Type::Kind in size: #{type.kind}"
    end
  end

  def align(offset, type)
    align = align(type)
    (offset + align - 1) / align * align
  end

  def register?(type)
    case type.kind
    when Type::Kind::Integer, Type::Kind::Float, Type::Kind::Double, Type::Kind::Pointer
      true
    else
      false
    end
  end

  private def compute_return_type(rty, ret_def)
    if !ret_def
      ArgType.direct(LLVM::Void)
    elsif register?(rty)
      non_struct(rty)
    else
      case size(rty)
      when 1
        ArgType.direct(rty, LLVM::Int8)
      when 2
        ArgType.direct(rty, LLVM::Int16)
      when 3, 4
        ArgType.direct(rty, LLVM::Int32)
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
          ArgType.direct(aty, Type.new(LibLLVM.array_type(LLVM::Int32, ((size(aty) + 3) / 4).to_u64)))
        else
          ArgType.direct(aty, Type.new(LibLLVM.array_type(LLVM::Int64, ((size(aty) + 7) / 8).to_u64)))
        end
      end
    end
  end

  private def non_struct(type)
    attr = type == LLVM::Int1 ? LLVM::Attribute::ZExt : nil
    ArgType.direct(type, attr: attr)
  end
end
