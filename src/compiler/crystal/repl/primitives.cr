require "./compiler"

class Crystal::Repl::Compiler
  private def visit_primitive(node, body)
    obj = node.obj

    case body.name
    when "unchecked_convert", "convert"
      # TODO: let convert raise on error
      primitive_unchecked_convert(node, body)
    when "binary"
      primitive_binary(node, body)
    when "pointer_new"
      accept_call_members(node)
      return false unless @wants_value

      pointer_new
    when "pointer_malloc"
      discard_value(obj) if obj
      request_value(node.args.first)

      scope_type = ((obj.try &.type) || scope).instance_type

      pointer_instance_type = scope_type.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = sizeof_type(element_type)

      pointer_malloc(element_size)
      pop(sizeof_type(scope_type)) unless @wants_value
    when "pointer_realloc"
      obj ? request_value(obj) : put_self
      request_value(node.args.first)

      scope_type = (obj.try &.type) || scope

      pointer_instance_type = scope_type.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = sizeof_type(element_type)

      pointer_realloc(element_size)
      pop(sizeof_type(scope_type)) unless @wants_value
    when "pointer_set"
      # Accept in reverse order so that it's easier for the interpreter
      arg = node.args.first
      request_value(arg)
      dup(sizeof_type(arg)) if @wants_value

      request_value(obj.not_nil!)
      pointer_set(sizeof_type(node.args.first))
    when "pointer_get"
      accept_call_members(node)
      return unless @wants_value

      pointer_get(sizeof_type(obj.not_nil!.type.as(PointerInstanceType).element_type))
    when "pointer_address"
      accept_call_members(node)
      return unless @wants_value

      pointer_address
    when "pointer_diff"
      accept_call_members(node)
      return unless @wants_value

      pointer_diff(sizeof_type(obj.not_nil!.type.as(PointerInstanceType).element_type))
    when "pointer_add"
      accept_call_members(node)
      return unless @wants_value

      pointer_add(sizeof_type(obj.not_nil!.type.as(PointerInstanceType).element_type))
    when "class"
      return unless @wants_value

      put_type obj.not_nil!.type
    when "object_crystal_type_id"
      type =
        if obj
          discard_value(obj)
          obj.type
        else
          scope
        end

      return unless @wants_value

      put_i32 type_id(type)
    when "allocate"
      type =
        if obj
          discard_value(obj)
          obj.type.instance_type
        else
          scope.instance_type
        end

      return unless @wants_value

      # TODO: check struct
      if type.struct?
        allocate_struct(instance_sizeof_type(type))
      else
        allocate_class(instance_sizeof_type(type), type_id(type))
      end
    when "tuple_indexer_known_index"
      obj = obj.not_nil!
      obj.accept self

      type = obj.type.as(TupleInstanceType)
      index = body.as(TupleIndexer).index
      case index
      when Int32
        element_type = type.tuple_types[index]
        offset = @context.offset_of(type, index)
        tuple_indexer_known_index(sizeof_type(type), offset, sizeof_type(element_type))
      else
        node.raise "BUG: missing handling of primitive #{body.name} with range"
      end
    when "repl_call_stack_unwind"
      repl_call_stack_unwind
    when "repl_raise_without_backtrace"
      repl_raise_without_backtrace
    when "repl_intrinsics_memcpy"
      node.args.each { |arg| request_value(arg) }
      node.named_args.try &.each { |arg| request_value(arg.value) }

      repl_intrinsics_memcpy
    when "repl_intrinsics_memmove"
      node.args.each { |arg| request_value(arg) }
      node.named_args.try &.each { |arg| request_value(arg.value) }

      repl_intrinsics_memmove
    when "repl_intrinsics_memset"
      node.args.each { |arg| request_value(arg) }
      node.named_args.try &.each { |arg| request_value(arg.value) }

      repl_intrinsics_memset
    else
      node.raise "BUG: missing handling of primitive #{body.name}"
    end
  end

  private def primitive_unchecked_convert(node : ASTNode, body : Primitive)
    obj = node.obj

    return false if !obj && !@wants_value

    obj_type =
      if obj
        obj.accept self
        obj.type
      else
        put_self
        scope
      end

    return false unless @wants_value

    target_type = body.type

    primitive_unchecked_convert(node, obj_type, target_type)
  end

  private def primitive_unchecked_convert(node : ASTNode, from_type : IntegerType | FloatType, to_type : IntegerType | FloatType)
    from_kind = integer_or_float_kind(from_type)
    to_kind = integer_or_float_kind(to_type)

    unless from_kind && to_kind
      node.raise "BUG: missing handling of unchecked_convert for #{from_type} (#{node.name})"
    end

    primitive_unchecked_convert(node, from_kind, to_kind)
  end

  private def primitive_unchecked_convert(node : ASTNode, from_type : CharType, to_type : IntegerType)
    # This is Char#ord
    nop
  end

  private def primitive_unchecked_convert(node : ASTNode, from_type : Type, to_type : Type)
    node.raise "BUG: missing handling of unchecked_convert from #{from_type} to #{to_type}"
  end

  private def primitive_unchecked_convert(node : ASTNode, from_kind : Symbol, to_kind : Symbol)
    to_kind =
      case to_kind
      when :u8  then :i8
      when :u16 then :i16
      when :u32 then :i32
      when :u64 then :i64
      else           to_kind
      end

    case {from_kind, to_kind}
    when {:i8, :i8}   then nop
    when {:i8, :i16}  then extend_sign(1)
    when {:i8, :i32}  then extend_sign(3)
    when {:i8, :i64}  then extend_sign(7)
    when {:i8, :f32}  then i8_to_f32
    when {:i8, :f64}  then i8_to_f64
    when {:u8, :i8}   then nop
    when {:u8, :i16}  then push_zeros(1)
    when {:u8, :i32}  then push_zeros(3)
    when {:u8, :i64}  then push_zeros(7)
    when {:u8, :f32}  then u8_to_f32
    when {:u8, :f64}  then u8_to_f64
    when {:i16, :i8}  then pop(1)
    when {:i16, :i16} then nop
    when {:i16, :i32} then extend_sign(2)
    when {:i16, :i64} then extend_sign(6)
    when {:i16, :f32} then i16_to_f32
    when {:i16, :f64} then i16_to_f64
    when {:u16, :i8}  then pop(1)
    when {:u16, :i16} then nop
    when {:u16, :i32} then push_zeros(2)
    when {:u16, :i64} then push_zeros(6)
    when {:u16, :f32} then u16_to_f32
    when {:u16, :f64} then u16_to_f64
    when {:i32, :i8}  then pop(3)
    when {:i32, :i16} then pop(2)
    when {:i32, :i32} then nop
    when {:i32, :i64} then extend_sign(4)
    when {:i32, :f32} then i32_to_f32
    when {:i32, :f64} then i32_to_f64
    when {:u32, :i8}  then pop(3)
    when {:u32, :i16} then pop(2)
    when {:u32, :i32} then nop
    when {:u32, :u32} then nop
    when {:u32, :i64} then push_zeros(4)
    when {:u32, :f32} then u32_to_f32
    when {:u32, :f64} then u32_to_f64
    when {:i64, :i8}  then pop(7)
    when {:i64, :i16} then pop(6)
    when {:i64, :i32} then pop(4)
    when {:i64, :i64} then nop
    when {:i64, :f32} then i64_to_f32
    when {:i64, :f64} then i64_to_f64
    when {:u64, :i8}  then pop(7)
    when {:u64, :i16} then pop(6)
    when {:u64, :i32} then pop(4)
    when {:u64, :i64} then nop
    when {:u64, :f32} then u64_to_f32
    when {:u64, :f64} then u64_to_f64
    when {:f32, :i8}  then f32_to_i64_bang; pop(7)
    when {:f32, :i16} then f32_to_i64_bang; pop(6)
    when {:f32, :i32} then f32_to_i64_bang; pop(4)
    when {:f32, :i64} then f32_to_i64_bang
    when {:f32, :f32} then nop
    when {:f32, :f64} then f32_to_f64
    when {:f64, :i8}  then f64_to_i64_bang; pop(7)
    when {:f64, :i16} then f64_to_i64_bang; pop(6)
    when {:f64, :i32} then f64_to_i64_bang; pop(4)
    when {:f64, :i64} then f64_to_i64_bang
    when {:f64, :f32} then f64_to_f32_bang
    when {:f64, :f64} then nop
    else                   node.raise "BUG: missing handling of unchecked_convert for #{from_kind} - #{to_kind}"
    end
  end

  private def primitive_binary(node, body)
    unless @wants_value
      node.obj.try &.accept self
      node.args.each &.accept self
      node.named_args.try &.each &.value.accept self
      return
    end

    case node.name
    when "+", "&+", "-", "*", "^", "|", "&", "unsafe_shl", "unsafe_shr", "unsafe_div", "unsafe_mod"
      primitive_binary_op_math(node, body, node.name)
    when "<", "<=", ">", ">=", "==", "!="
      primitive_binary_op_cmp(node, body, node.name)
    when "/"
      primitive_binary_float_div(node, body)
    else
      node.raise "BUG: missing handling of binary op #{node.name}"
    end
  end

  private def primitive_binary_op_math(node : ASTNode, body : Primitive, op : String)
    obj = node.obj
    arg = node.args.first

    obj_type = obj.try(&.type) || scope
    arg_type = arg.type

    primitive_binary_op_math(obj_type, arg_type, obj, arg, node, op)
  end

  private def primitive_binary_op_math(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    # TODO: check for overflow (in general)
    if left_type.kind == right_type.kind
      # All good
      left_node ? left_node.accept(self) : put_self
      right_node.accept self
      kind = left_type.kind
      # If both types fit inside Int32
    elsif left_type.rank <= 5 && right_type.rank <= 5
      # Convert them to both to Int32 first
      left_node ? left_node.accept(self) : put_self
      primitive_unchecked_convert(node, left_type.kind, :i32) if left_type.rank < 5

      right_node.accept self
      primitive_unchecked_convert(node, right_type.kind, :i32) if right_type.rank < 5

      kind = :i32
    elsif left_type.unsigned? && right_type.signed?
      # TODO: check for overflow
      # Essentially: if the right value is less than zero, raise
      # Otherwise, do this conversion
      left_node ? left_node.accept(self) : put_self
      right_node.accept self
      primitive_unchecked_convert(node, right_type.kind, left_type.kind)
      kind = left_type.kind
    else
      node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
    end

    return false unless @wants_value

    case kind
    when :i32
      case op
      when "+"          then add_i32
      when "&+"         then add_wrap_i32
      when "-"          then sub_i32
      when "*"          then mul_i32
      when "^"          then xor_i32
      when "|"          then or_i32
      when "&"          then and_i32
      when "unsafe_shl" then unsafe_shl_i32
      when "unsafe_shr" then unsafe_shr_i32
      when "unsafe_div" then unsafe_div_i32
      when "unsafe_mod" then unsafe_mod_i32
      else
        node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
      end
    when :u32
      case op
      when "+"          then add_u32
      when "&+"         then add_wrap_i32
      when "-"          then sub_u32
      when "*"          then mul_u32
      when "^"          then xor_i32
      when "|"          then or_i32
      when "&"          then and_i32
      when "unsafe_shl" then unsafe_shl_i32
      when "unsafe_shr" then unsafe_shr_u32
      when "unsafe_div" then unsafe_div_u32
      when "unsafe_mod" then unsafe_mod_u32
      else
        node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
      end
    when :i64
      case op
      when "+"          then add_i64
      when "&+"         then add_wrap_i64
      when "-"          then sub_i64
      when "*"          then mul_i64
      when "^"          then xor_i64
      when "|"          then or_i64
      when "&"          then and_i64
      when "unsafe_shl" then unsafe_shl_i64
      when "unsafe_shr" then unsafe_shr_i64
      when "unsafe_div" then unsafe_div_i64
      when "unsafe_mod" then unsafe_mod_i64
      else
        node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
      end
    when :u64
      case op
      when "+"          then add_u64
      when "&+"         then add_wrap_i64
      when "-"          then sub_u64
      when "*"          then mul_u64
      when "^"          then xor_i64
      when "|"          then or_i64
      when "&"          then and_i64
      when "unsafe_shl" then unsafe_shl_i64
      when "unsafe_shr" then unsafe_shr_u64
      when "unsafe_div" then unsafe_div_u64
      when "unsafe_mod" then unsafe_mod_u64
      else
        node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
      end
    else
      node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
    end

    if kind != left_type.kind
      primitive_unchecked_convert(node, kind, left_type.kind)
    end
  end

  private def primitive_binary_op_math(left_type : Type, right_type : Type, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    node.raise "BUG: primitive_binary_op_math called with #{left_type} #{op} #{right_type}"
  end

  private def primitive_binary_op_cmp(node : ASTNode, body : Primitive, op : String)
    obj = node.obj.not_nil!
    arg = node.args.first

    obj_type = obj.type
    arg_type = arg.type

    primitive_binary_op_cmp(obj_type, arg_type, obj, arg, op)
  end

  private def primitive_binary_op_cmp(left_type : CharType, right_type : CharType, left_node : ASTNode, right_node : ASTNode, op : String)
    left_node.accept self
    right_node.accept self

    case op
    when "==" then eq_i32
    when "!=" then neq_i32
    when "<"  then lt_i32
    when "<=" then le_i32
    when ">"  then gt_i32
    when ">=" then ge_i32
    else
      left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
    end
  end

  private def primitive_binary_op_cmp(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode, op : String)
    case op
    when "==" then primitive_binary_op_eq(left_type, right_type, left_node, right_node)
    when "!=" then primitive_binary_op_neq(left_type, right_type, left_node, right_node)
    when "<"  then primitive_binary_op_lt(left_type, right_type, left_node, right_node)
    when "<=" then primitive_binary_op_le(left_type, right_type, left_node, right_node)
    when ">"  then primitive_binary_op_gt(left_type, right_type, left_node, right_node)
    when ">=" then primitive_binary_op_ge(left_type, right_type, left_node, right_node)
    else
      left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
    end
  end

  private def primitive_binary_op_eq(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode)
    if left_type.signed? == right_type.signed?
      kind = extend_int(left_type, right_type, left_node, right_node)
    else
      left_node.raise "BUG: missing handling of binary == with types #{left_type} and #{right_type}"
    end

    case kind
    when :i32, :u32 then eq_i32
    when :i64, :u64 then eq_i64
    else
      left_node.raise "BUG: missing handling of binary == with types #{left_type} and #{right_type}"
    end
  end

  private def primitive_binary_op_neq(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode)
    if left_type.signed? == right_type.signed?
      kind = extend_int(left_type, right_type, left_node, right_node)
    else
      left_node.raise "BUG: missing handling of binary == with types #{left_type} and #{right_type}"
    end

    case kind
    when :i32, :u32 then neq_i32
    when :i64, :u64 then neq_i64
    else
      left_node.raise "BUG: missing handling of binary != with types #{left_type} and #{right_type}"
    end
  end

  private def primitive_binary_op_lt(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode)
    if left_type.signed? == right_type.signed?
      kind = extend_int(left_type, right_type, left_node, right_node)
    else
      left_node.raise "BUG: missing handling of binary < with types #{left_type} and #{right_type}"
    end

    case kind
    when :i32, :u32 then lt_i32
    when :i64, :u64 then lt_i64
    else
      left_node.raise "BUG: missing handling of binary < with types #{left_type} and #{right_type}"
    end
  end

  private def primitive_binary_op_le(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode)
    if left_type.signed? == right_type.signed?
      kind = extend_int(left_type, right_type, left_node, right_node)
    else
      left_node.raise "BUG: missing handling of binary <= with types #{left_type} and #{right_type}"
    end

    case kind
    when :i32, :u32 then le_i32
    when :i64, :u64 then le_i64
    else
      left_node.raise "BUG: missing handling of binary <= with types #{left_type} and #{right_type}"
    end
  end

  private def primitive_binary_op_gt(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode)
    if left_type.signed? == right_type.signed?
      kind = extend_int(left_type, right_type, left_node, right_node)
    else
      left_node.raise "BUG: missing handling of binary > with types #{left_type} and #{right_type}"
    end

    case kind
    when :i32, :u32 then gt_i32
    when :i64, :u64 then gt_i64
    else
      left_node.raise "BUG: missing handling of binary > with types #{left_type} and #{right_type}"
    end
  end

  private def primitive_binary_op_ge(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode)
    if left_type.signed? == right_type.signed?
      kind = extend_int(left_type, right_type, left_node, right_node)
    else
      left_node.raise "BUG: missing handling of binary >= with types #{left_type} and #{right_type}"
    end

    case kind
    when :i32, :u32 then ge_i32
    when :i64, :u64 then ge_i64
    else
      left_node.raise "BUG: missing handling of binary >= with types #{left_type} and #{right_type}"
    end
  end

  private def extend_int(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode)
    if left_type.rank == right_type.rank
      left_node.accept self
      right_node.accept self
      left_type.kind
    elsif left_type.rank < right_type.rank
      left_node.accept self
      primitive_unchecked_convert left_node, left_type.kind, right_type.kind
      right_node.accept self
      right_type.kind
    else
      left_node.accept self
      right_node.accept self
      primitive_unchecked_convert right_node, right_type.kind, left_type.kind
      left_type.kind
    end
  end

  #   if left_type.kind == right_type.kind
  #     # If the types are the same
  #     left_node.accept self
  #     right_node.accept self
  #     kind = left_type.kind
  #   elsif left_type.rank <= 5 && right_type.rank <= 5
  #     # If both fit in an Int32
  #     # Convert them to Int32 first, then do the comparison
  #     left_node.accept self
  #     primitive_unchecked_convert(left_node, left_type.kind, :i32) if left_type.rank < 5

  #     right_node.accept self
  #     primitive_unchecked_convert(right_node, right_type.kind, :i32) if right_type.rank < 5

  #     kind = :i32
  #   elsif left_type.rank <= 7 && right_type.rank <= 7
  #     # If both fit in an Int64
  #     # Convert them to Int64 first, then do the comparison
  #     left_node.accept self
  #     primitive_unchecked_convert(left_node, left_type.kind, :i64) if left_type.rank < 7

  #     right_node.accept self
  #     primitive_unchecked_convert(right_node, right_type.kind, :i64) if right_type.rank < 7

  #     kind = :i64
  #   elsif left_type.unsigned? && right_type.unsigned?
  #     # If both are unsigned, convert the smallest to the biggest
  #     if left_type.rank < right_type.rank
  #       left_node.accept self
  #       primitive_unchecked_convert(left_node, left_type.kind, right_type.kind)
  #       right_node.accept self
  #       kind = right_type.kind
  #     else
  #       left_node.accept self
  #       right_node.accept self
  #       primitive_unchecked_convert(right_node, right_type.kind, left_type.kind)
  #       kind = left_type.kind
  #     end
  #   else
  #     left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
  #   end

  #   return false unless @wants_value

  #   case kind
  #   when :i32
  #     case op
  #     when "==" then eq_i32
  #     when "!=" then neq_i32
  #     when "<"  then lt_i32
  #     when "<=" then le_i32
  #     when ">"  then gt_i32
  #     when ">=" then ge_i32
  #     else
  #       left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
  #     end
  #   when :i64
  #     case op
  #     when "==" then eq_i64
  #     when "!=" then neq_i64
  #     when "<"  then lt_i64
  #     when "<=" then le_i64
  #     when ">"  then gt_i64
  #     when ">=" then ge_i64
  #     else
  #       left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
  #     end
  #   when :u64
  #     case op
  #     when "==" then eq_i64
  #     when "!=" then neq_i64
  #     when "<"  then lt_u64
  #     when "<=" then le_u64
  #     when ">"  then gt_u64
  #     when ">=" then ge_u64
  #     else
  #       left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
  #     end
  #   else
  #     left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
  #   end
  # end

  private def primitive_binary_op_cmp(left_type : IntegerType, right_type : FloatType, left_node : ASTNode, right_node : ASTNode, op : String)
    left_node.accept self
    primitive_unchecked_convert(left_node, left_type.kind, right_type.kind)
    right_node.accept self

    case right_type.kind
    when :f64
      case op
      when "==" then eq_f64
      when "!=" then neq_f64
      when "<"  then lt_f64
      when "<=" then le_f64
      when ">"  then gt_f64
      when ">=" then ge_f64
      else
        left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
      end
    else
      left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
    end
  end

  private def primitive_binary_op_cmp(left_type : Type, right_type : Type, left_node : ASTNode, right_node : ASTNode, op : String)
    left_node.raise "BUG: primitive_binary_op_cmp called with #{left_type} #{op} #{right_type}"
  end

  private def primitive_binary_float_div(node, body)
    # TODO: don't assume Float64 op Float64
    obj = node.obj.not_nil!
    arg = node.args.first

    obj.accept self
    arg.accept self

    obj_type = obj.type
    arg_type = arg.type

    obj_kind = integer_or_float_kind(obj_type)
    target_kind = integer_or_float_kind(arg_type)

    case {obj_kind, target_kind}
    when {:f64, :f64}
      div_f64
    else
      node.raise "BUG: missing handling of binary float div with types #{obj_type} and #{arg_type}"
    end
  end

  private def integer_or_float_kind(type)
    case type
    when IntegerType
      type.kind
    when FloatType
      type.kind
    else
      nil
    end
  end
end
