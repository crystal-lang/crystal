require "../abi"

# Based on https://github.com/rust-lang/rust/blob/master/src/librustc_trans/trans/cabi_x86_64.rs
class LLVM::ABI::X86_64 < LLVM::ABI
  def abi_info(atys : Array(Type), rty : Type, ret_def : Bool, context : Context)
    arg_tys = Array(LLVM::Type).new(atys.size)
    arg_tys = atys.map do |arg_type|
      x86_64_type(arg_type, Attribute::ByVal, context) { |cls| pass_by_val?(cls) }
    end

    if ret_def
      ret_ty = x86_64_type(rty, Attribute::StructRet, context) { |cls| sret?(cls) }
    else
      ret_ty = ArgType.direct(context.void)
    end

    FunctionType.new arg_tys, ret_ty
  end

  def x86_64_type(type, ind_attr, context)
    if register?(type)
      attr = type == context.int1 ? Attribute::ZExt : nil
      ArgType.direct(type, attr: attr)
    else
      cls = classify(type)
      if yield cls
        ArgType.indirect(type, ind_attr)
      else
        ArgType.direct(type, llreg(context, cls))
      end
    end
  end

  def register?(type)
    case type.kind
    when Type::Kind::Integer, Type::Kind::Float, Type::Kind::Double, Type::Kind::Pointer
      true
    else
      false
    end
  end

  def pass_by_val?(cls)
    return false if cls.empty?

    cl = cls.first
    cl == RegClass::Memory || cl == RegClass::X87 || cl == RegClass::ComplexX87
  end

  def sret?(cls)
    return false if cls.empty?

    cls.first == RegClass::Memory
  end

  def classify(type)
    words = (size(type) + 7) / 8
    reg_classes = Array.new(words, RegClass::NoClass)
    if words > 4
      all_mem(reg_classes)
    else
      classify(type, reg_classes, 0, 0)
      fixup(type, reg_classes)
    end
    reg_classes
  end

  def classify(ty, cls, ix, off)
    t_align = align(ty)
    t_size = size(ty)

    misalign = off % t_align
    if misalign != 0
      i = off / 8
      e = (off + t_size + 7) / 8
      while i < e
        unify(cls, ix + 1, RegClass::Memory)
        i += 1
      end
      return
    end

    case ty.kind
    when Type::Kind::Integer, Type::Kind::Pointer
      unify(cls, ix + off / 8, RegClass::Int)
    when Type::Kind::Float
      unify(cls, ix + off / 8, (off % 8 == 4) ? RegClass::SSEFv : RegClass::SSEFs)
    when Type::Kind::Double
      unify(cls, ix + off / 8, RegClass::SSEDs)
    when Type::Kind::Struct
      classify_struct(ty.struct_element_types, cls, ix, off, ty.packed_struct?)
    when Type::Kind::Array
      len = ty.array_size
      elt = ty.element_type
      eltsz = size(elt)
      i = 0
      while i < len
        classify(elt, cls, ix, off + i * eltsz)
        i += 1
      end
    else
      raise "Unhandled Type::Kind in classify: #{ty.kind}"
    end
  end

  def classify_struct(tys, cls, i, off, packed)
    field_off = off
    tys.each do |ty|
      field_off = align(field_off, ty) unless packed
      classify(ty, cls, i, field_off)
      field_off += size(ty)
    end
  end

  def fixup(ty, cls)
    i = 0
    ty_kind = ty.kind
    e = cls.size
    if e > 2 && (ty_kind == Type::Kind::Struct || ty_kind == Type::Kind::Array)
      if cls[i].sse?
        i += 1
        while i < e
          if cls[i] != RegClass::SSEUp
            all_mem(cls)
            return
          end
          i += 1
        end
      else
        all_mem(cls)
        return
      end
    else
      while i < e
        case
        when cls[i] == RegClass::Memory
          all_mem(cls)
          return
        when cls[i] == RegClass::X87Up
          # for darwin
          # cls[i] = RegClass::SSEDs
          all_mem(cls)
          return
        when cls[i] == RegClass::SSEUp
          cls[i] = RegClass::SSEDv
        when cls[i].sse?
          i += 1
          while i != e && cls[i] == RegClass::SSEUp
            i += 1
          end
        when cls[i] == RegClass::X87
          i += 1
          while i != e && cls[i] == RegClass::X87Up
            i += 1
          end
        else
          i += 1
        end
      end
    end
  end

  def unify(cls, i, newv)
    case
    when cls[i] == newv
      return
    when cls[i] == RegClass::NoClass
      cls[i] = newv
    when newv == RegClass::NoClass
      return
    when cls[i] == RegClass::Memory, newv == RegClass::Memory
      return
    when cls[i] == RegClass::Int, newv == RegClass::Int
      return
    when cls[i] == RegClass::X87,
         cls[i] == RegClass::X87Up,
         cls[i] == RegClass::ComplexX87,
         newv == RegClass::X87,
         newv == RegClass::X87Up,
         newv == RegClass::ComplexX87
      cls[i] = RegClass::Memory
    else
      cls[i] = newv
    end
  end

  def all_mem(reg_classes)
    reg_classes.fill(RegClass::Memory)
  end

  def llreg(context, reg_classes)
    types = Array(Type).new
    i = 0
    e = reg_classes.size
    while i < e
      case reg_classes[i]
      when RegClass::Int
        types << context.int64
      when RegClass::SSEFv
        vec_len = llvec_len(reg_classes[i + 1..-1])
        vec_type = context.float.vector(vec_len * 2)
        types << vec_type
        i += vec_len
        next
      when RegClass::SSEFs
        types << context.float
      when RegClass::SSEDs
        types << context.double
      else
        raise "Unhandled RegClass: #{reg_classes[i]}"
      end
      i += 1
    end
    context.struct(types)
  end

  def llvec_len(reg_classes)
    len = 1
    reg_classes.each do |reg_class|
      break if reg_class != RegClass::SSEUp
      len += 1
    end
    len
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
      8
    when Type::Kind::Struct
      if type.packed_struct?
        1
      else
        type.struct_element_types.reduce(1) do |memo, elem|
          Math.max(memo, align(elem))
        end
      end
    when Type::Kind::Array
      align type.element_type
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
      8
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

  enum RegClass
    NoClass
    Int
    SSEFs
    SSEFv
    SSEDs
    SSEDv
    SSEInt
    SSEUp
    X87
    X87Up
    ComplexX87
    Memory

    def sse?
      case self
      when SSEFs, SSEFv, SSEDs
        true
      else
        false
      end
    end
  end
end
