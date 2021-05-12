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
      node.args.first.accept self

      # TODO: do we want the side effect of allocating memory
      return false unless @wants_value

      pointer_instance_type = node.obj.not_nil!.type.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = sizeof_type(element_type)

      pointer_malloc(element_size)
    when "pointer_set"
      # Accept in reverse order so that it's easier for the interpreter
      request_value(node.args.first)
      request_value(node.obj.not_nil!)
      pointer_set(sizeof_type(node.args.first))
    when "pointer_get"
      accept_call_members(node)
      return unless @wants_value

      pointer_get(sizeof_type(node.obj.not_nil!.type.as(PointerInstanceType).element_type))
    when "pointer_address"
      accept_call_members(node)
      return unless @wants_value

      pointer_address
    when "pointer_diff"
      accept_call_members(node)
      return unless @wants_value

      pointer_diff(sizeof_type(node.obj.not_nil!.type.as(PointerInstanceType).element_type))
    when "class"
      return unless @wants_value

      put_type node.obj.not_nil!.type
    when "object_crystal_type_id"
      type =
        if obj
          dont_request_value(obj)
          obj.type
        else
          scope
        end

      return unless @wants_value

      put_i32 type_id(type)
    when "allocate"
      type =
        if obj
          dont_request_value(obj)
          obj.type.instance_type
        else
          scope.instance_type
        end

      return unless @wants_value

      # TODO: check struct
      allocate_class(instance_sizeof_type(type), type_id(type))
    when "repl_call_stack_unwind"
      repl_call_stack_unwind
    when "repl_raise_without_backtrace"
      repl_raise_without_backtrace
    else
      node.raise "BUG: missing handling of primitive #{body.name}"
    end
  end

  private def primitive_unchecked_convert(node : ASTNode, body : Primitive)
    obj = node.obj

    obj_type =
      if obj
        obj.accept self
        obj.type
      else
        scope
      end

    return false unless @wants_value

    target_type = body.type

    obj_kind = integer_or_float_kind(obj_type)
    target_kind = integer_or_float_kind(target_type)

    unless obj_kind && target_kind
      node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
    end

    primitive_unchecked_convert(node, obj_kind, target_kind)
  end

  private def primitive_unchecked_convert(node : ASTNode, obj_kind : Symbol, target_kind : Symbol)
    target_kind =
      case target_kind
      when :u8  then :i8
      when :u16 then :i16
      when :u32 then :i32
      when :u64 then :i64
      else           target_kind
      end

    case {obj_kind, target_kind}
    when {:i8, :i8}   then nop
    when {:i8, :i16}  then i8_to_i16
    when {:i8, :i32}  then i8_to_i32
    when {:i8, :i64}  then i8_to_i64
    when {:i8, :f32}  then i8_to_f32
    when {:i8, :f64}  then i8_to_f64
    when {:u8, :i8}   then nop
    when {:u8, :i16}  then u8_to_i16
    when {:u8, :i32}  then u8_to_i32
    when {:u8, :i64}  then u8_to_i64
    when {:u8, :f32}  then u8_to_f32
    when {:u8, :f64}  then u8_to_f64
    when {:i16, :i8}  then i16_to_i8_bang
    when {:i16, :i16} then nop
    when {:i16, :i32} then i16_to_i32
    when {:i16, :i64} then i16_to_i64
    when {:i16, :f32} then i16_to_f32
    when {:i16, :f64} then i16_to_f64
    when {:u16, :i8}  then i16_to_i8_bang
    when {:u16, :i16} then nop
    when {:u16, :i32} then u16_to_i32
    when {:u16, :i64} then u16_to_i64
    when {:u16, :f32} then u16_to_f32
    when {:u16, :f64} then u16_to_f64
    when {:i32, :i8}  then i32_to_i8_bang
    when {:i32, :i16} then i32_to_i16_bang
    when {:i32, :i32} then nop
    when {:i32, :i64} then i32_to_i64
    when {:i32, :f32} then i32_to_f32
    when {:i32, :f64} then i32_to_f64
    when {:u32, :i8}  then i32_to_i8_bang
    when {:u32, :i16} then i32_to_i16_bang
    when {:u32, :i32} then nop
    when {:u32, :u32} then nop
    when {:u32, :i64} then u32_to_i64
    when {:u32, :f32} then u32_to_f32
    when {:u32, :f64} then u32_to_f64
    when {:i64, :i8}  then i64_to_i8_bang
    when {:i64, :i16} then i64_to_i16_bang
    when {:i64, :i32} then i64_to_i32_bang
    when {:i64, :i64} then nop
    when {:i64, :f32} then i64_to_f32
    when {:i64, :f64} then i64_to_f64
    when {:u64, :i8}  then i64_to_i8_bang
    when {:u64, :i16} then i64_to_i16_bang
    when {:u64, :i32} then i64_to_i32_bang
    when {:u64, :i64} then nop
    when {:u64, :f32} then u64_to_f32
    when {:u64, :f64} then u64_to_f64
    when {:f32, :i8}  then f32_to_i8_bang
    when {:f32, :i16} then f32_to_i16_bang
    when {:f32, :i32} then f32_to_i32_bang
    when {:f32, :i64} then f32_to_i64_bang
    when {:f32, :f32} then nop
    when {:f32, :f64} then f32_to_f64
    when {:f64, :i8}  then f64_to_i8_bang
    when {:f64, :i16} then f64_to_i16_bang
    when {:f64, :i32} then f64_to_i32_bang
    when {:f64, :i64} then f64_to_i64_bang
    when {:f64, :f32} then f64_to_f32_bang
    when {:f64, :f64} then nop
    else                   node.raise "BUG: missing handling of unchecked_convert for #{obj_kind} - #{target_kind}"
    end
  end

  private def primitive_binary(node, body)
    case node.name
    when "+", "-", "*"
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
    obj = node.obj.not_nil!
    arg = node.args.first

    obj_type = obj.type
    arg_type = arg.type

    primitive_binary_op_math(obj_type, arg_type, obj, arg, op)
  end

  private def primitive_binary_op_math(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode, op : String)
    left_node.accept self
    right_node.accept self
    return false unless @wants_value

    case {left_type.kind, right_type.kind}
    when {:i32, :i32}
      case op
      when "+" then add_i32
      when "-" then sub_i32
      when "*" then mul_i32
      else
        left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
      end
    else
      left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
    end
  end

  private def primitive_binary_op_math(left_type : Type, right_type : Type, left_node : ASTNode, right_node : ASTNode, op : String)
    left_node.raise "BUG: primitive_binary_op_math called with #{left_type} #{op} #{right_type}"
  end

  private def primitive_binary_op_cmp(node : ASTNode, body : Primitive, op : String)
    obj = node.obj.not_nil!
    arg = node.args.first

    obj_type = obj.type
    arg_type = arg.type

    primitive_binary_op_cmp(obj_type, arg_type, obj, arg, op)
  end

  private def primitive_binary_op_cmp(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode, op : String)
    left_node.accept self
    right_node.accept self
    return false unless @wants_value

    case {left_type.kind, right_type.kind}
    when {:i32, :i32}
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
    else
      left_node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
    end
  end

  private def primitive_binary_op_cmp(left_type : IntegerType, right_type : FloatType, left_node : ASTNode, right_node : ASTNode, op : String)
    left_node.accept self
    primitive_unchecked_convert(left_node, left_type.kind, right_type.kind)
    right_node.accept self
    return false unless @wants_value

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
    accept_call_members(node)
    return false unless @wants_value

    obj_type = node.obj.not_nil!.type
    arg_type = node.args.first.type

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
