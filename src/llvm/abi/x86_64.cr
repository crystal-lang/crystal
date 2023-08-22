require "../abi"

# Based on https://github.com/rust-lang/rust/blob/29ac04402d53d358a1f6200bea45a301ff05b2d1/src/librustc_trans/trans/cabi_x86_64.rs
# See also, section 3.2.3 of the System V Application Binary Interface AMD64 Architecture Processor Supplement
class LLVM::ABI::X86_64 < LLVM::ABI
  MAX_INT_REGS = 6 # %rdi, %rsi, %rdx, %rcx, %r8, %r9
  MAX_SSE_REGS = 8 # %xmm0-%xmm7

  def abi_info(atys : Array(Type), rty : Type, ret_def : Bool, context : Context) : LLVM::ABI::FunctionType
    # registers available to pass arguments directly: int_regs can hold integers
    # and pointers, sse_regs can hold floats and doubles
    available_int_regs = MAX_INT_REGS
    available_sse_regs = MAX_SSE_REGS

    if ret_def
      ret_ty, _, _ = x86_64_type(rty, Attribute::StructRet, context) { |cls| sret?(cls) }
      if ret_ty.kind.indirect?
        # return value is a caller-allocated struct which is passed in %rdi,
        # so we have 1 less register available for passing arguments
        available_int_regs -= 1
      end
    else
      ret_ty = ArgType.direct(context.void)
    end

    arg_tys = atys.map do |arg_type|
      abi_type, needed_int_regs, needed_sse_regs = x86_64_type(arg_type, Attribute::ByVal, context) { |cls| pass_by_val?(cls) }
      if available_int_regs >= needed_int_regs && available_sse_regs >= needed_sse_regs
        available_int_regs -= needed_int_regs
        available_sse_regs -= needed_sse_regs
        abi_type
      elsif !register?(arg_type)
        # no available registers to pass the argument, but only mark aggregates
        # as indirect byval types because LLVM will automatically pass register
        # types in the stack
        ArgType.indirect(arg_type, Attribute::ByVal)
      else
        abi_type
      end
    end

    FunctionType.new arg_tys, ret_ty
  end

  # returns the LLVM type (with attributes) and the number of integer and SSE
  # registers needed to pass this value directly (ie. not using the stack)
  def x86_64_type(type, ind_attr, context, &) : Tuple(ArgType, Int32, Int32)
    if int_register?(type)
      attr = type == context.int1 ? Attribute::ZExt : nil
      {ArgType.direct(type, attr: attr), 1, 0}
    elsif sse_register?(type)
      {ArgType.direct(type), 0, 1}
    else
      cls = classify(type)
      if yield cls
        {ArgType.indirect(type, ind_attr), 0, 0}
      else
        needed_int_regs = cls.count(&.int?)
        needed_sse_regs = cls.count(&.sse?)
        {ArgType.direct(type, llreg(context, cls)), needed_int_regs, needed_sse_regs}
      end
    end
  end

  def register?(type) : Bool
    int_register?(type) || sse_register?(type)
  end

  def int_register?(type) : Bool
    case type.kind
    when Type::Kind::Integer, Type::Kind::Pointer
      true
    else
      false
    end
  end

  def sse_register?(type) : Bool
    case type.kind
    when Type::Kind::Float, Type::Kind::Double
      true
    else
      false
    end
  end

  def pass_by_val?(cls) : Bool
    return false if cls.empty?

    cl = cls.first
    cl.in?(RegClass::Memory, RegClass::X87, RegClass::ComplexX87)
  end

  def sret?(cls) : Bool
    return false if cls.empty?

    cls.first == RegClass::Memory
  end

  def classify(type)
    words = (size(type) + 7) // 8
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
      i = off // 8
      e = (off + t_size + 7) // 8
      while i < e
        unify(cls, ix + 1, RegClass::Memory)
        i += 1
      end
      return
    end

    case ty.kind
    when Type::Kind::Integer, Type::Kind::Pointer
      unify(cls, ix + off // 8, RegClass::Int)
    when Type::Kind::Float
      unify(cls, ix + off // 8, (off % 8 == 4) ? RegClass::SSEFv : RegClass::SSEFs)
    when Type::Kind::Double
      unify(cls, ix + off // 8, RegClass::SSEDs)
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

  def classify_struct(tys, cls, i, off, packed) : Nil
    field_off = off
    tys.each do |ty|
      field_off = align_offset(field_off, ty) unless packed
      classify(ty, cls, i, field_off)
      field_off += size(ty)
    end
  end

  def fixup(ty, cls) : Nil
    i = 0
    ty_kind = ty.kind
    e = cls.size
    if e > 2 && ty_kind.in?(Type::Kind::Struct, Type::Kind::Array)
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

  def llreg(context, reg_classes) : LLVM::Type
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

  def llvec_len(reg_classes) : Int32
    len = 1
    reg_classes.each do |reg_class|
      break if reg_class != RegClass::SSEUp
      len += 1
    end
    len
  end

  def align(type : Type) : Int32
    align(type, 8)
  end

  def size(type : Type) : Int32
    size(type, 8)
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

    def sse? : Bool
      case self
      when SSEFs, SSEFv, SSEDs
        true
      else
        false
      end
    end
  end
end
