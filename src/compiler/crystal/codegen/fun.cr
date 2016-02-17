require "./codegen"

class Crystal::CodeGenVisitor
  def target_def_fun(target_def, self_type)
    mangled_name = target_def.mangled_name(self_type)
    self_type_mod = type_module(self_type)

    func = self_type_mod.functions[mangled_name]? || codegen_fun(mangled_name, target_def, self_type)
    check_mod_fun self_type_mod, mangled_name, func
  end

  def main_fun(name)
    func = @main_mod.functions[name]?
    unless func
      raise "Bug: #{name} is not defined"
    end

    check_main_fun name, func
  end

  def check_main_fun(name, func)
    check_mod_fun @main_mod, name, func
  end

  def check_mod_fun(mod, name, func)
    return func if @llvm_mod == mod
    @llvm_mod.functions[name]? || declare_fun(name, func)
  end

  def declare_fun(mangled_name, func)
    new_fun = @llvm_mod.functions.add(
      mangled_name,
      func.params.types,
      func.return_type,
      func.varargs?
    )
    func.params.to_a.zip(new_fun.params.to_a) do |p1, p2|
      val = p1.attributes
      p2.add_attribute val if val.value != 0
    end
    new_fun
  end

  def codegen_fun(mangled_name, target_def, self_type, is_exported_fun = false, fun_module = type_module(self_type), is_fun_literal = false, is_closure = false)
    old_position = insert_block
    old_entry_block = @entry_block
    old_alloca_block = @alloca_block
    old_ensure_exception_handlers = @ensure_exception_handlers
    old_rescue_block = @rescue_block
    old_llvm_mod = @llvm_mod
    old_needs_value = @needs_value

    with_cloned_context do |old_context|
      context.type = self_type
      context.vars = LLVMVars.new
      context.block_context = nil

      @llvm_mod = fun_module

      @ensure_exception_handlers = nil
      @rescue_block = nil
      @needs_value = true

      args = codegen_fun_signature(mangled_name, target_def, self_type, is_fun_literal, is_closure)

      needs_body = !target_def.is_a?(External) || is_exported_fun
      if needs_body
        emit_def_debug_metadata target_def if @debug

        context.fun.add_attribute LLVM::Attribute::UWTable
        if @mod.has_flag?("darwin")
          # Disable frame pointer elimination in Darwin, as it causes issues during stack unwind
          context.fun.add_target_dependent_attribute "no-frame-pointer-elim", "true"
          context.fun.add_target_dependent_attribute "no-frame-pointer-elim-non-leaf", "true"
        end

        new_entry_block

        if is_closure
          clear_current_debug_location if @debug
          setup_closure_vars context.closure_vars.not_nil!
        else
          context.reset_closure
        end

        if !is_fun_literal && self_type.passed_as_self?
          context.vars["self"] = LLVMVar.new(context.fun.params.first, self_type, true)
        end

        if is_closure
          # In the case of a closure fun literal (-> { ... }), the closure_ptr is not
          # the one of the parent context, it's the last parameter of this fun literal.
          closure_parent_context = old_context.clone
          closure_parent_context.closure_ptr = fun_literal_closure_ptr
          context.closure_parent_context = closure_parent_context
        end

        set_current_debug_location target_def if @debug
        alloca_vars target_def.vars, target_def, args, context.closure_parent_context

        if @debug
          in_alloca_block do
            context.vars.each do |name, var|
              declare_variable(name, var.type, var.pointer, target_def)
            end
          end
        end

        create_local_copy_of_fun_args(target_def, self_type, args, is_fun_literal, is_closure)

        context.return_type = target_def.type?
        context.return_phi = nil

        accept target_def.body

        set_current_debug_location target_def.end_location if @debug
        codegen_return target_def.body.type?

        br_from_alloca_to_entry
      end

      position_at_end old_position

      @last = llvm_nil

      @llvm_mod = old_llvm_mod
      @ensure_exception_handlers = old_ensure_exception_handlers
      @rescue_block = old_rescue_block
      @entry_block = old_entry_block
      @alloca_block = old_alloca_block
      @needs_value = old_needs_value

      context.fun
    end
  end

  def codegen_fun_signature(mangled_name, target_def, self_type, is_fun_literal, is_closure)
    if target_def.is_a?(External)
      codegen_fun_signature_external(mangled_name, target_def)
    else
      codegen_fun_signature_non_external(mangled_name, target_def, self_type, is_fun_literal, is_closure)
    end
  end

  def codegen_fun_signature_non_external(mangled_name, target_def, self_type, is_fun_literal, is_closure)
    args = Array(Arg).new(target_def.args.size + 1)

    if !is_fun_literal && self_type.passed_as_self?
      args.push Arg.new("self", type: self_type)
    end

    args.concat target_def.args

    if target_def.uses_block_arg
      block_arg = target_def.block_arg.not_nil!
      args.push Arg.new(block_arg.name, type: block_arg.type)
    end

    target_def.special_vars.try &.each do |special_var_name|
      args.push Arg.new(special_var_name, type: target_def.vars.not_nil![special_var_name].type)
    end

    llvm_args_types = args.map do |arg|
      arg_type = arg.type
      if arg_type.void?
        arg_type = LLVM::Int8
      else
        arg_type = llvm_arg_type(arg_type)
        arg_type = arg_type.pointer if arg.special_var?
      end
      arg_type
    end
    llvm_return_type = llvm_type(target_def.type)

    if is_closure
      llvm_args_types.insert(0, LLVM::VoidPointer)
      offset = 1
    else
      offset = 0
    end

    no_inline = setup_context_fun(mangled_name, target_def, llvm_args_types, llvm_return_type)

    if @single_module && !no_inline
      context.fun.linkage = LLVM::Linkage::Internal
    end

    args.each_with_index do |arg, i|
      param = context.fun.params[i + offset]
      param.name = arg.name

      # Set 'byval' attribute
      # but don't set it if it's the "self" argument and it's a struct (while not in a closure).
      if arg.type.passed_by_value?
        if (is_fun_literal && !is_closure) || (is_closure || !(i == 0 && self_type.struct?))
          param.add_attribute LLVM::Attribute::ByVal
        end
      end
    end

    args
  end

  def codegen_fun_signature_external(mangled_name, target_def)
    args = target_def.args.dup

    # This is the case where we declared a fun that was not used and now we
    # are defining its body.
    if existing_fun = @llvm_mod.functions[mangled_name]?
      context.fun = existing_fun
      return args
    end

    offset = 0

    abi_info = abi_info(target_def)

    llvm_args_types = Array(LLVM::Type).new(abi_info.arg_types.size)
    abi_info.arg_types.each do |arg_type|
      case arg_type.kind
      when LLVM::ABI::ArgKind::Direct
        llvm_args_types << (arg_type.cast || arg_type.type)
      when LLVM::ABI::ArgKind::Indirect
        llvm_args_types << arg_type.type.pointer
      when LLVM::ABI::ArgKind::Ignore
        # ignore
      end
    end

    ret_type = abi_info.return_type
    case ret_type.kind
    when LLVM::ABI::ArgKind::Direct
      llvm_return_type = (ret_type.cast || ret_type.type)
    when LLVM::ABI::ArgKind::Indirect
      sret = true
      offset += 1
      llvm_args_types.insert 0, ret_type.type.pointer
      llvm_return_type = LLVM::Void
    else
      llvm_return_type = LLVM::Void
    end

    setup_context_fun(mangled_name, target_def, llvm_args_types, llvm_return_type)

    if call_convention = target_def.call_convention
      context.fun.call_convention = call_convention
    end

    i = 0
    args.each do |arg|
      param = context.fun.params[i + offset]
      param.name = arg.name

      abi_arg_type = abi_info.arg_types[i]

      if attr = abi_arg_type.attr
        param.add_attribute attr
      end

      i += 1 unless abi_arg_type.kind == LLVM::ABI::ArgKind::Ignore
    end

    # This is for sret
    if (attr = abi_info.return_type.attr) && attr == LLVM::Attribute::StructRet
      context.fun.params[0].add_attribute attr
    end

    args
  end

  def abi_info(external : External)
    external.abi_info ||= begin
      llvm_args_types = external.args.map { |arg| llvm_c_type(arg.type) }
      llvm_return_type = llvm_c_return_type(external.type)
      @abi.abi_info(llvm_args_types, llvm_return_type, !llvm_return_type.void?)
    end
  end

  def abi_info(external : External, node : Call)
    llvm_args_types = node.args.map { |arg| llvm_c_type(arg.type) }
    llvm_return_type = llvm_c_return_type(external.type)
    @abi.abi_info(llvm_args_types, llvm_return_type, !llvm_return_type.void?)
  end

  def setup_context_fun(mangled_name, target_def, llvm_args_types, llvm_return_type)
    context.fun = @llvm_mod.functions.add(
      mangled_name,
      llvm_args_types,
      llvm_return_type,
      target_def.varargs,
    )
    context.fun.add_attribute LLVM::Attribute::NoReturn if target_def.no_returns?

    no_inline = false
    target_def.attributes.try &.each do |attribute|
      case attribute.name
      when "NoInline"
        context.fun.add_attribute LLVM::Attribute::NoInline
        context.fun.linkage = LLVM::Linkage::External
        no_inline = true
      when "AlwaysInline"
        context.fun.add_attribute LLVM::Attribute::AlwaysInline
      when "ReturnsTwice"
        context.fun.add_attribute LLVM::Attribute::ReturnsTwice
      when "Naked"
        context.fun.add_attribute LLVM::Attribute::Naked
      end
    end
    no_inline
  end

  def setup_closure_vars(closure_vars, context = self.context, closure_ptr = fun_literal_closure_ptr)
    if context.closure_skip_parent
      parent_context = context.closure_parent_context.not_nil!
      setup_closure_vars(parent_context.closure_vars.not_nil!, parent_context, closure_ptr)
    else
      closure_vars.each_with_index do |var, i|
        self.context.vars[var.name] = LLVMVar.new(gep(closure_ptr, 0, i, var.name), var.type)
      end

      if (closure_parent_context = context.closure_parent_context) &&
         (parent_vars = closure_parent_context.closure_vars)
        parent_closure_ptr = gep(closure_ptr, 0, closure_vars.size, "parent_ptr")
        setup_closure_vars(parent_vars, closure_parent_context, load(parent_closure_ptr, "parent"))
      elsif closure_self = context.closure_self
        offset = context.closure_parent_context ? 1 : 0
        self_value = gep(closure_ptr, 0, closure_vars.size + offset, "self")
        self_value = load(self_value) unless context.type.passed_by_value?
        self.context.vars["self"] = LLVMVar.new(self_value, closure_self, true)
      end
    end
  end

  def fun_literal_closure_ptr
    void_ptr = context.fun.params.first
    bit_cast void_ptr, context.closure_type.not_nil!.pointer
  end

  def create_local_copy_of_fun_args(target_def, self_type, args, is_fun_literal, is_closure)
    offset = is_closure ? 1 : 0

    target_def_vars = target_def.vars
    args.each_with_index do |arg, i|
      param = context.fun.params[i + offset]
      if !is_fun_literal && (i == 0 && self_type.passed_as_self?)
        # here self is already in context.vars
      else
        create_local_copy_of_arg(target_def_vars, arg, param)
      end
    end
  end

  def create_local_copy_of_block_args(target_def, self_type, call_args)
    args_base_index = 0
    if self_type.passed_as_self?
      context.vars["self"] = LLVMVar.new(call_args[0], self_type, true)
      args_base_index = 1
    end

    target_def.args.each_with_index do |arg, i|
      create_local_copy_of_arg(target_def.vars, arg, call_args[args_base_index + i])
    end
  end

  def create_local_copy_of_arg(target_def_vars, arg, value)
    target_def_var = target_def_vars.try &.[arg.name]

    var_type = (target_def_var || arg).type
    return if var_type.void?

    if closure_var = context.vars[arg.name]?
      pointer = closure_var.pointer
    else
      # We don't need to create a copy of the argument if it's never
      # assigned a value inside the function.
      needs_copy = target_def_var.try &.assigned_to
      if needs_copy && !arg.special_var?
        pointer = alloca(llvm_type(var_type), arg.name)
        context.vars[arg.name] = LLVMVar.new(pointer, var_type)
      else
        context.vars[arg.name] = LLVMVar.new(value, var_type, true)
        return
      end
    end

    assign pointer, var_type, arg.type, value
  end

  def type_module(type)
    return @main_mod if @single_module

    @types_to_modules[type] ||= begin
      type = type.remove_typedef
      case type
      when Nil, Program, LibType
        type_name = ""
      else
        type_name = type.instance_type.to_s
      end

      @modules[type_name] ||= begin
        llvm_mod = LLVM::Module.new(type_name)
        define_symbol_table llvm_mod
        llvm_mod
      end
    end
  end
end
