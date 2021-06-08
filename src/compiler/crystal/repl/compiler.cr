require "./repl"
require "./instructions"

class Crystal::Repl::Compiler < Crystal::Visitor
  record CompilingBlock, block : Block, target_def : Def

  private getter scope : Type
  private getter def : Def?

  property compiled_block : CompiledBlock?
  getter instructions
  getter nodes
  property block_level = 0

  def initialize(
    @context : Context,
    @local_vars : LocalVars,
    @instructions : Array(Instruction) = [] of Instruction,
    @nodes : Hash(Int32, ASTNode) = {} of Int32 => ASTNode,
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
      context: context,
      local_vars: compiled_def.local_vars,
      instructions: compiled_def.instructions,
      nodes: compiled_def.nodes,
      scope: compiled_def.def.owner,
      def: compiled_def.def)
  end

  def compile(node : ASTNode) : Nil
    node.accept self

    leave aligned_sizeof_type(node), node: nil
  end

  def compile_block(node : Block, target_def : Def) : Nil
    @compiling_block = CompilingBlock.new(node, target_def)
    node.args.reverse_each do |arg|
      index = @local_vars.name_to_index(arg.name, @block_level)
      set_local index, aligned_sizeof_type(arg), node: arg
    end

    node.body.accept self
    upcast node.body, node.body.type, node.type

    leave aligned_sizeof_type(node), node: nil
  end

  def compile_def(node : Def) : Nil
    node.body.accept self

    final_type = node.type

    compiled_block = @compiled_block
    if compiled_block
      final_type = merge_block_break_type(final_type, compiled_block.block)
    end

    if node.type.nil_type?
      pop aligned_sizeof_type(node.body), node: nil
    else
      upcast node.body, node.body.type, final_type
    end

    leave aligned_sizeof_type(final_type), node: nil

    @instructions
  end

  private def inside_method?
    !!@def
  end

  def visit(node : Nop)
    return false unless @wants_value

    put_nil node: node
    false
  end

  def visit(node : NilLiteral)
    return false unless @wants_value

    put_nil node: node
    false
  end

  def visit(node : BoolLiteral)
    return false unless @wants_value

    if node.value
      put_true node: node
    else
      put_false node: node
    end

    false
  end

  def visit(node : NumberLiteral)
    return false unless @wants_value

    case node.kind
    when :i8
      put_i8 node.value.to_i8, node: node
    when :u8
      put_u8 node.value.to_u8, node: node
    when :i16
      put_i16 node.value.to_i16, node: node
    when :u16
      put_u16 node.value.to_u16, node: node
    when :i32
      put_i32 node.value.to_i32, node: node
    when :u32
      put_u32 node.value.to_u32, node: node
    when :i64
      put_i64 node.value.to_i64, node: node
    when :u64
      put_u64 node.value.to_u64, node: node
    when :f32
      put_i32 node.value.to_f32.unsafe_as(Int32), node: node
    when :f64
      put_i64 node.value.to_f64.unsafe_as(Int64), node: node
    else
      node.raise "BUG: missing interpret for NumberLiteral with kind #{node.kind}"
    end
    false
  end

  def visit(node : CharLiteral)
    return false unless @wants_value

    put_i32 node.value.ord, node: node
    false
  end

  def visit(node : StringLiteral)
    return false unless @wants_value

    # TODO: use a string pool?
    put_i64 node.value.object_id.unsafe_as(Int64), node: node
    false
  end

  def visit(node : SymbolLiteral)
    return false unless @wants_value

    index = @context.symbol_index(node.value)

    put_i32 index, node: node
    false
  end

  def visit(node : TupleLiteral)
    type = node.type.as(TupleInstanceType)

    current_offset = 0
    node.elements.each_with_index do |element, i|
      element.accept self
      aligned_size = aligned_sizeof_type(element)
      next_offset =
        if i == node.elements.size - 1
          aligned_sizeof_type(type)
        else
          @context.offset_of(type, i + 1)
        end

      difference = next_offset - (current_offset + aligned_size)
      if difference > 0
        push_zeros(difference, node: nil)
      elsif difference < 0
        pop(-difference, node: nil)
      end

      current_offset = next_offset
    end

    false
  end

  def visit(node : NamedTupleLiteral)
    type = node.type.as(NamedTupleInstanceType)

    current_offset = 0
    node.entries.each_with_index do |entry, i|
      entry.value.accept self
      aligned_size = aligned_sizeof_type(entry.value)
      next_offset =
        if i == node.entries.size - 1
          aligned_sizeof_type(type)
        else
          @context.offset_of(type, i + 1)
        end

      difference = next_offset - (current_offset + aligned_size)
      if difference > 0
        push_zeros(difference, node: nil)
      elsif difference < 0
        pop(-difference, node: nil)
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
      dup(aligned_sizeof_type(node.value), node: nil) if @wants_value

      index, type = lookup_local_var_index_and_type(target.name)

      # Before assigning to the var we must potentially box inside a union
      upcast node.value, node.value.type, type
      set_local index, aligned_sizeof_type(type), node: node
    when InstanceVar
      if inside_method?
        request_value(node.value)
        dup(aligned_sizeof_type(node.value), node: nil) if @wants_value

        ivar_offset = ivar_offset(scope, target.name)
        ivar = scope.lookup_instance_var(target.name)
        ivar_size = inner_sizeof_type(ivar.type)

        upcast node.value, node.value.type, ivar.type

        set_self_ivar ivar_offset, ivar_size, node: node
      else
        node.type = @context.program.nil_type
        put_nil node: nil if @wants_value
      end
    when ClassVar
      index = class_var_index(target)

      if inside_method?
        request_value(node.value)
        dup(aligned_sizeof_type(node.value), node: nil) if @wants_value

        var = target.var

        upcast node.value, node.value.type, var.type

        set_class_var index, aligned_sizeof_type(var), node: node
      else
        node.type = @context.program.nil_type
        put_nil node: nil if @wants_value
      end
    when Path
      # TODO: I think we should track that the constant is initialized at this point,
      # to avoid an init flag, we'll see
    else
      node.raise "BUG: missing interpret for #{node.class} with target #{node.target.class}"
    end
    false
  end

  def visit(node : Var)
    return false unless @wants_value

    index, type = lookup_local_var_index_and_type(node.name)

    if node.name == "self" && type.passed_by_value?
      # Load the entire self from the pointer that's self
      get_self_ivar 0, aligned_sizeof_type(type), node: node
    else
      get_local index, aligned_sizeof_type(type), node: node
    end

    downcast node, type, node.type

    false
  end

  def lookup_local_var_index_and_type(name : String) : {Int32, Type}
    block_level = @block_level
    while block_level >= 0
      index = @local_vars.name_to_index?(name, block_level)
      if index
        type = @local_vars.type(name, block_level)
        return {index, type}
      end

      block_level -= 1
    end

    raise "BUG: can't find local var #{name}"
  end

  def visit(node : InstanceVar)
    return false unless @wants_value

    ivar_offset = ivar_offset(scope, node.name)
    ivar_size = inner_sizeof_type(scope.lookup_instance_var(node.name))

    get_self_ivar ivar_offset, ivar_size, node: node
    false
  end

  def visit(node : ClassVar)
    index = class_var_index(node)
    get_class_var index, aligned_sizeof_type(node.var), node: node

    false
  end

  private def class_var_index(node : ClassVar)
    var = node.var

    case var.owner
    when VirtualType
      node.raise "BUG: missing interpret class var for virtual type"
    when VirtualMetaclassType
      node.raise "BUG: missing interpret class var for virtual metaclass type"
    end

    index = @context.class_var_index?(var.owner, var.name)
    unless index
      initializer = var.initializer
      if initializer
        def_name = "#{var.owner}::#{var.name}}"
        fake_def = Def.new(def_name)
        fake_def.owner = var.owner

        compiled_def = CompiledDef.new(@context, fake_def, 0)

        # Declare local variables for the constant initializer
        initializer.meta_vars.each do |name, var|
          compiled_def.local_vars.declare(name, var.type)
        end

        value = initializer.node
        value = @context.program.cleanup(value)

        compiler = Compiler.new(@context, compiled_def)
        compiler.compile(value)

        if @context.decompile
          puts "=== #{def_name} ==="
          puts Disassembler.disassemble(@context, compiled_def)
          puts "=== #{def_name} ==="
        end
      end

      index = @context.declare_class_var(var.owner, var.name, var.type, compiled_def)
    end

    index
  end

  def visit(node : ReadInstanceVar)
    # TODO: check struct
    node.obj.accept self

    type = node.obj.type

    ivar_offset = ivar_offset(type, node.name)
    ivar_size = inner_sizeof_type(type.lookup_instance_var(node.name))

    get_class_ivar ivar_offset, ivar_size, node: node
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

      upcast node.then, node.then.type, node.type
      return false
    elsif node.falsey?
      discard_value(node.cond)
      node.else.accept self
      return false unless @wants_value

      upcast node.else, node.else.type, node.type
      return false
    end

    request_value(node.cond)
    value_to_bool(node.cond, node.cond.type)

    branch_unless 0, node: nil
    cond_jump_location = patch_location

    node.then.accept self
    upcast node.then, node.then.type, node.type if @wants_value

    jump 0, node: nil
    then_jump_location = patch_location

    patch_jump(cond_jump_location)

    node.else.accept self
    upcast node.else, node.else.type, node.type if @wants_value

    patch_jump(then_jump_location)

    false
  end

  def visit(node : While)
    # Jump directly to the condition
    jump 0, node: nil
    cond_jump_location = patch_location

    body_index = @instructions.size

    old_while = @while
    old_while_breaks = @while_breaks
    old_while_nexts = @while_nexts

    @while = node
    while_breaks = @while_breaks = [] of Int32
    while_nexts = @while_nexts = [] of Int32

    # Now write the body
    discard_value(node.body)

    # Here starts the condition.
    # Any `next` that happened leads us here.
    while_nexts.each do |while_next|
      patch_jump(while_next)
    end

    patch_jump(cond_jump_location)
    request_value(node.cond)
    value_to_bool(node.cond, node.cond.type)

    # If the condition holds, jump back to the body
    branch_if body_index, node: nil

    # Here we are at the point where the condition didn't hold anymore.
    # We must convert `nil` to whatever while's type is.
    upcast node.body, @context.program.nil_type, node.type

    # Otherwise we are at the end of the while.
    # Any `break` that happened leads us here
    while_breaks.each do |while_break|
      patch_jump(while_break)
    end

    unless @wants_value
      pop aligned_sizeof_type(node), node: nil
    end

    @while = old_while
    @while_breaks = old_while_breaks
    @while_nexts = old_while_nexts

    false
  end

  def visit(node : Return)
    exp = node.exp

    exp_type =
      if exp
        request_value(exp)
        exp.type
      else
        put_nil node: node
        @context.program.nil_type
      end

    def_type = @def.not_nil!.type

    compiled_block = @compiled_block
    if compiled_block
      def_type = merge_block_break_type(def_type, compiled_block.block)
    end

    upcast node, exp_type, def_type

    if @compiling_block
      leave_def aligned_sizeof_type(def_type), node: node
    else
      leave aligned_sizeof_type(def_type), node: node
    end

    false
  end

  def visit(node : IsA)
    node.obj.accept self
    return false unless @wants_value

    obj_type = node.obj.type
    const_type = node.const.type

    filtered_type = obj_type.filter_by(const_type).not_nil!

    if obj_type.is_a?(MixedUnionType)
      union_is_a(aligned_sizeof_type(obj_type), type_id(filtered_type), node: node)
    else
      node.raise "BUG: missing IsA for #{obj_type}"
    end

    false
  end

  def visit(node : TypeOf)
    return false unless @wants_value

    put_type node.type, node: node
    false
  end

  def visit(node : Path)
    return false unless @wants_value

    if const = node.target_const
      if const.value.simple_literal?
        const.value.accept self
      else
        index = @context.const_index?(const)
        unless index
          fake_def = const.fake_def.not_nil!
          fake_def.owner = const.visitor.not_nil!.current_type

          compiled_def = CompiledDef.new(@context, fake_def, 0)

          # Declare local variables for the constant initializer
          fake_def.vars.try &.each do |name, var|
            compiled_def.local_vars.declare(name, var.type)
          end

          value = const.value
          value = @context.program.cleanup(value)

          compiler = Compiler.new(@context, compiled_def)
          compiler.compile(value)

          if @context.decompile
            puts "=== #{const} ==="
            puts Disassembler.disassemble(@context, compiled_def)
            puts "=== #{const} ==="
          end

          index = @context.declare_const(const, compiled_def)
        end

        get_const index, aligned_sizeof_type(const.value), node: node
      end
    elsif replacement = node.syntax_replacement
      replacement.accept self
    else
      put_type node.type, node: node
    end
    false
  end

  def visit(node : Generic)
    return false unless @wants_value

    put_type node.type, node: node
    false
  end

  def visit(node : PointerOf)
    return false unless @wants_value

    exp = node.exp
    case exp
    when Var
      index, type = lookup_local_var_index_and_type(exp.name)
      pointerof_var(index, node: node)
    when InstanceVar
      index = scope.index_of_instance_var(exp.name).not_nil!
      if scope.struct?
        pointerof_ivar(@context.offset_of(scope, index), node: node)
      else
        pointerof_ivar(@context.instance_offset_of(scope, index), node: node)
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
    logical_not node: node

    false
  end

  def visit(node : Cast)
    node.obj.accept self

    obj_type = node.obj.type
    to_type = node.to.type.virtual_type

    if obj_type == to_type
      # TODO: not tested
      nop
    elsif obj_type.is_a?(PointerInstanceType) && to_type.is_a?(PointerInstanceType)
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
    obj = node.obj

    target_defs = node.target_defs
    unless target_defs
      node.raise "BUG: no target defs"
    end

    if target_defs.size == 1
      target_def = target_defs.first
    else
      target_def = Multidispatch.create_def(@context, node, target_defs)
    end

    body = target_def.body
    if body.is_a?(Primitive)
      visit_primitive(node, body)
      return false
    end

    if obj && (obj_type = obj.type).is_a?(LibType)
      compile_lib_call(node, obj_type)
      return false
    end

    compiled_def = @context.defs[target_def]? ||
                   create_compiled_def(node, target_def)

    pop_obj = compile_call_args(node, target_def)

    if node.block
      call_with_block compiled_def, node: node
    else
      call compiled_def, node: node
    end

    if @wants_value
      # Pop the struct that's on the stack, if any, if obj was a struct
      # (but the struct is after the call's value, so we must
      # remove it past that value)
      pop_from_offset aligned_sizeof_type(pop_obj), aligned_sizeof_type(node), node: nil if pop_obj
    else
      if pop_obj
        pop aligned_sizeof_type(node) + aligned_sizeof_type(pop_obj), node: nil
      else
        pop aligned_sizeof_type(node), node: nil
      end
    end

    false
  end

  private def compile_lib_call(node : Call, obj_type)
    target_def = node.target_def
    external = target_def.as(External)

    # TODO: named args
    node.args.each { |arg| request_value(arg) }

    lib_function = @context.lib_functions[external] ||= LibFunction.new(
      def: external,
      symbol: @context.c_function(obj_type, external.real_name),
      call_interface: FFI::CallInterface.new(
        abi: FFI::ABI::DEFAULT,
        args: external.args.map(&.type.ffi_type),
        return_type: external.type.ffi_type,
      )
    )

    lib_call(lib_function, node: node)

    pop aligned_sizeof_type(node), node: nil unless @wants_value

    return false
  end

  private def create_compiled_def(node : Call, target_def : Def)
    block = node.block
    block = nil if block && !block.visited?

    # Compile the block too if there's one
    if block
      compiled_block = create_compiled_block(block, target_def)
    end

    args_bytesize = 0

    obj = node.obj
    args = node.args
    named_args = node.named_args
    obj_type = obj.try(&.type) || target_def.owner

    if obj_type == @context.program
      # Nothing
    elsif obj_type.passed_by_value?
      args_bytesize += sizeof(Pointer(UInt8))
    else
      args_bytesize += aligned_sizeof_type(obj_type)
    end

    args_bytesize += args.sum { |arg| aligned_sizeof_type(arg) }
    args_bytesize += named_args.sum { |arg| aligned_sizeof_type(arg.value) } if named_args

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
      compiler.compile_def(target_def)
    rescue ex : Crystal::CodeError
      node.raise "compiling #{node}", inner: ex
    end

    if @context.decompile
      puts "=== #{target_def.owner}##{target_def.name} ==="
      puts compiled_def.local_vars
      puts Disassembler.disassemble(@context, compiled_def)
      puts "=== #{target_def.owner}##{target_def.name} ==="
    end

    compiled_def
  end

  private def create_compiled_block(block : Block, target_def : Def)
    bytesize_before_block_local_vars = @local_vars.current_bytesize

    @local_vars.push_block

    begin
      block.vars.try &.each do |name, var|
        next if var.context != block

        @local_vars.declare(name, var.type)
      end

      bytesize_after_block_local_vars = @local_vars.current_bytesize

      block_args_bytesize = block.args.sum { |arg| aligned_sizeof_type(arg) }

      compiled_block = CompiledBlock.new(block, @local_vars,
        args_bytesize: block_args_bytesize,
        locals_bytesize_start: bytesize_before_block_local_vars,
        locals_bytesize_end: bytesize_after_block_local_vars,
      )

      # Store it so the GC doesn't collect it (it's in the instructions but it might not be aligned)
      @context.gc_references << compiled_block.object_id

      compiler = Compiler.new(@context, @local_vars,
        instructions: compiled_block.instructions,
        nodes: compiled_block.nodes,
        scope: @scope, def: @def)
      compiler.compiled_block = @compiled_block
      compiler.block_level = block_level + 1
      compiler.compile_block(block, target_def)

      if @context.decompile
        puts "=== #{target_def.owner}##{target_def.name}#block ==="
        puts Disassembler.disassemble(@context, compiled_block.instructions, compiled_block.nodes, @local_vars)
        puts "=== #{target_def.owner}##{target_def.name}#block ==="
      end
    ensure
      @local_vars.pop_block
    end

    compiled_block
  end

  private def compile_call_args(node : Call, target_def : Def)
    # Self for structs is passed by reference
    pop_obj = nil

    obj = node.obj
    if obj
      if obj.type.passed_by_value?
        case obj
        when Var
          if obj.name == "self"
            self_type = @def.not_nil!.vars.not_nil!["self"].type
            if self_type == target_def.owner
              put_self(node: obj)
            else
              # It might happen that self's type was narrowed down,
              # so we need to accept it regularly and downcast it.
              request_value(obj)

              # Then take a pointer to it (this is self inside the method)
              put_stack_top_pointer(aligned_sizeof_type(obj), node: nil)

              # We must remember to later pop the struct that's still on the stack
              pop_obj = obj
            end
          else
            ptr_index, var_type = lookup_local_var_index_and_type(obj.name)
            if obj.type == var_type
              pointerof_var(ptr_index, node: obj)
            elsif var_type.is_a?(MixedUnionType) && obj.type.struct?
              # Get pointer of var
              pointerof_var(ptr_index, node: obj)

              # Add 8 to it, to reach the union value
              put_i64 8_i64, node: nil
              pointer_add 1_i64, node: nil
            else
              node.raise "BUG: missing call receiver by value cast from #{var_type} to #{obj.type}"
            end
          end
        when InstanceVar
          index = scope.index_of_instance_var(obj.name).not_nil!
          pointerof_ivar(@context.offset_of(scope, index), node: node)
        else
          # For a struct, we first put it on the stack
          request_value(obj)

          # Then take a pointer to it (this is self inside the method)
          put_stack_top_pointer(aligned_sizeof_type(obj), node: nil)

          # We must remember to later pop the struct that's still on the stack
          pop_obj = obj
        end
      else
        request_value(obj)
      end
    else
      # Pass implicit self if needed
      put_self(node: node) unless node.scope.is_a?(Program)
    end

    node.args.each { |a| request_value(a) }
    node.named_args.try &.each { |n| request_value(n) }

    pop_obj
  end

  private def accept_call_members(node : Call)
    if obj = node.obj
      obj.accept(self)
    else
      put_self(node: node) unless scope.is_a?(Program)
    end

    node.args.each &.accept(self)
    node.named_args.try &.each &.value.accept(self)
  end

  def visit(node : ProcLiteral)
    is_closure = node.def.closure?
    if is_closure
      node.raise "BUG: closures not yet supported"
    end

    # TODO: This was copied from Codegen. Why is it not in CleanupTransformer?
    # If we don't care about a proc literal's return type then we mark the associated
    # def as returning void. This can't be done in the type inference phase because
    # of bindings and type propagation.
    if node.force_nil?
      node.def.set_type @context.program.nil
    else
      # Use proc literal's type, which might have a broader type then the body
      # (for example, return type: Int32 | String, body: String)
      node.def.set_type node.return_type
    end

    target_def = node.def
    target_def.owner = @context.program
    args = target_def.args

    # 1. Compile def
    args_bytesize = args.sum { |arg| aligned_sizeof_type(arg) }
    compiled_def = CompiledDef.new(@context, target_def, args_bytesize)

    # 2. Store it in context
    @context.gc_references << compiled_def.object_id

    # Declare local variables for the newly compiled function
    target_def.vars.try &.each do |name, var|
      compiled_def.local_vars.declare(name, var.type)
    end

    compiler = Compiler.new(@context, compiled_def)
    begin
      compiler.compile_def(target_def)
    rescue ex : Crystal::CodeError
      node.raise "compiling #{node}", inner: ex
    end

    # 3. Push compiled_def id to stack
    put_i64 compiled_def.object_id.to_i64!, node: node

    # 4. Push context to stack (null for now, so i64 0)
    put_i64 0, node: node

    false
  end

  def visit(node : Break)
    exp = node.exp

    exp_type =
      if exp
        request_value(exp)
        exp.type
      else
        put_nil node: node

        @context.program.nil_type
      end

    if compiling_block = @compiling_block
      block = compiling_block.block
      target_def = compiling_block.target_def

      final_type = merge_block_break_type(target_def.type, block)

      upcast node, exp_type, final_type

      break_block aligned_sizeof_type(final_type), node: node
    else
      target_while = @while.not_nil!

      upcast node, exp_type, target_while.type

      jump 0, node: nil
      @while_breaks.not_nil! << patch_location
    end

    false
  end

  def visit(node : Next)
    exp = node.exp

    if compiling_block = @compiling_block
      exp_type =
        if exp
          request_value(exp)
          exp.type
        else
          put_nil node: node
          @context.program.nil_type
        end

      upcast node, exp_type, compiling_block.block.type
      leave aligned_sizeof_type(compiling_block.block.type), node: node
    else
      if exp
        discard_value(exp)
      else
        put_nil node: node
      end

      jump 0, node: nil
      @while_nexts.not_nil! << patch_location
    end

    false
  end

  def visit(node : Yield)
    compiled_block = @compiled_block.not_nil!
    block = compiled_block.block

    splat_index = block.splat_index
    if splat_index
      node.raise "BUG: block with splat not yet supported"
    end

    if node.exps.any?(Splat)
      node.raise "BUG: splat inside yield not yet supported"
    end

    pop_obj = nil

    # Check if tuple unpacking is needed
    if node.exps.size == 1 &&
       (tuple_type = node.exps.first.type).is_a?(TupleInstanceType) &&
       block.args.size > 1
      # Accept the tuple
      exp = node.exps.first
      request_value exp

      offset = aligned_sizeof_type(tuple_type)

      # Now copy tuple members to block args
      block.args.each_with_index do |arg, i|
        tuple_element_type = tuple_type.tuple_types[i]
        inner_size = inner_sizeof_type(tuple_element_type)

        # Copy inner size bytes from the struct.
        # The interpreter will make sure to align this value.
        copy_from(offset, inner_size, node: nil)

        upcast exp, tuple_element_type, arg.type

        current_offset =
          @context.offset_of(tuple_type, i)

        next_offset =
          if i == tuple_type.tuple_types.size - 1
            aligned_sizeof_type(tuple_type)
          else
            @context.offset_of(tuple_type, i + 1)
          end

        # Now we have arg.type in front of the tuple so we must skip it
        offset += aligned_sizeof_type(arg.type)
        # But we need to access the next tuple member, so we move forward
        offset -= next_offset - current_offset
      end

      # We need to discard the tuple value that comes before the unpacked values
      pop_obj = tuple_type
    else
      node.exps.each_with_index do |exp, i|
        if i < block.args.size
          request_value(exp)
          upcast exp, exp.type, block.args[i].type
        else
          discard_value(exp)
        end
      end
    end

    call_block compiled_block, node: node

    if @wants_value
      pop_from_offset aligned_sizeof_type(pop_obj), aligned_sizeof_type(node), node: nil if pop_obj
    else
      if pop_obj
        pop aligned_sizeof_type(node) + aligned_sizeof_type(pop_obj), node: nil
      else
        pop aligned_sizeof_type(node), node: nil
      end
    end

    false
  end

  def visit(node : ClassDef)
    # TODO: change scope
    node.body.accept self

    return false unless @wants_value

    put_nil(node: node)
    false
  end

  def visit(node : ModuleDef)
    # TODO: change scope
    node.body.accept self

    return false unless @wants_value

    put_nil(node: node)
    false
  end

  def visit(node : Def)
    return false unless @wants_value

    put_nil(node: node)
    false
  end

  def visit(node : Unreachable)
    unreachable(node: node)

    false
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing interpret for #{node.class}"
  end

  {% for name, instruction in Crystal::Repl::Instructions %}
    {% operands = instruction[:operands] %}

    def {{name.id}}(
      {% if operands.empty? %}
        *, node : ASTNode?
      {% else %}
        {{*operands}}, *, node : ASTNode?
      {% end %}
    ) : Nil
      @nodes[@instructions.size] = node if node

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

  # TODO: block.break shouldn't exist: the type should be merged in target_def
  private def merge_block_break_type(def_type : Type, block : Block)
    block_break_type = block.break.type?
    if block_break_type
      @context.program.type_merge([def_type, block_break_type] of Type) ||
        @context.program.no_return
    else
      def_type
    end
  end

  private def put_true(*, node : ASTNode?)
    put_i64 1_i64, node: node
  end

  private def put_false(*, node : ASTNode?)
    put_i64 0_i64, node: node
  end

  private def put_i8(value : Int8, *, node : ASTNode)
    put_i64 value.to_i64!, node: node
  end

  private def put_u8(value : UInt8, *, node : ASTNode)
    put_i64 value.to_u64!.to_i64!, node: node
  end

  private def put_i16(value : Int16, *, node : ASTNode)
    put_i64 value.to_i64!, node: node
  end

  private def put_u16(value : UInt16, *, node : ASTNode)
    put_i64 value.to_u64!.to_i64!, node: node
  end

  private def put_i32(value : Int32, *, node : ASTNode)
    put_i64 value.to_i64!, node: node
  end

  private def put_u32(value : UInt32, *, node : ASTNode)
    put_i64 value.to_u64!.to_i64!, node: node
  end

  private def put_u64(value : UInt64, *, node : ASTNode)
    put_i64 value.to_i64!, node: node
  end

  private def put_type(type : Type, *, node : ASTNode)
    put_i32 type_id(type), node: node
  end

  private def put_def(a_def : Def)
  end

  private def put_self(*, node : ASTNode)
    if scope.struct?
      if scope.passed_by_value?
        get_local 0, sizeof(Pointer(UInt8)), node: node
      else
        get_local 0, aligned_sizeof_type(scope), node: node
      end
    else
      get_local 0, sizeof(Pointer(UInt8)), node: node
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

  private def append(lib_function : LibFunction)
    append(lib_function.object_id.unsafe_as(Int64))
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

  private def append(value : Symbol)
    value.unsafe_as(StaticArray(UInt8, 4)).each do |byte|
      append byte
    end
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

  private def aligned_sizeof_type(node : ASTNode) : Int32
    @context.aligned_sizeof_type(node)
  end

  private def aligned_sizeof_type(type : Type) : Int32
    @context.aligned_sizeof_type(type)
  end

  private def inner_sizeof_type(node : ASTNode) : Int32
    @context.inner_sizeof_type(node)
  end

  private def inner_sizeof_type(type : Type) : Int32
    @context.inner_sizeof_type(type)
  end

  private def aligned_instance_sizeof_type(type : Type) : Int32
    @context.aligned_instance_sizeof_type(type)
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
