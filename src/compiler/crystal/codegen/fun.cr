require "./codegen"

class Crystal::CodeGenVisitor
  def typed_fun?(mod : LLVM::Module, name : String) : LLVMTypedFunction?
    if func = mod.functions[name]?
      LLVMTypedFunction.new(@fun_types[{mod, name}], func)
    end
  end

  def add_typed_fun(mod : LLVM::Module, name : String, type : LLVM::Type) : LLVMTypedFunction
    func = mod.functions.add(name, type)
    @fun_types[{mod, name}] = type
    LLVMTypedFunction.new(type, func)
  end

  def fetch_typed_fun(mod : LLVM::Module, name : String, & : -> LLVM::Type) : LLVMTypedFunction
    typed_fun?(mod, name) || add_typed_fun(mod, name, yield)
  end

  def target_def_fun(target_def, self_type) : LLVMTypedFunction
    mangled_name = target_def.mangled_name(@program, self_type)
    self_type_mod = type_module(self_type).mod

    func = typed_fun?(self_type_mod, mangled_name) || codegen_fun(mangled_name, target_def, self_type)
    check_mod_fun self_type_mod, mangled_name, func
  end

  def main_fun(name)
    func = typed_fun?(@main_mod, name) || raise "BUG: #{name} is not defined"
    check_main_fun name, func
  end

  def check_main_fun(name, func : LLVMTypedFunction) : LLVMTypedFunction
    check_mod_fun @main_mod, name, func
  end

  def check_mod_fun(mod, name, func : LLVMTypedFunction) : LLVMTypedFunction
    if @llvm_mod == mod
      func
    elsif existing_func = @llvm_mod.functions[name]?
      LLVMTypedFunction.new(@fun_types[{@llvm_mod, name}], existing_func)
    else
      declare_fun(name, func)
    end
  end

  def declare_fun(mangled_name, func : LLVMTypedFunction) : LLVMTypedFunction
    type = @llvm_typer.copy_type(func.type)
    typed_fun = add_typed_fun(@llvm_mod, mangled_name, type)

    new_fun = typed_fun.func
    func.func.params.to_a.each_with_index do |p1, index|
      attrs = new_fun.attributes(index + 1)
      new_fun.add_attribute(attrs, index + 1) unless attrs.value == 0
    end

    typed_fun
  end

  def codegen_fun(mangled_name, target_def, self_type, is_exported_fun = false, fun_module_info = type_module(self_type), is_fun_literal = false, is_closure = false)
    old_position = insert_block
    old_entry_block = @entry_block
    old_alloca_block = @alloca_block
    old_ensure_exception_handlers = @ensure_exception_handlers
    old_rescue_block = @rescue_block
    old_catch_pad = @catch_pad
    old_llvm_mod = @llvm_mod
    old_llvm_context = @llvm_context
    old_llvm_typer = @llvm_typer
    old_builder = self.builder
    old_debug_location = @current_debug_location
    old_fun = context.fun

    old_needs_value = @needs_value

    with_cloned_context do |old_context|
      context.type = self_type
      context.vars = LLVMVars.new
      context.block_context = nil

      @llvm_mod = fun_module_info.mod
      @llvm_context = @llvm_mod.context
      @llvm_typer = fun_module_info.typer
      @builder = fun_module_info.builder

      @ensure_exception_handlers = nil
      @rescue_block = nil
      @catch_pad = nil
      @needs_value = true

      args = codegen_fun_signature(mangled_name, target_def, self_type, is_fun_literal, is_closure)

      needs_body = !target_def.is_a?(External) || is_exported_fun
      if needs_body
        emit_def_debug_metadata target_def unless @debug.none?
        set_current_debug_location target_def if @debug.line_numbers?

        {% if LibLLVM::IS_LT_150 %}
          context.fun.add_attribute LLVM::Attribute::UWTable
        {% else %}
          context.fun.add_attribute LLVM::Attribute::UWTable, value: @program.has_flag?("aarch64") ? LLVM::UWTableKind::Sync : LLVM::UWTableKind::Async
        {% end %}

        if @frame_pointers.always?
          context.fun.add_attribute "frame-pointer", value: "all"
        elsif @program.has_flag?("darwin") || @program.has_flag?("solaris")
          # Disable frame pointer elimination, as it causes issues during stack unwind
          context.fun.add_target_dependent_attribute "frame-pointer", "all"
        elsif @frame_pointers.non_leaf?
          context.fun.add_attribute "frame-pointer", value: "non-leaf"
        end

        new_entry_block

        if is_closure
          clear_current_debug_location if @debug.line_numbers?
          void_ptr = context.fun.params.first
          closure_type = llvm_typer.copy_type(context.closure_type.not_nil!)
          closure_ptr = pointer_cast void_ptr, closure_type.pointer
          setup_closure_vars target_def.vars, context.closure_vars.not_nil!, self.context, closure_type, closure_ptr
        else
          context.reset_closure
        end

        if !is_fun_literal && self_type.passed_as_self?
          context.vars["self"] = LLVMVar.new(context.fun.params.first, self_type, true)
        end

        if is_closure
          # In the case of a closure proc literal (-> { ... }), the closure_ptr is not
          # the one of the parent context, it's the last parameter of this proc literal.
          closure_parent_context = old_context.clone
          closure_parent_context.closure_ptr = closure_ptr.not_nil!
          context.closure_parent_context = closure_parent_context
        end

        set_current_debug_location target_def if @debug.line_numbers?
        alloca_vars target_def.vars, target_def, args, context.closure_parent_context

        create_local_copy_of_fun_args(target_def, self_type, args, is_fun_literal, is_closure)

        if @debug.variables? && !target_def.naked?
          in_alloca_block do
            location = target_def.location
            context.vars.each do |name, var|
              next if var.debug_variable_created

              # Self always comes as the first parameter, unless it's a closure:
              # then it will be fetched from the closure data.
              if name == "self" && !is_closure
                declare_debug_for_function_argument(name, var.type, 1, var.pointer, location)
                # Method debug parameters are skipped as they were defined in create_local_copy_of_fun_args()
                # due to LLVM variable dominance issue in some closure cases
              elsif args.none? { |arg| arg.name == name }
                declare_variable(name, var.type, var.pointer, location, alloca_block)
              end
            end
          end
        end

        context.return_type = target_def.type?
        context.return_phi = nil

        body = target_def.body

        # If the body is a primitive it means this is a function
        # that was generated by taking a pointer to it, for example
        # `a = 1; ->a.+(Int32)`.
        # In that case we need to inline the primitive code (as usual).
        if body.is_a?(Primitive)
          primitive_params = context.fun.params.to_a

          # If self is a primitive type it's actually passed as a pointer
          # (because the closure data is a pointer) and so we must load the
          # real value first.
          if args.first.type.is_a?(PrimitiveType)
            primitive_params[0] = load(llvm_type(args.first.type), primitive_params[0])
          end

          codegen_primitive(nil, body, target_def, primitive_params)
        else
          accept target_def.body
        end

        codegen_return(target_def)

        br_from_alloca_to_entry
      end

      @last = llvm_nil

      @llvm_mod = old_llvm_mod
      @llvm_context = old_llvm_context
      @llvm_typer = old_llvm_typer
      @builder = old_builder
      position_at_end old_position

      @ensure_exception_handlers = old_ensure_exception_handlers
      @rescue_block = old_rescue_block
      @catch_pad = old_catch_pad
      @entry_block = old_entry_block
      @alloca_block = old_alloca_block
      @needs_value = old_needs_value

      if @debug.line_numbers?
        # set_current_debug_location associates a scope from the current fun,
        # and at this point the current one should be the old one before
        # defining the fun. We do that. We also clear the debug location
        # if there was none before.
        if old_debug_location
          new_fun = context.fun
          context.fun = old_fun
          set_current_debug_location(old_debug_location)
          context.fun = new_fun
        else
          clear_current_debug_location
        end
      end

      if @program.has_flag?("wasm32")
        if target_def.is_a?(External) && (wasm_import_module = target_def.wasm_import_module)
          context.fun.add_target_dependent_attribute("wasm-import-name", target_def.real_name)
          context.fun.add_target_dependent_attribute("wasm-import-module", wasm_import_module)
        end

        if is_exported_fun
          context.fun.add_target_dependent_attribute("wasm-export-name", mangled_name)
        end
      end

      LLVMTypedFunction.new(context.fun_type, context.fun)
    end
  end

  def codegen_return(target_def : Def)
    # Check if this def must use the C calling convention and the return
    # value must be either casted or passed by sret
    if target_def.c_calling_convention? && target_def.abi_info?
      return_type = target_def.body.type
      if return_type.proc?
        @last = check_proc_is_not_closure(@last, return_type)
      end

      abi_info = abi_info(target_def)
      abi_ret_type = abi_info.return_type
      if cast = abi_ret_type.cast
        casted_last = pointer_cast @last, cast.pointer
        last = load cast, casted_last
        ret last
        return
      end

      if (attr = abi_ret_type.attr) && attr == LLVM::Attribute::StructRet
        store load(llvm_type(return_type), @last), context.fun.params[0]
        ret
        return
      end
    end

    codegen_return target_def.body.type?
  end

  def codegen_fun_signature(mangled_name, target_def, self_type, is_fun_literal, is_closure)
    if !is_closure && (external = target_def.c_calling_convention?)
      codegen_fun_signature_external(mangled_name, external)
    else
      codegen_fun_signature_non_external(mangled_name, target_def, self_type, is_fun_literal, is_closure)
    end
  end

  def codegen_fun_signature_non_external(mangled_name, target_def, self_type, is_fun_literal, is_closure)
    is_primitive = target_def.body.is_a?(Primitive)

    args = Array(Arg).new(target_def.args.size + 1)

    if !is_fun_literal && self_type.passed_as_self?
      args.push Arg.new("self", type: self_type)
    end

    args.concat target_def.args

    if target_def.uses_block_arg?
      block_arg = target_def.block_arg.not_nil!
      args.push Arg.new(block_arg.name, type: block_arg.type)
    end

    target_def.special_vars.try &.each do |special_var_name|
      args.push Arg.new(special_var_name, type: target_def.vars.not_nil![special_var_name].type)
    end

    llvm_args_types = args.map_with_index do |arg, i|
      arg_type = arg.type
      if arg_type.void?
        llvm_arg_type = llvm_context.int8
      else
        llvm_arg_type = llvm_type(arg_type)

        # We need an extra pointer for special vars (they always have an extra pointer)
        if arg.special_var?
          llvm_arg_type = llvm_arg_type.pointer
        end

        # Self is always passed by reference (pointer),
        # even if the type is passed by value (like a struct).
        # In case the body is a Primitive it means it's something like
        # `a = 1; ->a.+(Int32)` in which case we must use a pointer for
        # the first argument (because the closure data is a pointer).
        if i == 0 && !is_fun_literal && self_type.passed_as_self? && (self_type.passed_by_value? || (is_primitive && arg_type.is_a?(PrimitiveType)))
          llvm_arg_type = llvm_arg_type.pointer
        end
      end
      llvm_arg_type
    end

    llvm_return_type = {% if LibLLVM::IS_LT_150 %}
                         llvm_return_type(target_def.type)
                       {% else %}
                         target_def.llvm_intrinsic? ? llvm_intrinsic_return_type(target_def.type) : llvm_return_type(target_def.type)
                       {% end %}

    if is_closure
      llvm_args_types.insert(0, llvm_context.void_pointer)
      offset = 1
    else
      offset = 0
    end

    setup_context_fun(mangled_name, target_def, llvm_args_types, llvm_return_type)

    if @debug.variables?
      context.fun_debug_params.clear
      if context.fun
        context.add_fun_debug_param(get_debug_type(target_def.type))
        args.each do |arg|
          context.add_fun_debug_param(get_debug_type(arg.type))
        end
      end
    end

    if @single_module && !target_def.no_inline? && !target_def.is_a?(External)
      context.fun.linkage = LLVM::Linkage::Internal
    end

    args.each_with_index do |arg, i|
      param = context.fun.params[i + offset]
      param.name = arg.name
    end

    args
  end

  def codegen_fun_signature_external(mangled_name, target_def)
    args = target_def.args.dup

    # This is the case where we declared a fun that was not used and now we
    # are defining its body.
    if existing_fun = typed_fun?(@llvm_mod, mangled_name)
      context.fun = existing_fun.func
      context.fun_type = existing_fun.type
      return args
    end

    offset = 0

    abi_info = abi_info(target_def)

    llvm_args_types = Array(LLVM::Type).new(abi_info.arg_types.size)
    abi_info.arg_types.each do |arg_type|
      case arg_type.kind
      in .direct?
        llvm_args_types << (arg_type.cast || arg_type.type)
      in .indirect?
        llvm_args_types << arg_type.type.pointer
      in .ignore?
        # ignore
      end
    end

    ret_type = abi_info.return_type
    llvm_return_type =
      case ret_type.kind
      in .direct?
        ret_type.cast || ret_type.type
      in .indirect?
        offset += 1
        llvm_args_types.insert 0, ret_type.type.pointer
        llvm_context.void
      in .ignore?
        llvm_context.void
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
        context.fun.add_attribute(attr, i + offset + 1, abi_arg_type.type)
      end

      i += 1 unless abi_arg_type.kind == LLVM::ABI::ArgKind::Ignore
    end

    # This is for sret
    if (attr = abi_info.return_type.attr) && attr == LLVM::Attribute::StructRet
      context.fun.add_attribute(attr, 1, abi_info.return_type.type)
    end

    args
  end

  def abi_info(external : Def)
    external.abi_info = true

    llvm_args_types = external.args.map { |arg| llvm_c_type(arg.type) }
    llvm_return_type = llvm_c_return_type(external.type)
    @abi.abi_info(llvm_args_types, llvm_return_type, !llvm_return_type.void?, llvm_context)
  end

  def abi_info(external : Def, node : Call)
    llvm_args_types = node.args.map_with_index do |arg, i|
      llvm_c_type((external.args[i]? || arg).type)
    end
    llvm_return_type = llvm_c_return_type(external.type)
    @abi.abi_info(llvm_args_types, llvm_return_type, !llvm_return_type.void?, llvm_context)
  end

  def setup_context_fun(mangled_name, target_def, llvm_args_types, llvm_return_type) : Nil
    fun_type = LLVM::Type.function(llvm_args_types, llvm_return_type, target_def.varargs?)
    typed_fun = add_typed_fun(@llvm_mod, mangled_name, fun_type)
    context.fun = typed_fun.func
    context.fun_type = typed_fun.type

    if @debug.variables?
      context.fun.add_attribute LLVM::Attribute::NoInline
      context.fun.add_attribute LLVM::Attribute::OptimizeNone
    else
      context.fun.add_attribute LLVM::Attribute::AlwaysInline if target_def.always_inline?
    end
    context.fun.add_attribute LLVM::Attribute::ReturnsTwice if target_def.returns_twice?
    context.fun.add_attribute LLVM::Attribute::Naked if target_def.naked?
    context.fun.add_attribute LLVM::Attribute::NoReturn if target_def.no_returns?

    if target_def.no_inline?
      context.fun.add_attribute LLVM::Attribute::NoInline
      context.fun.linkage = LLVM::Linkage::External
    end
  end

  def setup_closure_vars(def_vars, closure_vars, context, closure_type, closure_ptr)
    if context.closure_skip_parent
      parent_context = context.closure_parent_context.not_nil!
      setup_closure_vars(def_vars, parent_context.closure_vars.not_nil!, parent_context, closure_type, closure_ptr)
    else
      closure_vars.each_with_index do |var, i|
        # A closured var in this context might have the same name as
        # a local var in another context, for example if the local var
        # was defined before the closured var. In this case, don't
        # consider the local var as closured.
        def_var = def_vars.try &.[var.name]?
        next if def_var && !def_var.closured?

        self.context.vars[var.name] = LLVMVar.new(gep(closure_type, closure_ptr, 0, i, var.name), var.type)
      end

      if (closure_parent_context = context.closure_parent_context) &&
         (parent_vars = closure_parent_context.closure_vars)
        parent_closure_type = llvm_typer.copy_type(closure_parent_context.closure_type.not_nil!)
        parent_closure_ptr = gep(closure_type, closure_ptr, 0, closure_vars.size, "parent_ptr")
        parent_closure = load(parent_closure_type.pointer, parent_closure_ptr, "parent")
        setup_closure_vars(def_vars, parent_vars, closure_parent_context, parent_closure_type, parent_closure)
      elsif closure_self = context.closure_self
        offset = context.closure_parent_context ? 1 : 0
        self_value = gep(closure_type, closure_ptr, 0, closure_vars.size + offset, "self")
        self_value = load(llvm_type(closure_self), self_value) unless context.type.passed_by_value?
        self.context.vars["self"] = LLVMVar.new(self_value, closure_self, true)
      end
    end
  end

  def create_local_copy_of_fun_args(target_def, self_type, args, is_fun_literal, is_closure)
    offset = is_closure ? 1 : 0

    abi_info = target_def.abi_info? ? abi_info(target_def) : nil
    sret = abi_info && sret?(abi_info)
    offset += 1 if sret

    target_def_vars = target_def.vars
    args.each_with_index do |arg, i|
      param = context.fun.params[i + offset]
      if !is_fun_literal && (i == 0 && self_type.passed_as_self?)
        # here self is already in context.vars
      else
        create_local_copy_of_arg(target_def, target_def_vars, arg, param, i + offset)
      end
    end
  end

  def create_local_copy_of_block_self(self_type, call_args)
    args_base_index = 0
    if self_type.passed_as_self?
      context.vars["self"] = LLVMVar.new(call_args[0], self_type, true)
      args_base_index = 1
    end
    args_base_index
  end

  def create_local_copy_of_block_args(target_def, self_type, call_args, args_base_index)
    target_def.args.each_with_index do |arg, i|
      create_local_copy_of_arg(target_def, target_def.vars, arg, call_args[args_base_index + i], args_base_index + i)
    end
  end

  def create_local_copy_of_arg(target_def, target_def_vars, arg, value, index)
    # An argument name can be "_" in the case of a captured block,
    # and we must ignore these
    return if arg.name == "_"

    target_def_var = target_def_vars.try &.[arg.name]
    location = target_def_var.try(&.location) || target_def.location

    var_type = (target_def_var || arg).type
    return if var_type.void?

    if closure_var = context.vars[arg.name]?
      pointer = closure_var.pointer

      if arg.type.passed_by_value?
        # Create an alloca and store it there, so assign works well
        pointer2 = alloca(llvm_type(arg.type))
        store value, pointer2
        value = pointer2
      end
    else
      abi_info = target_def.abi_info? ? abi_info(target_def) : nil
      sret = abi_info && sret?(abi_info)

      # If it's an extern struct on a def that must be codegened with C ABI
      # compatibility, and it's not passed byval, we must cast the value
      if target_def.c_calling_convention? && arg.type.extern? && !context.fun.attributes(index + 1).by_val?
        # ... unless it's passed indirectly (ie. as a pointer to memory allocated by the caller)
        if abi_info.try &.arg_types[index - (sret ? 1 : 0)].kind.indirect?
          value = declare_debug_for_function_argument(arg.name, var_type, index + 1, value, location) unless target_def.naked?
          context.vars[arg.name] = LLVMVar.new(value, var_type)
        else
          pointer = alloca(llvm_type(var_type), arg.name)
          casted_pointer = pointer_cast pointer, value.type.pointer
          store value, casted_pointer
          pointer = declare_debug_for_function_argument(arg.name, var_type, index + 1, pointer, location) unless target_def.naked?
          context.vars[arg.name] = LLVMVar.new(pointer, var_type)
        end
        return
      elsif arg.special_var?
        value = declare_debug_for_function_argument(arg.name, var_type, index + 1, value, location) unless target_def.naked?
        context.vars[arg.name] = LLVMVar.new(value, var_type)
        return
      else
        # If an argument is a Proc inside a C function, we need to cast it to Proc
        fun_proc = var_type.is_a?(ProcInstanceType) && target_def.is_a?(External)

        # We don't need to create a copy of the argument if it's never
        # assigned a value inside the function.
        needs_copy = target_def_var.try &.assigned_to?
        needs_copy ||= fun_proc

        if needs_copy
          pointer = alloca(llvm_type(var_type), arg.name)
          pointer = declare_debug_for_function_argument(arg.name, var_type, index + 1, pointer, location) unless target_def.naked?

          if fun_proc
            fun_ptr = cast_to_void_pointer(value)
            value = make_fun(var_type, fun_ptr, llvm_context.void_pointer.null)
          end

          context.vars[arg.name] = LLVMVar.new(pointer, var_type)

          if arg.type.passed_by_value? && !context.fun.attributes(index + 1).by_val?
            # Create an alloca and store it there, so assign works well
            pointer2 = alloca(llvm_type(arg.type))
            store value, pointer2
            value = pointer2
          end
        else
          if arg.type.passed_by_value? && !context.fun.attributes(index + 1).by_val?
            # For pass-by-value we create an alloca so the value
            # is behind a pointer, as everywhere else
            pointer = alloca(llvm_type(var_type), arg.name)
            store value, pointer
            pointer = declare_debug_for_function_argument(arg.name, var_type, index + 1, pointer, location) unless target_def.naked?
            context.vars[arg.name] = LLVMVar.new(pointer, var_type)
            return
          else
            value = declare_debug_for_function_argument(arg.name, var_type, index + 1, value, location) unless target_def.naked?
            context.vars[arg.name] = LLVMVar.new(value, var_type, true)
            return
          end
        end
      end
    end

    assign pointer, var_type, arg.type, value
  end

  def type_module(type)
    return @main_module_info if @single_module

    @types_to_modules[type] ||= begin
      type = type.remove_typedef
      case type
      when Nil, Program, LibType
        type_name = ""
      else
        type_name = type.instance_type.to_s
      end

      @modules[type_name] ||= begin
        llvm_context = LLVM::Context.new
        # LLVM::Context.register(llvm_context, type_name)

        llvm_typer = LLVMTyper.new(@program, llvm_context)
        llvm_mod = configure_module(llvm_context.new_module(type_name))
        llvm_builder = new_builder(llvm_context)

        define_symbol_table llvm_mod, llvm_typer
        ModuleInfo.new(llvm_mod, llvm_typer, llvm_builder)
      end
    end
  end
end
