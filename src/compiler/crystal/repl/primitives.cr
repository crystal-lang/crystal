require "./repl"
require "./interpreter"

class Crystal::Repl::Interpreter
  def visit(node : Primitive)
    a_def = @def.not_nil!

    case node.name
    when "binary"
      primitive_binary(node)
    when "pointer_malloc"
      primitive_pointer_malloc(node)
    when "pointer_get"
      primitive_pointer_get(node)
    when "pointer_set"
      primitive_pointer_set(node)
    when "pointer_add"
      primitive_pointer_add(node)
    else
      node.raise "BUG: missing handling of primitive #{node.name}"
    end
  end

  private def primitive_binary(node)
    a_def = @def.not_nil!
    self_value = @local_vars["self"].value
    other_value = @local_vars[a_def.args.first.name].value
    case a_def.name
    when "+"
      binary_math_op("+", node, self_value, other_value) { |x, y| x + y }
    when "-"
      binary_math_op("-", node, self_value, other_value) { |x, y| x - y }
    when ">"
      binary_cmp_op(">", node, self_value, other_value) { |x, y| x > y }
    when ">="
      binary_cmp_op(">=", node, self_value, other_value) { |x, y| x >= y }
    when "<"
      binary_cmp_op("<", node, self_value, other_value) { |x, y| x < y }
    when "<="
      binary_cmp_op("<=", node, self_value, other_value) { |x, y| x <= y }
    when "=="
      result = self_value == other_value
      result_type = @program.bool
      @last = Value.new(result, result_type)
    when "!="
      result = self_value != other_value
      result_type = @program.bool
      @last = Value.new(result, result_type)
    else
      node.raise "BUG: missing handling of binary op #{a_def.name}"
    end
  end

  private def binary_math_op(op, node, self_value, other_value)
    if self_value.is_a?(Int) && other_value.is_a?(Int)
      result = yield self_value, other_value
      result_type = scope.lookup_type(@def.not_nil!.return_type.not_nil!)
      @last = Value.new(result, result_type)
    else
      node.raise "BUG: missing handling of #{self_value.class} #{op} #{other_value.class}"
    end
  end

  private def binary_cmp_op(op, node, self_value, other_value)
    if self_value.is_a?(Int) && other_value.is_a?(Int)
      result = yield self_value, other_value
      result_type = @program.bool
      @last = Value.new(result, result_type)
    else
      node.raise "BUG: missing handling of #{self_value.class} #{op} #{other_value.class}"
    end
  end

  private def primitive_pointer_malloc(node)
    a_def = @def.not_nil!
    pointer_instance_type = scope.instance_type.as(PointerInstanceType)
    element_type = pointer_instance_type.element_type
    type_size = @program.size_of(element_type.sizeof_type)
    arg_size = @local_vars[a_def.args.first.name].value.as(UInt64)
    bytes_to_malloc = (arg_size * type_size)
    pointer = Pointer(Void).malloc(bytes_to_malloc)
    @last = Value.new(pointer, pointer_instance_type)
  end

  private def primitive_pointer_get(node)
    self_var = @local_vars["self"]
    pointer = self_var.value.as(PointerWrapper).pointer
    pointer_instance_type = self_var.type.as(PointerInstanceType)
    element_type = pointer_instance_type.element_type
    @last = Value.new(pointer.as(Void**).value, element_type)
  end

  private def primitive_pointer_set(node)
    a_def = @def.not_nil!
    self_var = @local_vars["self"]
    value_to_set = @local_vars[a_def.args.first.name]
    @last = value_to_set

    pointer = self_var.value.as(PointerWrapper).pointer
    pointer.as(Void**).value = value_to_set.pointer
  end

  private def primitive_pointer_add(node)
    a_def = @def.not_nil!
    self_var = @local_vars["self"]
    pointer = self_var.value.as(PointerWrapper).pointer
    pointer_instance_type = scope.instance_type.as(PointerInstanceType)
    element_type = pointer_instance_type.element_type
    type_size = @program.size_of(element_type.sizeof_type)
    value_to_add = @local_vars[a_def.args.first.name].value.as(Int64)
    bytes_to_add = (type_size * value_to_add)
    @last = Value.new(pointer + bytes_to_add, pointer_instance_type)
  end
end
