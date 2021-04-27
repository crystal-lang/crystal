require "./repl"

class Crystal::Repl::Interpreter < Crystal::SemanticVisitor
  getter last : Value
  getter var_values : Hash(String, Value)

  @def : Def?

  def initialize(program : Program)
    super(program)

    @last = Value.new(nil, @program.nil_type)
    @scope = @program
    @def = nil
    @var_values = {} of String => Value
  end

  def interpret(node)
    node.accept self
    @last
  end

  def visit(node : Nop)
    @last = Value.new(nil, node.type)
    false
  end

  def visit(node : NilLiteral)
    @last = Value.new(nil, node.type)
    false
  end

  def visit(node : BoolLiteral)
    @last = Value.new(node.value, node.type)
    false
  end

  def visit(node : CharLiteral)
    @last = Value.new(node.value, node.type)
    false
  end

  def visit(node : NumberLiteral)
    case node.kind
    when :i32
      @last = Value.new(node.value.to_i, node.type)
    when :i64
      @last = Value.new(node.value.to_i64, node.type)
    when :u64
      @last = Value.new(node.value.to_u64, node.type)
    else
      node.raise "BUG: missing interpret for NumberLiteral with kind #{node.kind}"
    end
    false
  end

  def visit(node : StringLiteral)
    @last = Value.new(node.value, node.type)
    false
  end

  def visit(node : Assign)
    target = node.target
    case target
    when Var
      node.value.accept self
      @var_values[target.name] = @last
    else
      node.raise "BUG: missing interpret for #{node.class} with target #{node.target.class}"
    end
    false
  end

  def visit(node : Var)
    @last = @var_values[node.name]
    false
  end

  def visit(node : Call)
    super

    # TODO: handle case of multidispatch
    target_def = node.target_def

    obj = node.obj

    obj_value =
      if obj
        visit(obj)
        @last
      else
        nil
      end

    arg_values = node.args.map do |arg|
      visit(arg)
      @last
    end

    old_scope, @scope = scope, target_def.owner
    old_var_values, @var_values = @var_values, {} of String => Value
    @def = target_def

    # Set up local vars for the def instatiation
    if obj_value
      @var_values["self"] = obj_value
    end
    target_def.args.zip(arg_values) do |def_arg, arg_value|
      @var_values[def_arg.name] = arg_value
    end

    target_def.body.accept self

    @scope = old_scope
    @var_values = old_var_values
    @def = nil

    false
  end

  def visit(node : If)
    node.cond.accept self
    if @last.truthy?
      node.then.accept self
    elsif node_else = node.else
      node_else.accept self
    else
      @last = Value.new(nil, @program.nil_type)
    end
    false
  end

  def visit(node : While)
    while true
      node.cond.accept self
      break unless @last.truthy?

      node.body.accept self
    end
    @last = Value.new(nil, @program.nil_type)
    false
  end

  def visit(node : Path)
    @last = Value.new(node.type.instance_type, node.type)
    false
  end

  def visit(node : Generic)
    @last = Value.new(node.type.instance_type, node.type)
    false
  end

  def visit(node : Expressions)
    node.expressions.each do |expression|
      expression.accept self
    end
    false
  end

  def visit(node : Primitive)
    a_def = @def.not_nil!

    case node.name
    when "binary"
      self_value = @var_values["self"].value
      other_value = @var_values[a_def.args.first.name].value
      case a_def.name
      when "+"
        if self_value.is_a?(Int32) && other_value.is_a?(Int32)
          result = self_value + other_value
          result_type = scope.lookup_type(a_def.return_type.not_nil!)
          @last = Value.new(result, result_type)
        else
          node.raise "BUG: missing handling of #{self_value.class} + #{other_value.class}"
        end
      when "-"
        if self_value.is_a?(Int32) && other_value.is_a?(Int32)
          result = self_value - other_value
          result_type = scope.lookup_type(a_def.return_type.not_nil!)
          @last = Value.new(result, result_type)
        else
          node.raise "BUG: missing handling of #{self_value.class} - #{other_value.class}"
        end
      when ">"
        if self_value.is_a?(Int32) && other_value.is_a?(Int32)
          result = self_value > other_value
          result_type = @program.bool
          @last = Value.new(result, result_type)
        else
          node.raise "BUG: missing handling of #{self_value.class} > #{other_value.class}"
        end
      when ">="
        if self_value.is_a?(Int32) && other_value.is_a?(Int32)
          result = self_value >= other_value
          result_type = @program.bool
          @last = Value.new(result, result_type)
        else
          node.raise "BUG: missing handling of #{self_value.class} > #{other_value.class}"
        end
      when "<"
        if self_value.is_a?(Int32) && other_value.is_a?(Int32)
          result = self_value < other_value
          result_type = @program.bool
          @last = Value.new(result, result_type)
        else
          node.raise "BUG: missing handling of #{self_value.class} > #{other_value.class}"
        end
      when "<="
        if self_value.is_a?(Int32) && other_value.is_a?(Int32)
          result = self_value <= other_value
          result_type = @program.bool
          @last = Value.new(result, result_type)
        else
          node.raise "BUG: missing handling of #{self_value.class} > #{other_value.class}"
        end
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
    when "pointer_malloc"
      pointer_instance_type = scope.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      type_size = @program.size_of(element_type.sizeof_type)
      arg_size = @var_values[a_def.args.first.name].value.as(UInt64)
      bytes_to_malloc = (arg_size * type_size)
      pointer = Pointer(Void).malloc(bytes_to_malloc)
      @last = Value.new(PointerWrapper.new(pointer), pointer_instance_type)
    when "pointer_get"
      self_var = @var_values["self"]
      pointer = self_var.value.as(PointerWrapper).pointer
      pointer_instance_type = self_var.type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      case element_type
      when IntegerType
        case element_type.kind
        when :i32
          @last = Value.new(pointer.as(Int32*).value, @program.int32)
        else
          node.raise "BUG: missing handling of pointer_get with element_type #{element_type} and kind #{element_type.kind}"
        end
      else
        node.raise "BUG: missing handling of pointer_get with element_type #{element_type}"
      end
    when "pointer_set"
      self_var = @var_values["self"]
      value_to_set = @var_values[a_def.args.first.name]
      @last = value_to_set

      pointer = self_var.value.as(PointerWrapper).pointer
      pointer_instance_type = self_var.type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      case element_type
      when IntegerType
        case element_type.kind
        when :i32
          pointer.as(Int32*).value = value_to_set.value.as(Int32)
        else
          node.raise "BUG: missing handling of pointer_set with element_type #{element_type} and kind #{element_type.kind}"
        end
      else
        node.raise "BUG: missing handling of pointer_set with element_type #{element_type}"
      end
    when "pointer_add"
      self_var = @var_values["self"]
      pointer = self_var.value.as(PointerWrapper).pointer
      pointer_instance_type = scope.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      type_size = @program.size_of(element_type.sizeof_type)
      value_to_add = @var_values[a_def.args.first.name].value.as(Int64)
      bytes_to_add = (type_size * value_to_add)
      @last = Value.new(PointerWrapper.new(pointer + bytes_to_add), pointer_instance_type)
    else
      node.raise "BUG: missing handling of primitive #{node.name}"
    end
  end

  def visit(node : Def)
    @last = Value.new(nil, @program.nil_type)
    super
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing interpret for #{node.class}"
  end
end
