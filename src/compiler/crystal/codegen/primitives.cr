require "./codegen"

class Crystal::CodeGenVisitor
  # Can only happen in a Const or as an argument cast.
  def visit(node : Primitive)
    @last = case node.name
            when "argc"
              @argc
            when "argv"
              @argv
            else
              raise "BUG: unhandled primitive in codegen visit: #{node.name}"
            end
  end

  def codegen_primitive(call, node, target_def, call_args)
    @call_location = call.try &.name_location

    @last = case node.name
            when "binary"
              codegen_primitive_binary node, target_def, call_args
            when "convert"
              codegen_primitive_convert node, target_def, call_args, checked: true
            when "unchecked_convert"
              codegen_primitive_convert node, target_def, call_args, checked: false
            when "allocate"
              codegen_primitive_allocate node, target_def, call_args
            when "pointer_malloc"
              codegen_primitive_pointer_malloc node, target_def, call_args
            when "pointer_set"
              codegen_primitive_pointer_set node, target_def, call_args
            when "pointer_get"
              codegen_primitive_pointer_get node, target_def, call_args
            when "pointer_address"
              codegen_primitive_pointer_address node, target_def, call_args
            when "pointer_new"
              codegen_primitive_pointer_new node, target_def, call_args
            when "pointer_realloc"
              codegen_primitive_pointer_realloc node, target_def, call_args
            when "pointer_add"
              codegen_primitive_pointer_add node, target_def, call_args
            when "pointer_diff"
              codegen_primitive_pointer_diff node, target_def, call_args
            when "struct_or_union_set"
              codegen_primitive_struct_or_union_set node, target_def, call_args
            when "external_var_set"
              codegen_primitive_external_var_set node, target_def, call_args
            when "external_var_get"
              codegen_primitive_external_var_get node, target_def, call_args
            when "object_id"
              codegen_primitive_object_id node, target_def, call_args
            when "object_crystal_type_id"
              codegen_primitive_object_crystal_type_id node, target_def, call_args
            when "class_crystal_instance_type_id"
              codegen_primitive_class_crystal_instance_type_id node, target_def, call_args
            when "symbol_to_s"
              codegen_primitive_symbol_to_s node, target_def, call_args
            when "class"
              codegen_primitive_class node, target_def, call_args
            when "proc_call"
              codegen_primitive_proc_call node, target_def, call_args
            when "tuple_indexer_known_index"
              codegen_primitive_tuple_indexer_known_index node, target_def, call_args
            when "enum_value", "enum_new"
              call_args[0]
            when "cmpxchg"
              codegen_primitive_cmpxchg call, node, target_def, call_args
            when "atomicrmw"
              codegen_primitive_atomicrmw call, node, target_def, call_args
            when "fence"
              codegen_primitive_fence call, node, target_def, call_args
            when "load_atomic"
              codegen_primitive_load_atomic call, node, target_def, call_args
            when "store_atomic"
              codegen_primitive_store_atomic call, node, target_def, call_args
            when "throw_info"
              cast_to_void_pointer void_ptr_throwinfo
            when "va_arg"
              codegen_va_arg call, node, target_def, call_args
            else
              raise "BUG: unhandled primitive in codegen: #{node.name}"
            end

    @call_location = nil
  end

  def codegen_primitive_binary(node, target_def, call_args)
    p1, p2 = call_args
    t1, t2 = target_def.owner, target_def.args[0].type
    codegen_binary_op target_def.name, t1, t2, p1, p2
  end

  def codegen_binary_op(op, t1 : BoolType, t2 : BoolType, p1, p2)
    case op
    when "==" then builder.icmp LLVM::IntPredicate::EQ, p1, p2
    when "!=" then builder.icmp LLVM::IntPredicate::NE, p1, p2
    else           raise "BUG: trying to codegen #{t1} #{op} #{t2}"
    end
  end

  def codegen_binary_op(op, t1 : CharType, t2 : CharType, p1, p2)
    case op
    when "==" then builder.icmp LLVM::IntPredicate::EQ, p1, p2
    when "!=" then builder.icmp LLVM::IntPredicate::NE, p1, p2
    when "<"  then builder.icmp LLVM::IntPredicate::ULT, p1, p2
    when "<=" then builder.icmp LLVM::IntPredicate::ULE, p1, p2
    when ">"  then builder.icmp LLVM::IntPredicate::UGT, p1, p2
    when ">=" then builder.icmp LLVM::IntPredicate::UGE, p1, p2
    else           raise "BUG: trying to codegen #{t1} #{op} #{t2}"
    end
  end

  def codegen_binary_op(op, t1 : SymbolType, t2 : SymbolType, p1, p2)
    case op
    when "==" then builder.icmp LLVM::IntPredicate::EQ, p1, p2
    when "!=" then builder.icmp LLVM::IntPredicate::NE, p1, p2
    else           raise "BUG: trying to codegen #{t1} #{op} #{t2}"
    end
  end

  def codegen_binary_op(op, t1 : IntegerType, t2 : IntegerType, p1, p2)
    # Comparisons are a bit trickier because we want to get comparisons
    # between signed and unsigned integers right.
    case op
    when "<"  then return codegen_binary_op_lt(t1, t2, p1, p2)
    when "<=" then return codegen_binary_op_lte(t1, t2, p1, p2)
    when ">"  then return codegen_binary_op_gt(t1, t2, p1, p2)
    when ">=" then return codegen_binary_op_gte(t1, t2, p1, p2)
    when "==" then return codegen_binary_op_eq(t1, t2, p1, p2)
    when "!=" then return codegen_binary_op_ne(t1, t2, p1, p2)
    end

    case op
    when "+", "-", "*"
      return codegen_binary_op_with_overflow(op, t1, t2, p1, p2)
    end

    tmax, p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)

    case op
    when "&+"              then codegen_trunc_binary_op_result(t1, t2, builder.add(p1, p2))
    when "&-"              then codegen_trunc_binary_op_result(t1, t2, builder.sub(p1, p2))
    when "&*"              then codegen_trunc_binary_op_result(t1, t2, builder.mul(p1, p2))
    when "/", "unsafe_div" then codegen_trunc_binary_op_result(t1, t2, t1.signed? ? builder.sdiv(p1, p2) : builder.udiv(p1, p2))
    when "%", "unsafe_mod" then codegen_trunc_binary_op_result(t1, t2, t1.signed? ? builder.srem(p1, p2) : builder.urem(p1, p2))
    when "unsafe_shl"      then codegen_trunc_binary_op_result(t1, t2, builder.shl(p1, p2))
    when "unsafe_shr"      then codegen_trunc_binary_op_result(t1, t2, t1.signed? ? builder.ashr(p1, p2) : builder.lshr(p1, p2))
    when "|"               then codegen_trunc_binary_op_result(t1, t2, or(p1, p2))
    when "&"               then codegen_trunc_binary_op_result(t1, t2, and(p1, p2))
    when "^"               then codegen_trunc_binary_op_result(t1, t2, builder.xor(p1, p2))
    else                        raise "BUG: trying to codegen #{t1} #{op} #{t2}"
    end
  end

  def codegen_binary_op_with_overflow(op, t1, t2, p1, p2)
    if op == "*"
      if t1.unsigned? && t2.signed?
        return codegen_mul_unsigned_signed_with_overflow(t1, t2, p1, p2)
      elsif t1.signed? && t2.unsigned?
        return codegen_mul_signed_unsigned_with_overflow(t1, t2, p1, p2)
      end
    end

    calc_signed = t1.signed? || t2.signed?
    calc_width = {t1, t2}.map { |t| t.bytes * 8 + ((calc_signed && t.unsigned?) ? 1 : 0) }.max
    calc_type = llvm_context.int(calc_width)

    e1 = t1.signed? ? builder.sext(p1, calc_type) : builder.zext(p1, calc_type)
    e2 = t2.signed? ? builder.sext(p2, calc_type) : builder.zext(p2, calc_type)

    llvm_op =
      case {calc_signed, op}
      when {false, "+"} then "uadd"
      when {false, "-"} then "usub"
      when {false, "*"} then "umul"
      when {true, "+"}  then "sadd"
      when {true, "-"}  then "ssub"
      when {true, "*"}  then "smul"
      else                   raise "BUG: unknown overflow op"
      end

    llvm_fun = binary_overflow_fun "llvm.#{llvm_op}.with.overflow.i#{calc_width}", calc_type
    res_with_overflow = builder.call(llvm_fun.type, llvm_fun.func, [e1, e2])

    result = extract_value res_with_overflow, 0
    overflow = extract_value res_with_overflow, 1

    if calc_width > t1.bytes * 8
      result_trunc = trunc result, llvm_type(t1)
      result_trunc_ext = t1.signed? ? builder.sext(result_trunc, calc_type) : builder.zext(result_trunc, calc_type)
      overflow = or(overflow, builder.icmp LLVM::IntPredicate::NE, result, result_trunc_ext)
    end

    codegen_raise_overflow_cond overflow

    trunc result, llvm_type(t1)
  end

  def codegen_mul_unsigned_signed_with_overflow(t1, t2, p1, p2)
    overflow = and(
      codegen_binary_op_ne(t1, t1, p1, int(0, t1)), # self != 0
      codegen_binary_op_lt(t2, t2, p2, int(0, t2))  # other < 0
    )
    codegen_raise_overflow_cond overflow

    codegen_binary_op_with_overflow("*", t1, @program.int_type(false, t2.bytes), p1, p2)
  end

  def codegen_mul_signed_unsigned_with_overflow(t1, t2, p1, p2)
    negative = codegen_binary_op_lt(t1, t1, p1, int(0, t1)) # self < 0
    minus_p1 = builder.sub int(0, t1), p1
    abs = builder.select negative, minus_p1, p1
    u1 = @program.int_type(false, t1.bytes)

    # tmp is the abs value of the result
    # there is overflow when |result| > max + (negative ? 1 : 0)
    tmp = codegen_binary_op_with_overflow("*", u1, t2, abs, p2)
    _, max = t1.range
    max_result = builder.add(int(max, t1), builder.zext(negative, llvm_type(t1)))
    overflow = codegen_binary_op_gt(u1, u1, tmp, max_result)
    codegen_raise_overflow_cond overflow

    # negate back the result if p1 was negative
    minus_tmp = builder.sub int(0, t1), tmp
    builder.select negative, minus_tmp, tmp
  end

  def codegen_binary_extend_int(t1, t2, p1, p2)
    if t1.normal_rank == t2.normal_rank
      # Nothing to do
      tmax = t1
    elsif t1.rank < t2.rank
      p1 = extend_int t1, t2, p1
      tmax = t2
    else
      p2 = extend_int t2, t1, p2
      tmax = t1
    end
    {tmax, p1, p2}
  end

  # Ensures the result is returned in the type of the left hand side operand t1.
  # This is only needed if the operation was carried in the realm of t2
  # because it was of higher rank
  def codegen_trunc_binary_op_result(t1, t2, result)
    if t1.normal_rank != t2.normal_rank && t1.rank < t2.rank
      result = trunc result, llvm_type(t1)
    else
      result
    end
  end

  private def codegen_out_of_range(target_type : IntegerType, arg_type : IntegerType, arg)
    min_value, max_value = target_type.range
    # arg < min_value || arg > max_value
    or(
      codegen_binary_op_lt(arg_type, target_type, arg, int(min_value, target_type)),
      codegen_binary_op_gt(arg_type, target_type, arg, int(max_value, target_type))
    )
  end

  private def codegen_out_of_range(target_type : IntegerType, arg_type : FloatType, arg)
    min_value, max_value = target_type.range
    max_value = case arg_type.kind
                when .f32?
                  float32_upper_bound(max_value)
                when .f64?
                  float64_upper_bound(max_value)
                else
                  raise "BUG: unknown float type"
                end

    # we allow one comparison to be unordered so that NaNs are caught
    # !(arg >= min_value) || arg > max_value
    or(
      builder.fcmp(LLVM::RealPredicate::ULT, arg, int_to_float(target_type, arg_type, int(min_value, target_type))),
      builder.fcmp(LLVM::RealPredicate::OGT, arg, int_to_float(target_type, arg_type, int(max_value, target_type)))
    )
  end

  private def float32_upper_bound(int_max_value)
    case int_max_value
    when UInt128
      # `Float32::MAX < UInt128::MAX`, so we use `Float32::MAX` instead as the
      # upper bound in order to reject positive infinity
      int_max_value.class.new(Float32::MAX)
    when Int32, UInt32, Int64, UInt64, Int128
      # if the float type has fewer bits of precision than the integer type
      # then the upper bound would mistakenly allow values near the upper limit,
      # e.g. 2147483647_i32 -> 2147483648_f32, because the bound itself is
      # rounded to the nearest even-significand number in the `int_to_float`
      # call above; we choose the predecessor as the upper bound, i.e.
      # 2147483520_f32, ensuring it is exact when converted back to an integer
      int_max_value.class.new(int_max_value.to_f32.prev_float)
    else
      int_max_value
    end
  end

  private def float64_upper_bound(int_max_value)
    case int_max_value
    when Int64, UInt64, Int128, UInt128
      int_max_value.class.new(int_max_value.to_f64.prev_float)
    else
      int_max_value
    end
  end

  private def codegen_out_of_range(target_type : FloatType, arg_type : IntegerType, arg)
    if arg_type.kind.u128? && target_type.kind.f32?
      # since Float32::MAX < UInt128::MAX
      # the value will be outside of the float range if
      # arg > Float32::MAX
      _, max_value = target_type.range
      max_value_as_int = float_to_int(target_type, arg_type, float(max_value, target_type))

      codegen_binary_op_gt(arg_type, arg_type, arg, max_value_as_int)
    else
      # for all other possibilities the integer value fit within the float range
      llvm_false
    end
  end

  private def codegen_out_of_range(target_type : FloatType, arg_type : FloatType, arg)
    min_value, max_value = target_type.range
    # checks for arg being outside of range and not infinity
    # (arg < min_value || arg > max_value) && arg != 2 * arg
    and(
      or(
        builder.fcmp(LLVM::RealPredicate::OLT, arg, float(min_value, arg_type)),
        builder.fcmp(LLVM::RealPredicate::OGT, arg, float(max_value, arg_type))
      ),
      builder.fcmp(LLVM::RealPredicate::ONE, arg, builder.fmul(float(2, arg_type), arg))
    )
  end

  private def codegen_raise_overflow
    location = @call_location
    set_current_debug_location(location) if location && @debug.line_numbers?

    func = crystal_raise_overflow_fun
    call_args = [] of LLVM::Value

    if (rescue_block = @rescue_block)
      invoke_out_block = new_block "invoke_out"
      invoke func, call_args, invoke_out_block, rescue_block
      position_at_end invoke_out_block
    else
      call func, call_args
    end

    unreachable
  end

  private def codegen_raise_overflow_cond(overflow_condition)
    op_overflow = new_block "overflow"
    op_normal = new_block "normal"

    overflow_condition = builder.call(llvm_expect_i1_fun.type, llvm_expect_i1_fun.func, [overflow_condition, llvm_false])
    cond overflow_condition, op_overflow, op_normal

    position_at_end op_overflow
    codegen_raise_overflow

    position_at_end op_normal
  end

  private def binary_overflow_fun(fun_name, llvm_operand_type)
    fetch_typed_fun(@llvm_mod, fun_name) do
      LLVM::Type.function(
        [llvm_operand_type, llvm_operand_type],
        @llvm_context.struct([llvm_operand_type, @llvm_context.int1]),
      )
    end
  end

  private def llvm_expect_i1_fun
    fetch_typed_fun(@llvm_mod, "llvm.expect.i1") do
      LLVM::Type.function([@llvm_context.int1, @llvm_context.int1], @llvm_context.int1)
    end
  end

  # The below methods (lt, lte, gt, gte, eq, ne) perform
  # comparisons on two integers x and y,
  # where t1, t2 are their types and p1, p2 are their values.
  #
  # In LLVM, Int32 and UInt32 are represented as the same type
  # (i32) and although integer operations have a sign
  # (SGE, UGE, signed/unsigned greater than or equal)
  # when we have one signed integer and one unsigned integer
  # we can't choose a signedness for the operation. In that
  # case we need to perform some additional checks.
  #
  # Equality and inequality operations for integers in LLVM don't have
  # signedness, they just compare bit patterns. But for example
  # the Int32 with value -1 and the UInt32 with value
  # 4294967295 have the same bit pattern, and yet they are not
  # equal, so again we must perform some additional checks
  # (mainly, if the signed value is negative then there's
  # no way they are equal, and for positive values we can
  # perform the usual bit equality).

  def codegen_binary_op_lt(t1, t2, p1, p2)
    if t1.signed? == t2.signed?
      _, p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)
      builder.icmp (t1.signed? ? LLVM::IntPredicate::SLT : LLVM::IntPredicate::ULT), p1, p2
    else
      if t1.signed? && t2.unsigned?
        if t1.bytes > t2.bytes
          # x < 0 || x < x.class.new(y)
          or(
            builder.icmp(LLVM::IntPredicate::SLT, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::SLT, p1, extend_int(t2, t1, p2))
          )
        else
          # x < 0 || y.class.new(x) < y
          or(
            builder.icmp(LLVM::IntPredicate::SLT, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::ULT, extend_int(t1, t2, p1), p2)
          )
        end
      else
        # t1.unsigned? && t2.signed?
        if t1.bytes < t2.bytes
          # y >= 0 && y.class.new(x) < y
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::SLT, extend_int(t1, t2, p1), p2)
          )
        else
          # y >= 0 && x < x.class.new(y)
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::ULT, p1, extend_int(t2, t1, p2))
          )
        end
      end
    end
  end

  def codegen_binary_op_lte(t1, t2, p1, p2)
    if t1.signed? == t2.signed?
      _, p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)
      builder.icmp (t1.signed? ? LLVM::IntPredicate::SLE : LLVM::IntPredicate::ULE), p1, p2
    else
      if t1.signed? && t2.unsigned?
        if t1.bytes > t2.bytes
          # x <= 0 || x <= x.class.new(y)
          or(
            builder.icmp(LLVM::IntPredicate::SLE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::SLE, p1, extend_int(t2, t1, p2))
          )
        else
          # x <= 0 || y.class.new(x) <= y
          or(
            builder.icmp(LLVM::IntPredicate::SLE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::ULE, extend_int(t1, t2, p1), p2)
          )
        end
      else
        # t1.unsigned? && t2.signed?
        if t1.bytes < t2.bytes
          # y >= 0 && y.class.new(x) <= y
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::SLE, extend_int(t1, t2, p1), p2)
          )
        else
          # y >= 0 && x <= x.class.new(y)
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::ULE, p1, extend_int(t2, t1, p2))
          )
        end
      end
    end
  end

  def codegen_binary_op_gt(t1, t2, p1, p2)
    if t1.signed? == t2.signed?
      _, p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)
      builder.icmp (t1.signed? ? LLVM::IntPredicate::SGT : LLVM::IntPredicate::UGT), p1, p2
    else
      if t1.signed? && t2.unsigned?
        if t1.bytes > t2.bytes
          # x >= 0 && x > x.class.new(y)
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::SGT, p1, extend_int(t2, t1, p2))
          )
        else
          # x >= 0 && y.class.new(x) > y
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::UGT, extend_int(t1, t2, p1), p2)
          )
        end
      else
        # t1.unsigned? && t2.signed?
        if t1.bytes < t2.bytes
          # y < 0 || y.class.new(x) > y
          or(
            builder.icmp(LLVM::IntPredicate::SLT, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::SGT, extend_int(t1, t2, p1), p2)
          )
        else
          # y < 0 || x > x.class.new(y)
          or(
            builder.icmp(LLVM::IntPredicate::SLT, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::UGT, p1, extend_int(t2, t1, p2))
          )
        end
      end
    end
  end

  def codegen_binary_op_gte(t1, t2, p1, p2)
    if t1.signed? == t2.signed?
      _, p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)
      builder.icmp (t1.signed? ? LLVM::IntPredicate::SGE : LLVM::IntPredicate::UGE), p1, p2
    else
      if t1.signed? && t2.unsigned?
        if t1.bytes > t2.bytes
          # x >= 0 && x >= x.class.new(y)
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::SGE, p1, extend_int(t2, t1, p2))
          )
        else
          # x >= 0 && y.class.new(x) >= y
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::UGE, extend_int(t1, t2, p1), p2)
          )
        end
      else
        # t1.unsigned? && t2.signed?
        if t1.bytes < t2.bytes
          # y <= 0 || y.class.new(x) >= y
          or(
            builder.icmp(LLVM::IntPredicate::SLE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::SGE, extend_int(t1, t2, p1), p2)
          )
        else
          # y <= 0 || x >= x.class.new(y)
          or(
            builder.icmp(LLVM::IntPredicate::SLE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::UGE, p1, extend_int(t2, t1, p2))
          )
        end
      end
    end
  end

  def codegen_binary_op_eq(t1, t2, p1, p2)
    _, p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)

    if t1.signed? == t2.signed?
      builder.icmp(LLVM::IntPredicate::EQ, p1, p2)
    elsif t1.signed? && t2.unsigned?
      # x >= 0 && x == y
      and(
        builder.icmp(LLVM::IntPredicate::SGE, p1, p1.type.const_int(0)),
        builder.icmp(LLVM::IntPredicate::EQ, p1, p2)
      )
    else # t1.unsigned? && t2.signed?
      # y >= 0 && x == y
      and(
        builder.icmp(LLVM::IntPredicate::SGE, p2, p2.type.const_int(0)),
        builder.icmp(LLVM::IntPredicate::EQ, p1, p2)
      )
    end
  end

  def codegen_binary_op_ne(t1, t2, p1, p2)
    _, p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)

    if t1.signed? == t2.signed?
      builder.icmp(LLVM::IntPredicate::NE, p1, p2)
    elsif t1.signed? && t2.unsigned?
      # x < 0 || x != y
      or(
        builder.icmp(LLVM::IntPredicate::SLT, p1, p1.type.const_int(0)),
        builder.icmp(LLVM::IntPredicate::NE, p1, p2)
      )
    else # t1.unsigned? && t2.signed?
      # y < 0 || x != y
      or(
        builder.icmp(LLVM::IntPredicate::SLT, p2, p2.type.const_int(0)),
        builder.icmp(LLVM::IntPredicate::NE, p1, p2)
      )
    end
  end

  def codegen_binary_op(op, t1 : IntegerType, t2 : FloatType, p1, p2)
    p1 = codegen_cast(t1, t2, p1)
    codegen_binary_op(op, t2, t2, p1, p2)
  end

  def codegen_binary_op(op, t1 : FloatType, t2 : IntegerType, p1, p2)
    p2 = codegen_cast(t2, t1, p2)
    codegen_binary_op(op, t1, t1, p1, p2)
  end

  def codegen_binary_op(op, t1 : FloatType, t2 : FloatType, p1, p2)
    if t1.rank < t2.rank
      p1 = extend_float t2, p1
    elsif t1.rank > t2.rank
      p2 = extend_float t1, p2
    end

    @last = case op
            when "+"         then builder.fadd p1, p2
            when "-"         then builder.fsub p1, p2
            when "*"         then builder.fmul p1, p2
            when "/", "fdiv" then builder.fdiv p1, p2
            when "=="        then return builder.fcmp LLVM::RealPredicate::OEQ, p1, p2
            when "!="        then return builder.fcmp LLVM::RealPredicate::UNE, p1, p2
            when "<"         then return builder.fcmp LLVM::RealPredicate::OLT, p1, p2
            when "<="        then return builder.fcmp LLVM::RealPredicate::OLE, p1, p2
            when ">"         then return builder.fcmp LLVM::RealPredicate::OGT, p1, p2
            when ">="        then return builder.fcmp LLVM::RealPredicate::OGE, p1, p2
            else                  raise "BUG: trying to codegen #{t1} #{op} #{t2}"
            end
    @last = trunc_float t1, @last if t1.rank < t2.rank
    @last
  end

  def codegen_binary_op(op, t1 : TypeDefType, t2, p1, p2)
    codegen_binary_op(op, t1.remove_typedef, t2, p1, p2)
  end

  def codegen_binary_op(op, t1, t2, p1, p2)
    raise "BUG: codegen_binary_op called with #{t1} #{op} #{t2}"
  end

  def codegen_primitive_convert(node, target_def, call_args, *, checked : Bool)
    p1 = call_args[0]
    from_type, to_type = target_def.owner, target_def.type
    codegen_convert(from_type, to_type, p1, checked: checked)
  end

  def codegen_convert(from_type : IntegerType, to_type : IntegerType, arg, *, checked : Bool)
    case
    when from_type.normal_rank == to_type.normal_rank
      # if the normal_rank is the same (eg: UInt64 / Int64)
      # there is still chance for overflow
      if from_type.kind != to_type.kind && checked
        overflow = codegen_out_of_range(to_type, from_type, arg)
        codegen_raise_overflow_cond(overflow)
      end
      arg
    when from_type.rank < to_type.rank
      # extending a signed integer to an unsigned one (eg: Int8 to UInt16)
      # may still lead to underflow
      if checked
        if from_type.signed? && to_type.unsigned?
          overflow = codegen_out_of_range(to_type, from_type, arg)
          codegen_raise_overflow_cond(overflow)
        end
      end
      extend_int from_type, to_type, arg
    else
      if checked
        overflow = codegen_out_of_range(to_type, from_type, arg)
        codegen_raise_overflow_cond(overflow)
      end
      trunc arg, llvm_type(to_type)
    end
  end

  def codegen_convert(from_type : IntegerType, to_type : FloatType, arg, *, checked : Bool)
    if checked
      if from_type.kind.u128? && to_type.kind.f32?
        overflow = codegen_out_of_range(to_type, from_type, arg)
        codegen_raise_overflow_cond(overflow)
      end
    end
    int_to_float from_type, to_type, arg
  end

  def codegen_convert(from_type : FloatType, to_type : IntegerType, arg, *, checked : Bool)
    if checked
      overflow = codegen_out_of_range(to_type, from_type, arg)
      codegen_raise_overflow_cond(overflow)
    end
    float_to_int from_type, to_type, arg
  end

  def codegen_convert(from_type : FloatType, to_type : FloatType, arg, *, checked : Bool)
    case
    when from_type.rank < to_type.rank
      extend_float to_type, arg
    when from_type.rank > to_type.rank
      if checked
        overflow = codegen_out_of_range(to_type, from_type, arg)
        codegen_raise_overflow_cond(overflow)
      end
      trunc_float to_type, arg
    else
      arg
    end
  end

  def codegen_convert(from_type : IntegerType, to_type : CharType, arg, *, checked : Bool)
    codegen_convert from_type, @program.int32, arg, checked: checked
  end

  def codegen_convert(from_type : CharType, to_type : IntegerType, arg, *, checked : Bool)
    builder.zext arg, llvm_type(to_type)
  end

  def codegen_convert(from_type : SymbolType, to_type : IntegerType, arg, *, checked : Bool)
    arg
  end

  def codegen_convert(from_type : TypeDefType, to_type, arg, *, checked : Bool)
    codegen_convert from_type.remove_typedef, to_type, arg, checked: checked
  end

  def codegen_convert(from_type, to_type, arg, *, checked : Bool)
    raise "BUG: codegen_convert called from #{from_type} to #{to_type}"
  end

  def codegen_cast(from_type, to_type, arg)
    codegen_convert(from_type, to_type, arg, checked: false)
  end

  def codegen_primitive_allocate(node, target_def, call_args)
    type = node.type

    base_type = type.is_a?(VirtualType) ? type.base_type : type

    allocate_aggregate base_type

    if type.is_a?(VirtualType)
      @last = upcast(@last, type, base_type)
    end

    @last
  end

  def codegen_primitive_pointer_malloc(node, target_def, call_args)
    type = node.type.as(PointerInstanceType)
    llvm_type = llvm_embedded_type(type.element_type)

    old_debug_location = @current_debug_location
    if @debug.line_numbers? && (location = node.location)
      set_current_debug_location(location)
    end

    if type.element_type.has_inner_pointers?
      last = array_malloc(llvm_type, call_args[1])
    else
      last = array_malloc_atomic(llvm_type, call_args[1])
    end

    if @debug.line_numbers?
      set_current_debug_location(old_debug_location)
    end

    last
  end

  def codegen_primitive_pointer_set(node, target_def, call_args)
    type = context.type.remove_typedef.as(PointerInstanceType)

    # Assigning to a Pointer(Void) has no effect
    return llvm_nil if type.element_type.void?

    value = call_args[1]
    assign call_args[0], type.element_type, node.type, value
    value
  end

  def codegen_primitive_pointer_get(node, target_def, call_args)
    type = context.type.remove_typedef.as(PointerInstanceType)
    to_lhs call_args[0], type.element_type
  end

  def codegen_primitive_pointer_address(node, target_def, call_args)
    ptr2int call_args[0], llvm_context.int64
  end

  def codegen_primitive_pointer_new(node, target_def, call_args)
    int2ptr(call_args[1], llvm_type(node.type))
  end

  def codegen_primitive_pointer_realloc(node, target_def, call_args)
    type = context.type.as(PointerInstanceType)

    casted_ptr = cast_to_void_pointer(call_args[0])
    size = builder.mul call_args[1], llvm_size(type.element_type)
    reallocated_ptr = realloc casted_ptr, size
    cast_to_pointer reallocated_ptr, type.element_type
  end

  def codegen_primitive_pointer_add(node, target_def, call_args)
    type = context.type.as(PointerInstanceType)

    # `llvm_embedded_type` needed to treat `Void*` like `UInt8*`
    gep llvm_embedded_type(type.element_type), call_args[0], call_args[1]
  end

  def struct_field_ptr(type, field_name, pointer)
    index = type.index_of_instance_var('@' + field_name).not_nil!
    aggregate_index llvm_type(type), pointer, index
  end

  def codegen_primitive_struct_or_union_set(node, target_def, call_args)
    set_aggregate_field(node, target_def, call_args) do |field_type|
      type = context.type.as(NonGenericClassType)
      if type.extern_union?
        union_field_ptr(type, field_type, call_args[0])
      else
        name = target_def.name.rchop
        struct_field_ptr(type, name, call_args[0])
      end
    end
  end

  def set_aggregate_field(node, target_def, call_args, &)
    call_arg = call_args[1]
    original_call_arg = call_arg

    # Check if we need to do a numeric conversion
    if (extra = node.extra)
      existing_value = context.vars["value"]?
      context.vars["value"] = LLVMVar.new(call_arg, node.type, true)
      request_value(extra)
      call_arg = @last
      context.vars["value"] = existing_value if existing_value
    end

    var_name = '@' + target_def.name.rchop
    scope = context.type.as(NonGenericClassType)
    field_type = scope.instance_vars[var_name].type

    # Check assigning nil to a field of type pointer or Proc
    if node.type.nil_type? && (field_type.pointer? || field_type.proc?)
      call_arg = llvm_c_type(field_type).null
    elsif field_type.proc?
      call_arg = check_proc_is_not_closure(call_arg, field_type)
    end

    value = to_rhs call_arg, field_type
    store value, yield(field_type)

    original_call_arg
  end

  def union_field_ptr(union_type, field_type, pointer)
    ptr = aggregate_index llvm_type(union_type), pointer, 0
    if field_type.is_a?(ProcInstanceType)
      pointer_cast ptr, @llvm_typer.proc_type(field_type).pointer.pointer
    else
      cast_to_pointer ptr, field_type
    end
  end

  def codegen_primitive_external_var_set(node, target_def, call_args)
    external = target_def.as(External)
    name = external.real_name
    var = declare_lib_var name, node.type, external.thread_local?

    @last = extern_to_rhs(call_args[0], external.type)

    store @last, var

    @last = check_c_fun node.type, @last

    @last
  end

  def codegen_primitive_external_var_get(node, target_def, call_args)
    external = target_def.as(External)
    var = get_external_var(external)

    @last = extern_to_lhs(var, external.type)

    @last = check_c_fun node.type, @last

    @last
  end

  def get_external_var(external)
    name = external.as(External).real_name
    declare_lib_var name, external.type, external.thread_local?
  end

  def codegen_primitive_object_id(node, external, call_args)
    ptr2int call_args[0], llvm_context.int64
  end

  def codegen_primitive_object_crystal_type_id(node, target_def, call_args)
    if context.type.is_a?(MetaclassType)
      type_id(type)
    else
      type_id(call_args[0], type)
    end
  end

  def codegen_primitive_class_crystal_instance_type_id(node, target_def, call_args)
    type_id(context.type.instance_type)
  end

  def codegen_primitive_symbol_to_s(node, target_def, call_args)
    string = llvm_type(@program.string)
    table_type = string.array(@symbol_table_values.size)
    string_ptr = gep table_type, @llvm_mod.globals[SYMBOL_TABLE_NAME], int(0), call_args[0]
    load(string, string_ptr)
  end

  def codegen_primitive_class(node, target_def, call_args)
    value = call_args.first?
    if value
      codegen_primitive_class_with_type(type, value)
    else
      type_id(node.type)
    end
  end

  def codegen_primitive_class_with_type(type : VirtualType, value)
    type_id = type_id(value, type)
    metaclass_fun_name = "~metaclass"
    func = typed_fun?(@main_mod, metaclass_fun_name) || create_metaclass_fun(metaclass_fun_name)
    func = check_main_fun metaclass_fun_name, func
    call func, [type_id] of LLVM::Value
  end

  def create_metaclass_fun(name)
    id_to_metaclass = @program.llvm_id.id_to_metaclass.to_a.sort_by! &.[0]

    in_main do
      define_main_function(name, ([llvm_context.int32]), llvm_context.int32) do |func|
        set_internal_fun_debug_location(func, name)

        arg = func.params.first

        current_block = insert_block

        cases = {} of LLVM::Value => LLVM::BasicBlock
        id_to_metaclass.each do |(type_id, metaclass_id)|
          block = new_block "type_#{type_id}"
          cases[int32(type_id)] = block
          position_at_end block
          ret int32(metaclass_id)
        end

        otherwise = new_block "otherwise"
        position_at_end otherwise
        unreachable

        position_at_end current_block
        @builder.switch arg, otherwise, cases
      end
    end
  end

  def codegen_primitive_class_with_type(type : Type, value)
    type_id(type.metaclass)
  end

  def codegen_primitive_proc_call(node, target_def, call_args)
    location = @call_location
    set_current_debug_location(location) if location && @debug.line_numbers?

    closure_ptr = call_args[0]

    # For non-closure args we use byval attribute and other things
    # that the C ABI dictates, if needed (args).
    # Otherwise we load the values (closure_args).
    args = call_args[1..-1]
    closure_args = Array(LLVM::Value).new(args.size + 1)

    c_calling_convention = target_def.proc_c_calling_convention?

    proc_type = context.type.as(ProcInstanceType)
    target_def.args.size.times do |i|
      proc_arg_type = proc_type.arg_types[i]
      target_def_arg_type = target_def.args[i].type
      args[i] = arg = upcast args[i], proc_arg_type, target_def_arg_type
      closure_args << to_rhs(arg, proc_arg_type)
    end

    fun_ptr = builder.extract_value closure_ptr, 0
    ctx_ptr = builder.extract_value closure_ptr, 1

    ctx_is_null_block = new_block "ctx_is_null"
    ctx_is_not_null_block = new_block "ctx_is_not_null"

    ctx_is_null = equal? ctx_ptr, llvm_context.void_pointer.null
    cond ctx_is_null, ctx_is_null_block, ctx_is_not_null_block

    Phi.open(self, node, @needs_value) do |phi|
      position_at_end ctx_is_null_block
      real_fun_llvm_type = llvm_proc_type(context.type)
      real_fun_ptr = pointer_cast fun_ptr, real_fun_llvm_type.pointer

      # When invoking a Proc that has extern structs as arguments or return type, it's tricky:
      # closures are never generated with C ABI because C doesn't support closures.
      # But non-closures use C ABI, so if the target Proc is not a closure we cast the
      # arguments according to the ABI.
      # For this we temporarily set the target_def's `abi_info` and `c_calling_convention`
      # properties for the non-closure branch, and then reset it.
      old_abi_info = target_def.abi_info?
      old_c_calling_convention = target_def.c_calling_convention

      if c_calling_convention
        null_fun_ptr, null_fun_llvm_type, null_args = codegen_extern_primitive_proc_call(target_def, args, fun_ptr)
      else
        null_fun_ptr, null_fun_llvm_type, null_args = real_fun_ptr, real_fun_llvm_type, closure_args
      end
      null_fun = LLVMTypedFunction.new(null_fun_llvm_type, LLVM::Function.from_value(null_fun_ptr))

      value = codegen_call_or_invoke(node, target_def, nil, null_fun, null_args, true, target_def.type, false, proc_type)
      phi.add value, node.type

      # Reset abi_info + c_calling_convention so the closure part is generated as usual
      target_def.abi_info = false
      target_def.c_calling_convention = nil

      position_at_end ctx_is_not_null_block
      real_fun_llvm_type = llvm_closure_type(context.type)
      real_fun_ptr = pointer_cast fun_ptr, real_fun_llvm_type.pointer
      real_fun = LLVMTypedFunction.new(real_fun_llvm_type, LLVM::Function.from_value(real_fun_ptr))
      closure_args.insert(0, ctx_ptr)
      value = codegen_call_or_invoke(node, target_def, nil, real_fun, closure_args, true, target_def.type, true, proc_type)
      phi.add value, node.type, true

      target_def.abi_info = old_abi_info
      target_def.c_calling_convention = old_c_calling_convention
    end
  end

  def codegen_extern_primitive_proc_call(target_def, args, fun_ptr)
    null_fun_types = [] of LLVM::Type

    null_args = [] of LLVM::Value
    abi_info = abi_info(target_def)

    if abi_info.return_type.attr == LLVM::Attribute::StructRet
      sret_value = @sret_value = alloca abi_info.return_type.type
      null_args << sret_value
      null_fun_types << abi_info.return_type.type.pointer
      null_fun_return_type = llvm_context.void
    else
      if cast = abi_info.return_type.cast
        null_fun_return_type = cast
      else
        null_fun_return_type = abi_info.return_type.type
      end
    end

    target_def.args.each_with_index do |arg, index|
      call_arg = args[index]

      abi_arg_type = abi_info.arg_types[index]
      case abi_arg_type.kind
      in .direct?
        call_arg = codegen_direct_abi_call(arg.type, call_arg, abi_arg_type)
        if cast = abi_arg_type.cast
          null_fun_types << cast
        else
          null_fun_types << abi_arg_type.type
        end
        null_args << call_arg
      in .indirect?
        # Pass argument as is (will be passed byval)
        null_args << call_arg
        null_fun_types << abi_arg_type.type.pointer
      in .ignore?
        # Ignore
      end
    end

    null_fun_llvm_type = LLVM::Type.function(null_fun_types, null_fun_return_type)
    null_fun_ptr = pointer_cast fun_ptr, null_fun_llvm_type.pointer
    target_def.c_calling_convention = true

    {null_fun_ptr, null_fun_llvm_type, null_args}
  end

  def codegen_primitive_pointer_diff(node, target_def, call_args)
    type = context.type.as(PointerInstanceType)
    p0 = ptr2int(call_args[0], llvm_context.int64)
    p1 = ptr2int(call_args[1], llvm_context.int64)
    sub = builder.sub p0, p1
    # `llvm_embedded_type` needed to treat `Void*` like `UInt8*`
    offsetted = gep(llvm_embedded_type(type.element_type), call_args[0].type.null_pointer, 1)
    builder.exact_sdiv sub, ptr2int(offsetted, llvm_context.int64)
  end

  def codegen_primitive_tuple_indexer_known_index(node, target_def, call_args)
    index = node.as(TupleIndexer).index
    codegen_tuple_indexer(context.type, call_args[0], index)
  end

  def codegen_tuple_indexer(type, value, index : Range)
    case type
    when TupleInstanceType
      struct_type = llvm_type(type)
      tuple_types = type.tuple_types[index].map &.as(Type)
      allocate_tuple(@program.tuple_of(tuple_types).as(TupleInstanceType)) do |tuple_type, i|
        ptr = aggregate_index struct_type, value, index.begin + i
        tuple_value = to_lhs ptr, tuple_type
        {tuple_type, tuple_value}
      end
    else
      type = type.instance_type
      case type
      when TupleInstanceType
        type_id(@program.tuple_of(type.tuple_types[index].map &.as(Type)).metaclass)
      else
        raise "BUG: unsupported codegen for tuple_indexer"
      end
    end
  end

  def codegen_tuple_indexer(type, value, index : Int32)
    case type
    when TupleInstanceType
      ptr = aggregate_index llvm_type(type), value, index
      to_lhs ptr, type.tuple_types[index]
    when NamedTupleInstanceType
      ptr = aggregate_index llvm_type(type), value, index
      to_lhs ptr, type.entries[index].type
    else
      type = type.instance_type
      case type
      when TupleInstanceType
        type_id(type.tuple_types[index].as(Type).metaclass)
      when NamedTupleInstanceType
        type_id(type.entries[index].type.as(Type).metaclass)
      else
        raise "BUG: unsupported codegen for tuple_indexer"
      end
    end
  end

  def check_c_fun(type, value)
    if type.proc?
      make_fun(type, cast_to_void_pointer(value), llvm_context.void_pointer.null)
    else
      value
    end
  end

  def codegen_primitive_cmpxchg(call, node, target_def, call_args)
    call = check_atomic_call(call, target_def)
    ptr, cmp, new, success_ordering, failure_ordering = call_args

    success_ordering = atomic_ordering_get_const(call.args[-2], success_ordering)
    failure_ordering = atomic_ordering_get_const(call.args[-1], failure_ordering)

    value = builder.cmpxchg(ptr, cmp, new, success_ordering, failure_ordering)
    value_type = node.type.as(TupleInstanceType)
    struct_type = llvm_type(value_type)
    value_ptr = alloca struct_type
    store extract_value(value, 0), gep(struct_type, value_ptr, 0, 0)
    store extract_value(value, 1), gep(struct_type, value_ptr, 0, 1)
    value_ptr
  end

  def codegen_primitive_atomicrmw(call, node, target_def, call_args)
    call = check_atomic_call(call, target_def)
    op, ptr, val, ordering, _ = call_args

    op = atomicrwm_bin_op_get_const(call.args[0], op)
    ordering = atomic_ordering_get_const(call.args[-2], ordering)
    singlethread = bool_from_bool_literal(call.args[-1])

    builder.atomicrmw(op, ptr, val, ordering, singlethread)
  end

  def codegen_primitive_fence(call, node, target_def, call_args)
    call = check_atomic_call(call, target_def)
    ordering, _ = call_args

    ordering = atomic_ordering_get_const(call.args[0], ordering)
    singlethread = bool_from_bool_literal(call.args[1])

    builder.fence(ordering, singlethread)
    llvm_nil
  end

  def codegen_primitive_load_atomic(call, node, target_def, call_args)
    call = check_atomic_call(call, target_def)
    ptr, ordering, _ = call_args

    ordering = atomic_ordering_get_const(call.args[-2], ordering)
    volatile = bool_from_bool_literal(call.args[-1])

    inst = builder.load(llvm_type(node.type), ptr)
    inst.ordering = ordering
    inst.volatile = true if volatile
    set_alignment inst, node.type
    inst
  end

  def codegen_primitive_store_atomic(call, node, target_def, call_args)
    call = check_atomic_call(call, target_def)
    ptr, value, ordering, _ = call_args

    ordering = atomic_ordering_get_const(call.args[-2], ordering)
    volatile = bool_from_bool_literal(call.args[-1])

    inst = builder.store(value, ptr)
    inst.ordering = ordering
    inst.volatile = true if volatile
    set_alignment inst, node.type
    inst
  end

  def codegen_va_arg(call, node, target_def, call_args)
    ptr = call_args.first
    builder.va_arg(ptr, llvm_type(node.type))
  end

  def check_atomic_call(call, target_def)
    # This could only happen when taking a proc pointer to an atomic
    # primitive: it could be fixed but it's probably not important for now.
    if call.nil?
      target_def.raise "can't take proc pointer of atomic call"
    end

    call
  end

  def set_alignment(inst, type)
    case type
    when IntegerType, FloatType
      inst.alignment = type.bytes
    when CharType
      inst.alignment = 4
    else
      inst.alignment = @program.bits64? ? 8 : 4
    end
  end

  def atomic_ordering_get_const(node, llvm_arg)
    node.raise "atomic ordering must be a constant" unless llvm_arg.constant?

    if node.type.implements?(@program.enum) && llvm_arg.type.kind.integer? && llvm_arg.type.int_width == 32
      # any `Int32` enum will do, it is up to `Atomic::Ops` to use appropriate
      # parameter restrictions so that things don't go bad
      LLVM::AtomicOrdering.new(llvm_arg.const_int_get_sext_value.to_i32!)
    elsif node.is_a?(SymbolLiteral)
      # TODO: remove once support for 1.4 is dropped
      op = LLVM::AtomicOrdering.parse?(node.value)
      unless op
        node.raise "unknown atomic ordering: #{node.value}"
      end
      op
    else
      node.raise "BUG: unknown atomic ordering: #{node}"
    end
  end

  def atomicrwm_bin_op_get_const(node, llvm_arg)
    node.raise "atomic rwm bin op must be a constant" unless llvm_arg.constant?

    if node.type.implements?(@program.enum) && llvm_arg.type.kind.integer? && llvm_arg.type.int_width == 32
      LLVM::AtomicRMWBinOp.new(llvm_arg.const_int_get_sext_value.to_i32!)
    elsif node.is_a?(SymbolLiteral)
      op = LLVM::AtomicRMWBinOp.parse?(node.value)
      unless op
        node.raise "unknown atomic rwm bin op: #{node.value}"
      end
      op
    else
      node.raise "BUG: unknown atomic rwm bin op: #{node}"
    end
  end

  def bool_from_bool_literal(node)
    unless node.is_a?(BoolLiteral)
      node.raise "BUG: expected bool literal"
    end

    node.value
  end

  def void_ptr_type_descriptor
    void_ptr_type_descriptor_name = "\u{1}??_R0PEAX@8"

    if existing = @llvm_mod.globals[void_ptr_type_descriptor_name]?
      return existing
    end

    type_descriptor = llvm_context.struct([
      llvm_context.void_pointer.pointer,
      llvm_context.void_pointer,
      llvm_context.int8.array(6),
    ])

    if !@main_mod.globals[void_ptr_type_descriptor_name]?
      base_type_descriptor = external_constant(llvm_context.void_pointer, "\u{1}??_7type_info@@6B@")

      # .PEAX is void*
      void_ptr_type_descriptor = @main_mod.globals.add(
        type_descriptor, void_ptr_type_descriptor_name)
      void_ptr_type_descriptor.initializer = llvm_context.const_struct [
        base_type_descriptor,
        llvm_context.void_pointer.null,
        llvm_context.const_string(".PEAX"),
      ]
    end

    # if @llvm_mod == @main_mod, this will find the previously created void_ptr_type_descriptor
    external_constant(type_descriptor, void_ptr_type_descriptor_name)
  end

  def void_ptr_throwinfo
    void_ptr_throwinfo_name = "_TI1PEAX"

    if existing = @llvm_mod.globals[void_ptr_throwinfo_name]?
      return existing
    end

    eh_throwinfo = llvm_context.struct([llvm_context.int32, llvm_context.int32, llvm_context.int32, llvm_context.int32])

    if !@main_mod.globals[void_ptr_throwinfo_name]?
      catchable_type = llvm_context.struct([llvm_context.int32, llvm_context.int32, llvm_context.int32, llvm_context.int32, llvm_context.int32, llvm_context.int32, llvm_context.int32])
      void_ptr_catchable_type = @main_mod.globals.add(
        catchable_type, "_CT??_R0PEAX@88")
      void_ptr_catchable_type.initializer = llvm_context.const_struct [
        int32(1),
        sub_image_base(void_ptr_type_descriptor),
        int32(0),
        int32(-1),
        int32(0),
        int32(8),
        int32(0),
      ]

      catchable_type_array = llvm_context.struct([llvm_context.int32, llvm_context.int32.array(1)])
      catchable_void_ptr = @main_mod.globals.add(
        catchable_type_array, "_CTA1PEAX")
      catchable_void_ptr.initializer = llvm_context.const_struct [
        int32(1),
        llvm_context.int32.const_array([sub_image_base(void_ptr_catchable_type)]),
      ]

      void_ptr_throwinfo = @main_mod.globals.add(
        eh_throwinfo, void_ptr_throwinfo_name)
      void_ptr_throwinfo.initializer = llvm_context.const_struct [
        int32(0),
        int32(0),
        int32(0),
        sub_image_base(catchable_void_ptr),
      ]
    end

    # if @llvm_mod == @main_mod, this will find the previously created void_ptr_throwinfo
    external_constant(eh_throwinfo, void_ptr_throwinfo_name)
  end

  def external_constant(type, name)
    @llvm_mod.globals[name]? || begin
      c = @llvm_mod.globals.add(type, name)
      c.global_constant = true
      c
    end
  end

  def sub_image_base(value)
    image_base = external_constant(llvm_context.int8, "__ImageBase")

    @builder.trunc(
      @builder.sub(
        @builder.ptr2int(value, llvm_context.int64),
        @builder.ptr2int(image_base, llvm_context.int64)),
      llvm_context.int32)
  end
end
