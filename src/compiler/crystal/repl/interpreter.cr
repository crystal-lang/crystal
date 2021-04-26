require "./repl"

class Crystal::Repl::Interpreter < Crystal::Visitor
  getter last : Value
  getter vars : Hash(String, Value)

  @scope : Type
  @def : Def?

  def initialize(@program : Program)
    @last = Value.new(nil, @program.nil_type)
    @scope = @program
    @def = nil
    @vars = {} of String => Value
  end

  def interpret(node)
    node.accept self
    @last
  end

  def visit(node : Nop)
    @last = Value.new(nil, @program.nil_type)
    false
  end

  def visit(node : NilLiteral)
    @last = Value.new(nil, @program.nil_type)
    false
  end

  def visit(node : BoolLiteral)
    @last = Value.new(node.value, @program.bool)
  end

  def visit(node : CharLiteral)
    @last = Value.new(node.value, @program.char)
  end

  def visit(node : NumberLiteral)
    case node.kind
    when :i32
      @last = Value.new(node.value.to_i, @program.int32)
    when :u64
      @last = Value.new(node.value.to_u64, @program.uint64)
    else
      node.raise "BUG: missing interpret for NumberLiteral with kind #{node.kind}"
    end
    false
  end

  def visit(node : StringLiteral)
    @last = Value.new(node.value, @program.string)
  end

  def visit(node : Assign)
    visit(node, node.target, node.value)
    false
  end

  def visit(node : Var)
    @last = @vars[node.name]
    false
  end

  private def visit(node : Assign, target : Var, value : ASTNode)
    value.accept self
    @vars[target.name] = @last
  end

  private def visit(node : Assign, target : ASTNode, value : ASTNode)
    node.raise "BUG: missing interpret for #{node.class} with target #{node.target.class}"
  end

  def visit(node : Call)
    # TODO: named arguments, block
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

    arg_types = arg_values.map(&.type)

    signature = CallSignature.new(
      name: node.name,
      arg_types: arg_types,
      block: nil,
      named_args: nil,
    )

    matches =
      if obj_value
        obj_value.type.lookup_matches(signature)
      else
        @program.lookup_matches(signature)
      end

    if matches.empty?
      node.raise "BUG: handle case of call not found"
    end

    match = matches.first
    instantiated_type = match.context.instantiated_type
    old_scope, @scope = @scope, instantiated_type
    old_vars, @vars = @vars, {} of String => Value
    @def = match.def

    # Set up local vars for the def instatiation
    if obj_value
      @vars["self"] = obj_value
    end
    match.def.args.zip(arg_values) do |def_arg, arg_value|
      @vars[def_arg.name] = arg_value
    end

    match.def.body.accept self

    @scope = old_scope
    @vars = old_vars
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
    # TODO: do it well, handle constants too
    path_type = @scope.lookup_type(node)
    @last = Value.new(path_type, path_type.metaclass)
    false
  end

  def visit(node : Generic)
    # TODO: this is done like that so I can try out Pointer#malloc
    node.name.accept self
    generic_type = @last.value.as(GenericType)

    type_var_types = Array(TypeVar).new(node.type_vars.size)
    node.type_vars.each do |type_var|
      type_var.accept self
      type_var_types << @last.value.as(Type)
    end

    instantiated_type = generic_type.instantiate(type_var_types)
    @last = Value.new(instantiated_type, instantiated_type.metaclass)
    false
  end

  def visit(node : Primitive)
    a_def = @def.not_nil!

    case node.name
    when "binary"
      self_value = @vars["self"].value
      other_value = @vars[a_def.args.first.name].value
      case a_def.name
      when "+"
        if self_value.is_a?(Int32) && other_value.is_a?(Int32)
          result = self_value + other_value
          result_type = @scope.lookup_type(a_def.return_type.not_nil!)
          @last = Value.new(result, result_type)
        else
          node.raise "BUG: missing handling of #{self_value.class} + #{other_value.class}"
        end
      when "-"
        if self_value.is_a?(Int32) && other_value.is_a?(Int32)
          result = self_value - other_value
          result_type = @scope.lookup_type(a_def.return_type.not_nil!)
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
      pointer_instance_type = @scope.instance_type.as(PointerInstanceType)
      type_size = @program.size_of(pointer_instance_type.element_type.sizeof_type)
      arg_size = @vars[a_def.args.first.name].value.as(UInt64)
      bytes_to_malloc = (arg_size * type_size)
      pointer = Pointer(Void).malloc(bytes_to_malloc)
      @last = Value.new(pointer, pointer_instance_type)
    else
      node.raise "BUG: missing handling of primitive #{node.name}"
    end
  end

  def visit(node : Def)
    @last = Value.new(nil, @program.nil_type)
    false
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing interpret for #{node.class}"
  end
end
