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
    when :i8
      @last = Value.new(node.value.to_i8, node.type)
    when :u8
      @last = Value.new(node.value.to_u8, node.type)
    when :i16
      @last = Value.new(node.value.to_i16, node.type)
    when :u16
      @last = Value.new(node.value.to_u16, node.type)
    when :i32
      @last = Value.new(node.value.to_i32, node.type)
    when :u32
      @last = Value.new(node.value.to_u32, node.type)
    when :i64
      @last = Value.new(node.value.to_i64, node.type)
    when :u64
      @last = Value.new(node.value.to_u64, node.type)
    when :f32
      @last = Value.new(node.value.to_f32, node.type)
    when :f64
      @last = Value.new(node.value.to_f64, node.type)
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

    named_arg_values =
      if named_args = node.named_args
        named_args.map do |named_arg|
          named_arg.value.accept self
          {named_arg.name, @last}
        end
      else
        nil
      end

    old_scope, @scope = scope, target_def.owner
    old_var_values, @var_values = @var_values, {} of String => Value
    @def = target_def

    # Set up local vars for the def instatiation
    if obj_value
      @var_values["self"] = obj_value
    end

    arg_values.zip(target_def.args) do |arg_value, def_arg|
      @var_values[def_arg.name] = arg_value
    end

    if named_arg_values
      named_arg_values.each do |name, value|
        @var_values[name] = value
      end
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

  def visit(node : Def)
    @last = Value.new(nil, @program.nil_type)
    super
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing interpret for #{node.class}"
  end
end
