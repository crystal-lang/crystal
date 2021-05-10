require "./repl"
require "./instructions"

class Crystal::Repl::Compiler < Crystal::Visitor
  Decompile = false

  private getter scope
  private getter def : Def?

  def initialize(
    @program : Program,
    @defs : Hash(Def, CompiledDef),
    @local_vars : LocalVars,
    @instructions : Array(Instruction) = [] of Instruction,
    @scope : Type = program,
    @def = nil
  )
  end

  def self.new(
    program : Program,
    defs : Hash(Def, CompiledDef),
    compiled_def : CompiledDef
  )
    new(
      program,
      defs,
      compiled_def.local_vars,
      compiled_def.instructions,
      scope: compiled_def.def.owner,
      def: compiled_def.def)
  end

  def compile(node : ASTNode) : Array(Instruction)
    node.accept self

    leave sizeof_type(node)

    @instructions
  end

  private def inside_method?
    !!@def
  end

  def visit(node : Nop)
    put_nil
    false
  end

  def visit(node : NilLiteral)
    put_nil
    false
  end

  def visit(node : BoolLiteral)
    node.value ? put_true : put_false
    false
  end

  def visit(node : NumberLiteral)
    case node.kind
    when :i8
      put_i8 node.value.to_i8
    when :u8
      put_i8 node.value.to_u8.to_i8!
    when :i16
      put_i16 node.value.to_i16
    when :u16
      put_i16 node.value.to_u16.to_i16!
    when :i32
      put_i32 node.value.to_i32
    when :u32
      put_i32 node.value.to_u32.to_i32!
    when :i64
      put_i64 node.value.to_i64
    when :u64
      put_i64 node.value.to_u64.to_i64!
    when :f32
      put_i32 node.value.to_f32.unsafe_as(Int32)
    when :f64
      put_i64 node.value.to_f64.unsafe_as(Int64)
    else
      node.raise "BUG: missing interpret for NumberLiteral with kind #{node.kind}"
    end
    false
  end

  def visit(node : CharLiteral)
    put_i32 node.value.ord
    false
  end

  def visit(node : StringLiteral)
    put_i64 node.value.object_id.unsafe_as(Int64)
    false
  end

  def visit(node : Expressions)
    node.expressions.each_with_index do |expression, i|
      expression.accept self
      pop(sizeof_type(expression)) if i < node.expressions.size - 1
    end
    false
  end

  def visit(node : Assign)
    # TODO: downcast/upcast

    target = node.target
    case target
    when Var
      node.value.accept self
      index = @local_vars.name_to_index(target.name)
      type = @local_vars.type(target.name)
      set_local index, sizeof_type(type)
    when InstanceVar
      if inside_method?
        node.value.accept self

        # TODO: check struct
        ivar_index = scope.index_of_instance_var(target.name).not_nil!
        ivar_offset = @program.instance_offset_of(scope.sizeof_type, ivar_index).to_i32
        ivar_size = sizeof_type(scope.lookup_instance_var(target.name))

        set_self_class_ivar ivar_offset, ivar_size
      else
        node.type = @program.nil_type
        put_nil
      end
    else
      node.raise "BUG: missing interpret for #{node.class} with target #{node.target.class}"
    end
    false
  end

  def visit(node : Var)
    index = @local_vars.name_to_index(node.name)
    type = @local_vars.type(node.name)

    get_local index, sizeof_type(type)
    convert type, node.type
    false
  end

  def visit(node : InstanceVar)
    # TODO: check struct
    ivar_index = scope.index_of_instance_var(node.name).not_nil!
    ivar_offset = @program.instance_offset_of(scope.sizeof_type, ivar_index).to_i32
    ivar_size = sizeof_type(scope.lookup_instance_var(node.name))

    get_self_class_ivar ivar_offset, ivar_size
    false
  end

  def visit(node : ReadInstanceVar)
    # TODO: check struct
    node.obj.accept self

    type = node.obj.type
    ivar_index = type.index_of_instance_var(node.name).not_nil!
    ivar_offset = @program.instance_offset_of(type.sizeof_type, ivar_index).to_i32
    ivar_size = sizeof_type(type.lookup_instance_var(node.name))

    get_class_ivar ivar_offset, ivar_size
    false
  end

  def visit(node : If)
    node.cond.accept self

    if node.truthy?
      node.then.accept self
      convert node.then.type, node.type
      return false
    elsif node.falsey?
      node.else.accept self
      convert node.else.type, node.type
      return false
    end

    branch_unless 0
    cond_jump_location = patch_location

    node.then.accept self
    convert node.then.type, node.type
    jump 0
    then_jump_location = patch_location

    patch_jump(cond_jump_location)

    node.else.accept self
    convert node.else.type, node.type

    patch_jump(then_jump_location)

    false
  end

  def visit(node : While)
    jump 0
    cond_jump_location = patch_location

    body_index = @instructions.size
    node.body.accept self
    pop sizeof_type(node.body.type)

    patch_jump(cond_jump_location)

    node.cond.accept self
    branch_if body_index

    put_nil

    false
  end

  def visit(node : Return)
    # TODO: downcast/upcast
    exp = node.exp
    if exp
      exp.accept self

      def_type = @def.not_nil!.type
      convert exp.type, def_type
      leave sizeof_type(def_type)
    else
      put_nil
      leave 0
    end

    false
  end

  def visit(node : IsA)
    node.obj.accept self

    obj_type = node.obj.type
    const_type = node.const.type

    filtered_type = obj_type.filter_by(const_type).not_nil!

    if obj_type.is_a?(MixedUnionType)
      union_is_a(sizeof_type(obj_type), type_id(filtered_type))
    else
      node.raise "BUG: missing IsA for #{obj_type}"
    end

    false
  end

  def visit(node : TypeOf)
    put_type node.type
    false
  end

  def visit(node : Path)
    put_type node.type
    false
  end

  def visit(node : Generic)
    put_type node.type
    false
  end

  def visit(node : PointerOf)
    exp = node.exp
    case exp
    when Var
      pointerof_var(@local_vars.name_to_index(exp.name))
    else
      node.raise "BUG: missing interpret for PointerOf with exp #{exp.class}"
    end
    false
  end

  def visit(node : Not)
    exp = node.exp
    case exp.type
    when @program.nil_type
      put_true
    when @program.bool
      exp.accept self
      logical_not
    else
      node.raise "BUG: missing interpret Not for #{exp.type}"
    end

    false
  end

  def visit(node : RespondsTo)
    # TODO
    put_false
    false
  end

  def visit(node : Call)
    # TODO: downcast/upcast

    obj = node.obj
    args = node.args
    named_args = node.named_args

    # TODO: handle case of multidispatch
    target_def = node.target_def

    body = target_def.body
    if body.is_a?(Primitive)
      visit_primitive(node, body)
      return false
    end

    compiled_def = @defs[target_def]?
    unless compiled_def
      args_bytesize = 0
      args_bytesize += sizeof_type(obj.type) if obj && obj.type != @program
      args_bytesize += args.sum { |arg| sizeof_type(arg) }
      args_bytesize += named_args.sum { |arg| sizeof_type(arg.value) } if named_args

      compiled_def = CompiledDef.new(@program, target_def, args_bytesize)
      @defs[target_def] = compiled_def

      # Declare local variables for the newly compiled function
      target_def.vars.try &.each do |name, var|
        # Program is the only type we don't put on the stack
        next if name == "self" && var.type == @program

        compiled_def.local_vars.declare(name, var.type)
      end

      compiler = Compiler.new(@program, @defs, compiled_def)
      compiler.compile(target_def.body)

      {% if Decompile %}
        puts "=== #{target_def.name} ==="
        p! compiled_def.local_vars, compiled_def.args_bytesize
        puts Disassembler.disassemble(compiled_def)
        puts "=== #{target_def.name} ==="
      {% end %}
    end

    obj.try &.accept self
    args.each &.accept self
    named_args.try &.each &.value.accept self

    call compiled_def
    return false

    # arg_values = node.args.map do |arg|
    #   visit(arg)
    #   @last
    # end

    # named_arg_values =
    #   if named_args = node.named_args
    #     named_args.map do |named_arg|
    #       named_arg.value.accept self
    #       {named_arg.name, @last}
    #     end
    #   else
    #     nil
    #   end

    # old_scope, @scope = scope, target_def.owner
    # old_local_vars, @local_vars = @local_vars, LocalVars.new
    # @def = target_def

    # if obj_value && obj_value.type.is_a?(LibType)
    #   # Okay... we need to d a C call. libffi to the rescue!
    #   handle = @dl_libraries[nil] ||= LibC.dlopen(nil, LibC::RTLD_LAZY | LibC::RTLD_GLOBAL)
    #   fn = LibC.dlsym(handle, node.name)
    #   if fn.null?
    #     node.raise "dlsym failed for #{node.name}"
    #   end

    #   # TODO: missing named arguments here
    #   cif = FFI.prepare(
    #     abi: FFI::ABI::DEFAULT,
    #     args: arg_values.map(&.type.ffi_type),
    #     return_type: node.type.ffi_type,
    #   )

    #   pointers = [] of Void*
    #   arg_values.each do |arg_value|
    #     pointer = Pointer(Void).malloc(@program.size_of(arg_value.type.sizeof_type))
    #     arg_value.ffi_value(pointer)
    #     pointers << pointer
    #   end

    #   cif.call(fn, pointers)

    #   # TODO: missing return value
    # else
    #   # Set up local vars for the def instatiation
    #   if obj_value
    #     @local_vars["self"] = obj_value
    #   end

    #   arg_values.zip(target_def.args) do |arg_value, def_arg|
    #     @local_vars[def_arg.name] = arg_value
    #   end

    #   if named_arg_values
    #     named_arg_values.each do |name, value|
    #       @local_vars[name] = value
    #     end
    #   end

    #   target_def.body.accept self
    # end

    # @scope = old_scope
    # @local_vars = old_local_vars
    # @def = nil

    false
  end

  private def accept_call_members(node : Call)
    node.obj.try &.accept(self)
    node.args.each &.accept(self)
    # TODO: named arguments
  end

  def visit(node : ClassDef)
    # TODO: change scope
    node.body.accept self

    put_nil
    false
  end

  def visit(node : Def)
    put_nil
    false
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing instruction compiler for #{node.class}"
  end

  {% for name, instruction in Crystal::Repl::Instructions %}
    {% operands = instruction[:operands] %}

    def {{name.id}}( {{*operands}} ) : Nil
      append OpCode::{{ name.id.upcase }}
      {% for operand in operands %}
        append {{operand.var}}
      {% end %}
    end
  {% end %}

  private def put_type(type : Type)
    put_i32 type_id(type)
  end

  private def put_def(a_def : Def)
  end

  private def type_id(type : Type)
    @program.llvm_id.type_id(type)
  end

  private def convert(from : Type, to : Type)
    return if from == to

    convert_distinct(from, to)
  end

  private def convert_distinct(from : Type, to : MixedUnionType)
    put_in_union(type_id(from), sizeof_type(from), sizeof_type(to))
  end

  private def convert_distinct(from : MixedUnionType, to : Type)
    remove_from_union(sizeof_type(from), sizeof_type(to))
  end

  private def convert_distinct(from : NoReturnType, to : Type)
    # Nothing
  end

  private def convert_distinct(from : Type, to : Type)
    raise "BUG: missing convert_distinct from #{from} to #{to}"
  end

  private def append(op_code : OpCode)
    append op_code.value
  end

  private def append(a_def : CompiledDef)
    append(a_def.object_id.unsafe_as(Int64))
  end

  private def append(value : Int64)
    value.unsafe_as(StaticArray(UInt8, 8)).each do |byte|
      append byte
    end
  end

  private def append(value : Int32)
    value.unsafe_as(StaticArray(UInt8, 4)).each do |byte|
      append byte
    end
  end

  private def append(value : Int16)
    value.unsafe_as(StaticArray(UInt8, 2)).each do |byte|
      append byte
    end
  end

  private def append(value : Int8)
    append value.unsafe_as(UInt8)
  end

  private def append(value : UInt8)
    @instructions << value
  end

  private def patch_location
    @instructions.size - 4
  end

  private def patch_jump(offset : Int32)
    (@instructions.to_unsafe + offset).as(Int32*).value = @instructions.size
  end

  private def sizeof_type(node : ASTNode) : Int32
    sizeof_type(node.type)
  end

  private def sizeof_type(type : Type) : Int32
    @program.size_of(type.sizeof_type).to_i32
  end

  private def instance_sizeof_type(type : Type) : Int32
    @program.instance_size_of(type.sizeof_type).to_i32
  end

  private macro nop
  end
end
