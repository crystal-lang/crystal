require "./codegen"

class Crystal::CodeGenVisitor
  def visit(node : Call)
    if node.expanded
      raise "Bug: #{node} at #{node.location} should have been expanded"
    end

    target_defs = node.target_defs
    unless target_defs
      node.raise "Bug: no target defs"
    end

    if target_defs.length > 1
      # Check if it's a call on a union metaclass
      if (obj = node.obj) && (obj_type = obj.type?) && obj_type.is_a?(MetaclassType) && (instance_type = obj_type.instance_type).is_a?(UnionType)
        codegen_union_metaclass_call(instance_type, node)
        return false
      end

      codegen_dispatch node, target_defs
      return false
    end

    owner = node.name == "super" ? node.scope : node.target_def.owner

    call_args, has_out = prepare_call_args node, owner

    if block = node.block
      if fun_literal = block.fun_literal
        codegen_call_with_block_as_fun_literal(node, fun_literal, owner, call_args)
      else
        codegen_call_with_block(node, block, owner, call_args)
      end
    else
      codegen_call(node, node.target_def, owner, call_args)
    end

    # Now we move out values to the variables. This can be done automatically
    # because if declared inside a while, for example, the variable is nilable.
    if has_out
      node.args.zip(call_args) do |node_arg, call_arg|
        if node_arg.is_a?(Out) && (exp = node_arg.exp).is_a?(Var)
          node_var = context.vars[exp.name]
          assign node_var.pointer, node_var.type, node_arg.type, to_lhs(call_arg, node_arg.type)
        end
      end
    end

    false
  end

  def prepare_call_args(node, owner)
    target_def = node.target_def
    if target_def.is_a?(External)
      prepare_call_args_external(node, target_def, owner)
    else
      prepare_call_args_non_external(node, target_def, owner)
    end
  end

  def prepare_call_args_non_external(node, target_def, owner)
    call_args = Array(LLVM::Value).new(node.args.length + 1)
    old_needs_value = @needs_value

    # First self.
    if (obj = node.obj) && obj.type.passed_as_self?
      @needs_value = true
      accept obj
      call_args << downcast(@last, target_def.owner, obj.type, true)
    elsif owner.passed_as_self?
      if node.uses_with_scope? && (yield_scope = context.vars["%scope"]?)
        call_args << yield_scope.pointer
      else
        call_args << llvm_self(owner)
      end
    end

    # Then the arguments.
    node.args.zip(target_def.args) do |arg, def_arg|
      @needs_value = true
      accept arg

      if arg.type.void?
        call_arg = int8(0)
      else
        call_arg = @last
        call_arg = downcast(call_arg, def_arg.type, arg.type, true)
      end
      call_args << call_arg
    end

    # Then special variables ($~, $?)
    target_def.special_vars.try &.each do |special_var_name|
      call_args << context.vars[special_var_name].pointer
    end

    # Then magic constants (__LINE__, __FILE__, __DIR__)
    node.args.length.upto(target_def.args.length - 1) do |index|
      arg = target_def.args[index]
      default_value = arg.default_value as MagicConstant
      location = node.location
      case default_value.name
      when :__LINE__
        call_args << int32(MagicConstant.expand_line(location))
      when :__FILE__
        call_args << build_string_constant(MagicConstant.expand_file(location))
      when :__DIR__
        call_args << build_string_constant(MagicConstant.expand_dir(location))
      else
        default_value.raise "Bug: unknown magic constant: #{default_value.name}"
      end
    end

    @needs_value = old_needs_value

    {call_args, false}
  end

  def call_abi_info(target_def, node)
    # For varargs we need to compute abi info for the arguments, which may be more
    # than those specified in the function definition
    if target_def.varargs
      abi_info(target_def, node)
    else
      abi_info(target_def)
    end
  end

  def prepare_call_args_external(node, target_def, owner)
    has_out = false
    abi_info = call_abi_info(target_def, node)

    call_args = Array(LLVM::Value).new(node.args.length + 1)
    old_needs_value = @needs_value

    if abi_info.return_type.attr == LLVM::Attribute::StructRet
      sret_value = @sret_value = alloca abi_info.return_type.type
      call_args << sret_value
    end

    node.args.each_with_index do |arg, i|
      if arg.is_a?(Out)
        has_out = true
        case exp = arg.exp
        when Var
          # For out arguments we reserve the space. After the call
          # we move the value to the variable.
          call_arg = alloca(llvm_type(arg.type))
        when InstanceVar
          call_arg = instance_var_ptr(type, exp.name, llvm_self_ptr)
        else
          arg.raise "Bug: out argument was #{exp}"
        end
      else
        @needs_value = true
        accept arg

        if arg.type.void?
          call_arg = int8(0)
        else
          def_arg = target_def.args[i]?

          call_arg = @last

          if def_arg && arg.type.nil_type? && (def_arg.type.pointer? || def_arg.type.fun?)
            # Nil to pointer
            call_arg = llvm_c_type(def_arg.type).null
          else
            # Def argument might be missing if it's a variadic call
            call_arg = downcast(call_arg, def_arg.type, arg.type, true) if def_arg
          end
        end
      end

      if arg.type.fun?
        # Try first with the def arg type (might be a fun pointer that return void,
        # while the argument's type a fun pointer that return something else)
        call_arg = check_fun_is_not_closure(call_arg, def_arg.try(&.type) || arg.type)
      end

      abi_arg_type = abi_info.arg_types[i]
      case abi_arg_type.kind
      when LLVM::ABI::ArgKind::Direct
        if cast = abi_arg_type.cast
          final_value = alloca cast
          final_value_casted = bit_cast final_value, LLVM::VoidPointer
          gep_call_arg = bit_cast gep(call_arg, 0, 0), LLVM::VoidPointer
          size = @abi.size(abi_arg_type.type)
          align = @abi.align(abi_arg_type.type)
          memcpy(final_value_casted, gep_call_arg, int32(size), int32(align), int1(0))
          call_arg = load final_value
        else
          # Keep same call arg
        end
        call_args << call_arg
      when LLVM::ABI::ArgKind::Indirect
        # Pass argument as is (will be passed byval)
        call_args << call_arg
      when LLVM::ABI::ArgKind::Ignore
        # Ignore
      end
    end

    @needs_value = old_needs_value

    {call_args, has_out}
  end

  def codegen_call_with_block(node, block, self_type, call_args)
    with_cloned_context do |old_block_context|
      context.vars = old_block_context.vars.dup
      context.closure_parent_context = old_block_context

      # Allocate block vars, but first undefine variables outside
      # the block with the same name. This can only happen in this case:
      #
      #     a = foo { |a| }
      #
      # that is, when assigning to a variable with the same name as
      # a block argument (no shadowing here)
      undef_vars block.vars, block
      alloca_non_closured_vars block.vars, block

      with_cloned_context do |old_context|
        context.block = block
        context.block_context = old_context
        context.vars = LLVMVars.new
        context.type = self_type
        context.reset_closure

        target_def = node.target_def
        target_def.ensure_exception_handler = current_ensure_exception_handler

        alloca_vars target_def.vars, target_def
        create_local_copy_of_block_args(target_def, self_type, call_args)

        Phi.open(self, node) do |phi|
          context.return_phi = phi

          request_value do
            accept target_def.body
          end

          phi.add_last @last, target_def.body.type?
        end
      end
    end
  end

  def codegen_call_with_block_as_fun_literal(node, fun_literal, self_type, call_args)
    target_def = node.target_def
    func = target_def_fun(target_def, self_type)

    fun_literal.accept self
    call_args.push @last

    codegen_call_or_invoke(node, target_def, self_type, func, call_args, target_def.raises, target_def.type)
  end

  def codegen_dispatch(node, target_defs)
    new_vars = context.vars.dup
    old_needs_value = @needs_value

    # Get type_id of obj or owner
    if node_obj = node.obj
      owner = node_obj.type
      @needs_value = true
      accept node_obj
      obj_type_id = @last
    else
      owner = node.scope
      obj_type_id = llvm_self
    end
    obj_type_id = type_id(obj_type_id, owner)

    # Create self var if available
    if node_obj && node_obj.type.passed_as_self?
      new_vars["%self"] = LLVMVar.new(@last, node_obj.type, true)
    end

    # Get type if of args and create arg vars
    arg_type_ids = node.args.map_with_index do |arg, i|
      @needs_value = true
      accept arg
      new_vars["%arg#{i}"] = LLVMVar.new(@last, arg.type, true)
      type_id(@last, arg.type)
    end

    # Reuse this call for each dispatch branch
    call = Call.new(node_obj ? Var.new("%self") : nil, node.name, node.args.map_with_index { |arg, i| Var.new("%arg#{i}") as ASTNode }, node.block)
    call.scope = node.scope
    call.location = node.location

    with_cloned_context do
      context.vars = new_vars

      Phi.open(self, node, old_needs_value) do |phi|
        # Iterate all defs and check if any match the current types, given their ids (obj_type_id and arg_type_ids)
        target_defs.each do |a_def|
          result = match_type_id(owner, a_def.owner, obj_type_id)
          node.args.each_with_index do |node_arg, i|
            a_def_arg = a_def.args[i]
            result = and(result, match_type_id(node_arg.type, a_def_arg.type, arg_type_ids[i]))
          end

          current_def_label, next_def_label = new_blocks "current_def", "next_def"
          cond result, current_def_label, next_def_label

          position_at_end current_def_label

          # Prepare this specific call
          call.target_defs = [a_def] of Def
          call.obj.try &.set_type(a_def.owner)
          call.args.zip(a_def.args) do |call_arg, a_def_arg|
            call_arg.set_type(a_def_arg.type)
          end
          if (node_block = node.block) && node_block.break.type?
            call.set_type(@mod.type_merge [a_def.type, node_block.break.type] of Type)
          else
            call.set_type(a_def.type)
          end
          accept call

          phi.add @last, a_def.type
          position_at_end next_def_label
        end
        unreachable
      end
    end

    @needs_value = old_needs_value
  end

  # We codegen a call to the first type in the union, and cast it to the node's type.
  # So for example if you have ::(Int32 | Float64).zero it will give (0 as Int32 | Float)
  def codegen_union_metaclass_call(union_type, node)
    new_type = union_type.union_types.first.metaclass

    call = node.clone
    call.obj.not_nil!.set_type(new_type)

    node.args.zip(call.args) do |node_arg, call_arg|
      call_arg.set_type(node_arg.type?)
    end

    new_target_defs = node.target_defs.not_nil!.select { |a_def| a_def.owner == new_type }

    call.target_defs = new_target_defs
    call.bind_to(new_target_defs)
    call.scope = call.type

    call.accept(self)

    @last = upcast(@last, node.type, call.type)
  end

  def codegen_call(node, target_def, self_type, call_args)
    body = target_def.body
    if body.is_a?(Crystal::Primitive)
      # Change context type: faster then creating a new context
      old_type = context.type
      context.type = self_type
      codegen_primitive(body, target_def, call_args)
      context.type = old_type
      return
    end

    func = target_def_fun(target_def, self_type)
    codegen_call_or_invoke(node, target_def, self_type, func, call_args, target_def.raises, target_def.type)
  end

  def codegen_call_or_invoke(node, target_def, self_type, func, call_args, raises, type, is_closure = false, fun_type = nil)
    if raises && (rescue_block = @rescue_block)
      invoke_out_block = new_block "invoke_out"
      @last = builder.invoke func, call_args, invoke_out_block, rescue_block
      position_at_end invoke_out_block
    else
      @last = call func, call_args
    end

    if target_def.is_a?(External) && (call_convention = target_def.call_convention)
      @last.call_convention = call_convention
    end

    if @builder.end
      return @last
    end

    set_call_attributes node, target_def, self_type, is_closure, fun_type
    emit_debug_metadata node, @last if @debug

    if target_def.is_a?(External) && (target_def.type.fun? || target_def.type.is_a?(NilableFunType))
      fun_ptr = bit_cast(@last, LLVM::VoidPointer)
      ctx_ptr = LLVM::VoidPointer.null
      return @last = make_fun(target_def.type, fun_ptr, ctx_ptr)
    end

    if target_def.is_a?(External)
      if type.no_return?
        unreachable
      else
        abi_return = abi_info(target_def).return_type
        case abi_return.kind
        when LLVM::ABI::ArgKind::Direct
          if cast = abi_return.cast
            cast1 = alloca cast
            store @last, cast1
            cast2 = bit_cast cast1, LLVM::VoidPointer
            final_value = alloca abi_return.type
            final_value_casted = bit_cast final_value, LLVM::VoidPointer
            size = @abi.size(abi_return.type)
            align = @abi.align(abi_return.type)
            memcpy(final_value_casted, cast2, int32(size), int32(align), int1(0))
            @last = final_value
          end
        when LLVM::ABI::ArgKind::Indirect
          @last = @sret_value.not_nil!
        when LLVM::ABI::ArgKind::Ignore
          # Nothing
        end
      end
    else
      case type
      when .no_return?
        unreachable
      when .passed_by_value?
        if @needs_value
          union = alloca llvm_type(type)
          store @last, union
          @last = union
        else
          @last = llvm_nil
        end
      end
    end

    @last
  end

  def set_call_attributes(node : Call, target_def, self_type, is_closure, fun_type)
    if target_def.is_a?(External)
      set_call_attributes_external(node, target_def)
    else
      set_call_attributes_non_external(node, target_def, self_type, is_closure, fun_type)
    end
  end

  def set_call_attributes_non_external(node, target_def, self_type, is_closure, fun_type)
    arg_offset = 1
    arg_offset += 1 if self_type.try(&.passed_as_self?)

    node.args.each_with_index do |arg, i|
      next unless arg.type.passed_by_value?

      LibLLVM.add_instr_attribute(@last, (i + arg_offset).to_u32, LLVM::Attribute::ByVal)
    end
  end

  def set_call_attributes_external(node, target_def)
    abi_info = call_abi_info(target_def, node)

    sret = abi_info.return_type.attr == LLVM::Attribute::StructRet
    arg_offset = 1
    arg_offset += 1 if sret

    node.args.each_with_index do |arg, i|
      # If the argument is out the type might be a struct but we don't pass anything byval
      next if node.args[i]?.try &.is_a?(Out)

      abi_arg_type = abi_info.arg_types[i]?
      if abi_arg_type
        if (attr = abi_arg_type.attr)
          LibLLVM.add_instr_attribute(@last, (i + arg_offset).to_u32, attr)
        end
      else
        # TODO: this is for variadic arguments, which is still not handled properly (in regards to the ABI for structs)
        arg_type = arg.type
        next unless arg_type.passed_by_value?

        LibLLVM.add_instr_attribute(@last, (i + arg_offset).to_u32, LLVM::Attribute::ByVal)
      end
    end

    if sret
      LibLLVM.add_instr_attribute(@last, 1_u32, LLVM::Attribute::StructRet)
    end
  end

  # This is for function pointer calls and exception handler re-raise
  def set_call_attributes(node, target_def, self_type, is_closure, fun_type)
    arg_offset = is_closure ? 2 : 1
    arg_types = fun_type.try(&.arg_types) || target_def.try &.args.map &.type
    arg_types.try &.each_with_index do |arg_type, i|
      next unless arg_type.passed_by_value?
      LibLLVM.add_instr_attribute(@last, (i + arg_offset).to_u32, LLVM::Attribute::ByVal)
    end
  end
end
