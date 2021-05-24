require "./repl"
require "./instructions"

class Crystal::Repl::Compiler < Crystal::Visitor
  Decompile = false

  private getter scope : Type
  private getter def : Def?

  property compiled_block : CompiledBlock?

  def initialize(
    @context : Context,
    @local_vars : LocalVars,
    @instructions : Array(Instruction) = [] of Instruction,
    scope : Type? = nil,
    @def = nil
  )
    @scope = scope || @context.program
    @wants_value = true
  end

  def self.new(
    context : Context,
    compiled_def : CompiledDef
  )
    new(
      context,
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

  def compile_block(node : Block) : Array(Instruction)
    node.args.reverse_each do |arg|
      index = @local_vars.name_to_index(arg.name)
      set_local index, sizeof_type(arg)
    end

    compile(node.body)
  end

  private def inside_method?
    !!@def
  end

  def visit(node : Nop)
    return false unless @wants_value

    put_nil
    false
  end

  def visit(node : NilLiteral)
    return false unless @wants_value

    put_nil
    false
  end

  def visit(node : BoolLiteral)
    return false unless @wants_value

    node.value ? put_true : put_false
    false
  end

  def visit(node : NumberLiteral)
    return false unless @wants_value

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
    return false unless @wants_value

    put_i32 node.value.ord
    false
  end

  def visit(node : StringLiteral)
    return false unless @wants_value

    put_i64 node.value.object_id.unsafe_as(Int64)
    false
  end

  def visit(node : TupleLiteral)
    type = node.type.as(TupleInstanceType)
    current_offset = 0
    node.elements.each_with_index do |element, i|
      element.accept self
      size = sizeof_type(element)
      next_offset =
        if i == node.elements.size - 1
          sizeof_type(type)
        else
          @context.offset_of(type, i + 1)
        end
      if next_offset - (current_offset + size) > 0
        push_zeros(next_offset - (current_offset + size))
      end
      current_offset = next_offset
    end

    false
  end

  def visit(node : Expressions)
    old_wants_value = @wants_value

    node.expressions.each_with_index do |expression, i|
      @wants_value = old_wants_value && i == node.expressions.size - 1
      expression.accept self
    end

    @wants_value = old_wants_value

    false
  end

  def visit(node : Assign)
    target = node.target
    case target
    when Var
      request_value(node.value)
      dup(sizeof_type(node.value)) if @wants_value

      index = @local_vars.name_to_index(target.name)
      type = @local_vars.type(target.name)

      # Before assigning to the var we must potentially box inside a union
      convert node.value, node.value.type, type
      set_local index, sizeof_type(type)
    when InstanceVar
      if inside_method?
        request_value(node.value)
        dup(sizeof_type(node.value)) if @wants_value

        ivar_offset = ivar_offset(scope, target.name)
        ivar = scope.lookup_instance_var(target.name)
        ivar_size = sizeof_type(ivar.type)

        convert node.value, node.value.type, ivar.type

        set_self_ivar ivar_offset, ivar_size
      else
        node.type = @context.program.nil_type
        put_nil if @wants_value
      end
    else
      node.raise "BUG: missing interpret for #{node.class} with target #{node.target.class}"
    end
    false
  end

  def visit(node : Var)
    return false unless @wants_value

    index = @local_vars.name_to_index(node.name)
    type = @local_vars.type(node.name)

    get_local index, sizeof_type(type)
    convert node, type, node.type
    false
  end

  def visit(node : InstanceVar)
    return false unless @wants_value

    ivar_offset = ivar_offset(scope, node.name)
    ivar_size = sizeof_type(scope.lookup_instance_var(node.name))

    get_self_ivar ivar_offset, ivar_size
    false
  end

  def visit(node : ReadInstanceVar)
    # TODO: check struct
    node.obj.accept self

    type = node.obj.type

    ivar_offset = ivar_offset(type, node.name)
    ivar_size = sizeof_type(type.lookup_instance_var(node.name))

    get_class_ivar ivar_offset, ivar_size
    false
  end

  def visit(node : UninitializedVar)
    case var = node.var
    when Var
      var.accept self
    else
      node.raise "BUG: missing interpret UninitializedVar for #{var.class}"
    end

    false
  end

  def visit(node : If)
    if node.truthy?
      discard_value(node.cond)
      node.then.accept self
      return false unless @wants_value

      convert node.then, node.then.type, node.type
      return false
    elsif node.falsey?
      discard_value(node.cond)
      node.else.accept self
      return false unless @wants_value

      convert node.else, node.else.type, node.type
      return false
    end

    request_value(node.cond)
    value_to_bool(node.cond, node.cond.type)

    branch_unless 0
    cond_jump_location = patch_location

    node.then.accept self
    convert node.then, node.then.type, node.type if @wants_value

    jump 0
    then_jump_location = patch_location

    patch_jump(cond_jump_location)

    node.else.accept self
    convert node.else, node.else.type, node.type if @wants_value

    patch_jump(then_jump_location)

    false
  end

  def visit(node : While)
    jump 0
    cond_jump_location = patch_location

    body_index = @instructions.size
    discard_value(node.body)

    patch_jump(cond_jump_location)

    request_value(node.cond)
    value_to_bool(node.cond, node.cond.type)

    branch_if body_index

    put_nil if @wants_value

    false
  end

  def visit(node : Return)
    exp = node.exp

    exp_type =
      if exp
        request_value(exp)
        exp.type
      else
        put_nil
        @context.program.nil_type
      end

    def_type = @def.not_nil!.type
    convert node, exp_type, def_type
    leave sizeof_type(def_type)

    false
  end

  def visit(node : IsA)
    node.obj.accept self
    return false unless @wants_value

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
    return false unless @wants_value

    put_type node.type
    false
  end

  def visit(node : Path)
    return false unless @wants_value

    put_type node.type
    false
  end

  def visit(node : Generic)
    return false unless @wants_value

    put_type node.type
    false
  end

  def visit(node : PointerOf)
    return false unless @wants_value

    exp = node.exp
    case exp
    when Var
      pointerof_var(@local_vars.name_to_index(exp.name))
    when InstanceVar
      index = scope.index_of_instance_var(exp.name).not_nil!
      if scope.struct?
        pointerof_ivar(@context.offset_of(scope, index))
      else
        pointerof_ivar(@context.instance_offset_of(scope, index))
      end
    else
      node.raise "BUG: missing interpret for PointerOf with exp #{exp.class}"
    end
    false
  end

  def visit(node : Not)
    exp = node.exp
    exp.accept self
    return false unless @wants_value

    value_to_bool(exp, exp.type)
    logical_not

    false
  end

  def visit(node : Cast)
    node.obj.accept self

    obj_type = node.obj.type
    to_type = node.to.type.virtual_type

    if obj_type.is_a?(PointerInstanceType) && to_type.is_a?(PointerInstanceType)
      # Cast between pointers is nop
      nop
    elsif obj_type.is_a?(PointerInstanceType) && to_type.reference_like?
      # Cast from pointer to reference is nop
      nop
    elsif obj_type.reference_like? && to_type.is_a?(PointerInstanceType)
      # Cast from reference to pointer is nop
      nop
    else
      node.raise "BUG: missing interpret Cast from #{obj_type} to #{to_type}"
    end

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

    if obj && obj.type.is_a?(LibType)
      # TODO: named args
      node.args.each { |arg| request_value(arg) }

      lib_call(node)

      pop sizeof_type(node) unless @wants_value

      return false
    end

    compiled_def = @context.defs[target_def]?
    unless compiled_def
      block = node.block

      # Compile the block too if there's one
      if block
        # TODO: name collisions and different types with different blocks
        block.vars.try &.each do |name, var|
          next if var.context != block

          @local_vars.declare(name, var.type)
        end

        block_args_bytesize = block.args.sum { |arg| sizeof_type(arg) }

        compiled_block = CompiledBlock.new(block, @local_vars, block_args_bytesize)
        compiler = Compiler.new(@context, @local_vars, compiled_block.instructions, scope: @scope, def: @def)
        compiler.compiled_block = @compiled_block
        compiler.compile_block(block)

        {% if Decompile %}
          puts "=== #{target_def.owner}##{target_def.name}#block ==="
          puts Disassembler.disassemble(compiled_block.instructions, @local_vars)
          puts "=== #{target_def.owner}##{target_def.name}#block ==="
        {% end %}
      end

      args_bytesize = 0

      obj_type = obj.try(&.type) || scope

      if obj_type == @context.program
        # Nothing
      elsif obj_type.passed_by_value?
        args_bytesize += sizeof(Pointer(UInt8))
      else
        args_bytesize += sizeof_type(obj_type)
      end

      args_bytesize += args.sum { |arg| sizeof_type(arg) }
      args_bytesize += named_args.sum { |arg| sizeof_type(arg.value) } if named_args

      compiled_def = CompiledDef.new(@context, target_def, args_bytesize)

      # We don't cache defs that yield because we inline the block's contents
      @context.defs[target_def] = compiled_def unless block

      # Declare local variables for the newly compiled function
      target_def.vars.try &.each do |name, var|
        compiled_def.local_vars.declare(name, var.type)
      end

      compiler = Compiler.new(@context, compiled_def)
      compiler.compiled_block = compiled_block

      begin
        compiler.compile(target_def.body)
      rescue ex : Crystal::CodeError
        node.raise "compiling #{node}", inner: ex
      end

      {% if Decompile %}
        puts "=== #{target_def.owner}##{target_def.name} ==="
        p! compiled_def.local_vars, compiled_def.args_bytesize
        puts Disassembler.disassemble(compiled_def)
        puts "=== #{target_def.owner}##{target_def.name} ==="
      {% end %}
    end

    # Self for structs is passed by reference
    pop_obj = nil

    if obj
      if obj.type.passed_by_value?
        case obj
        when Var
          if obj.name == "self"
            put_self
          else
            pointerof_var(@local_vars.name_to_index(obj.name))
          end
          # TODO: when InstanceVar
        else
          # For a struct, we first put it on the stack
          request_value(obj)

          # Then take a pointer to it (this is self inside the method)
          put_stack_top_pointer(sizeof_type(obj))

          # We must remember to later pop the struct that's still on the stack
          pop_obj = obj
        end
      else
        request_value(obj)
      end
    else
      # Pass implicit self if needed
      put_self unless scope.is_a?(Program)
    end

    args.each { |a| request_value(a) }
    named_args.try &.each { |n| request_value(n) }

    if node.block
      call_with_block compiled_def
    else
      call compiled_def
    end

    if @wants_value
      # Pop the struct that's on the stack, if any, if obj was a struct
      # (but the struct is after the call's value, so we must
      # remove it past that value)
      pop_from_offset sizeof_type(pop_obj), sizeof_type(node) if pop_obj
    else
      if pop_obj
        pop sizeof_type(node) + sizeof_type(pop_obj)
      else
        pop sizeof_type(node)
      end
    end

    false
  end

  private def accept_call_members(node : Call)
    node.obj.try &.accept(self)
    node.args.each &.accept(self)
    node.named_args.try &.each &.value.accept(self)
  end

  def visit(node : Yield)
    compiled_block = @compiled_block.not_nil!
    block = compiled_block.block

    node.exps.each_with_index do |exp, i|
      if i < block.args.size
        request_value(exp)
        convert exp, exp.type, block.args[i].type
      else
        discard_value(exp)
      end
    end

    call_block compiled_block
    pop sizeof_type(node) unless @wants_value

    false
  end

  def visit(node : ClassDef)
    # TODO: change scope
    node.body.accept self

    return false unless @wants_value

    put_nil
    false
  end

  def visit(node : Def)
    return false unless @wants_value

    put_nil
    false
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing interpret for #{node.class}"
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

  private def request_value(node : ASTNode)
    accept_with_wants_value node, true
  end

  private def discard_value(node : ASTNode)
    accept_with_wants_value node, false
  end

  private def accept_with_wants_value(node : ASTNode, wants_value)
    old_wants_value = @wants_value
    @wants_value = wants_value
    node.accept self
    @wants_value = old_wants_value
  end

  private def put_type(type : Type)
    put_i32 type_id(type)
  end

  private def put_def(a_def : Def)
  end

  private def put_self
    if scope.struct?
      if scope.passed_by_value?
        get_local 0, sizeof(Pointer(UInt8))
      else
        get_local 0, sizeof_type(scope)
      end
    else
      get_local 0, sizeof(Pointer(UInt8))
    end
  end

  private def append(op_code : OpCode)
    append op_code.value
  end

  private def append(a_def : CompiledDef)
    append(a_def.object_id.unsafe_as(Int64))
  end

  private def append(a_block : CompiledBlock)
    append(a_block.object_id.unsafe_as(Int64))
  end

  private def append(call : Call)
    append(call.object_id.unsafe_as(Int64))
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
    @context.sizeof_type(node)
  end

  private def sizeof_type(type : Type) : Int32
    @context.sizeof_type(type)
  end

  private def instance_sizeof_type(type : Type) : Int32
    @context.instance_sizeof_type(type)
  end

  private def ivar_offset(type : Type, name : String) : Int32
    @context.ivar_offset(type, name)
  end

  private def type_id(type : Type)
    @context.type_id(type)
  end

  private macro nop
  end
end
