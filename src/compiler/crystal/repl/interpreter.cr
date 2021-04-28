require "./repl"
require "ffi"

class Crystal::Repl::Interpreter < Crystal::SemanticVisitor
  getter last : Value

  @def : Def?

  def initialize(program : Program)
    super(program)

    @main_visitor = MainVisitor.new(@program)
    @top_level_visitor = TopLevelVisitor.new(@program)

    @last = Value.new(nil, @program.nil_type)
    @scope = @program
    @def = nil
    @local_vars = LocalVars.new
    @dl_libraries = {} of String? => Void*
  end

  def interpret(node)
    @top_level_visitor.reset
    node.accept @top_level_visitor

    @main_visitor.reset
    node.accept @main_visitor

    node.accept self
    @last
  end

  def local_var_keys
    @local_vars.names
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
      @local_vars[target.name] = @last
    else
      node.raise "BUG: missing interpret for #{node.class} with target #{node.target.class}"
    end
    false
  end

  def visit(node : Var)
    @last = @local_vars[node.name]
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
    old_local_vars, @local_vars = @local_vars, LocalVars.new
    @def = target_def

    if obj_value && obj_value.type.is_a?(LibType)
      # Okay... we need to d a C call. libffi to the rescue!
      handle = @dl_libraries[nil] ||= LibC.dlopen(nil, LibC::RTLD_LAZY | LibC::RTLD_GLOBAL)
      fn = LibC.dlsym(handle, node.name)
      if fn.null?
        node.raise "dlsym failed for #{node.name}"
      end

      # TODO: missing named arguments here
      cif = FFI.prepare(
        abi: FFI::ABI::DEFAULT,
        args: arg_values.map(&.type.ffi_type),
        return_type: node.type.ffi_type,
      )

      pointers = [] of Void*
      arg_values.each do |arg_value|
        pointer = Pointer(Void).malloc(@program.size_of(arg_value.type.sizeof_type))
        arg_value.ffi_value(pointer)
        pointers << pointer
      end

      cif.call(fn, pointers)

      # TODO: missing return value
    else
      # Set up local vars for the def instatiation
      if obj_value
        @local_vars["self"] = obj_value
      end

      arg_values.zip(target_def.args) do |arg_value, def_arg|
        @local_vars[def_arg.name] = arg_value
      end

      if named_arg_values
        named_arg_values.each do |name, value|
          @local_vars[name] = value
        end
      end

      target_def.body.accept self
    end

    @scope = old_scope
    @local_vars = old_local_vars
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

  def visit(node : PointerOf)
    exp = node.exp
    case exp
    when Var
      @last = @local_vars.pointerof(exp.name)
    else
      node.raise "BUG: missing interpret for PointerOf with exp #{exp.class}"
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
