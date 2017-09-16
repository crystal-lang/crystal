require "./codegen"

module Crystal
  class CodeGenVisitor
    CRYSTAL_LANG_DEBUG_IDENTIFIER = 0x8002_u32

    @current_debug_location : Location?

    def di_builder(llvm_module = @llvm_mod || @main_mod)
      di_builders = @di_builders ||= {} of LLVM::Module => LLVM::DIBuilder
      di_builders[llvm_module] ||= LLVM::DIBuilder.new(llvm_module).tap do |di_builder|
        file, dir = file_and_dir(llvm_module.name == "" ? "main" : llvm_module.name)
        di_builder.create_compile_unit(CRYSTAL_LANG_DEBUG_IDENTIFIER, file, dir, "Crystal", 0, "", 0_u32)
      end
    end

    def push_debug_info_metadata(mod)
      di_builder(mod).end

      # DebugInfo generation in LLVM by default uses a higher version of dwarf
      # than OS X currently understands. Android has the same problem.
      if @program.has_flag?("osx") || @program.has_flag?("android")
        mod.add_named_metadata_operand("llvm.module.flags",
          metadata([LLVM::ModuleFlag::Warning.value, "Dwarf Version", 2]))
      end

      mod.add_named_metadata_operand("llvm.module.flags",
        metadata([LLVM::ModuleFlag::Warning.value, "Debug Info Version", LLVM::DEBUG_METADATA_VERSION]))
    end

    def fun_metadatas
      @fun_metadatas ||= {} of LLVM::Function => LibLLVMExt::Metadata
    end

    def fun_metadata_type
      int = di_builder.create_basic_type("int", 32, 32, LLVM::DwarfTypeEncoding::Signed)
      int1 = di_builder.get_or_create_type_array([int])
      di_builder.create_subroutine_type(nil, int1)
    end

    def debug_type_cache
      # We must cache debug types per module so metadata of a type
      # from one module isn't incorrectly used in another module.
      debug_types_per_module =
        @debug_types_per_module ||=
          {} of LLVM::Module => Hash(Type, LibLLVMExt::Metadata?)

      debug_types_per_module[@llvm_mod] ||= {} of Type => LibLLVMExt::Metadata?
    end

    def get_debug_type(type)
      type = type.remove_indirection
      debug_type_cache[type] ||= create_debug_type(type)
    end

    def create_debug_type(type : CharType)
      # The name "char32_t" is used so lldb and gdb recognizes this type
      di_builder.create_basic_type("char32_t", 32, 32, LLVM::DwarfTypeEncoding::Utf)
    end

    def create_debug_type(type : IntegerType)
      di_builder.create_basic_type(type.to_s, type.bits, type.bits,
        type.signed? ? LLVM::DwarfTypeEncoding::Signed : LLVM::DwarfTypeEncoding::Unsigned)
    end

    def create_debug_type(type : FloatType)
      di_builder.create_basic_type(type.to_s, type.bytes * 8, type.bytes * 8, LLVM::DwarfTypeEncoding::Float)
    end

    def create_debug_type(type : BoolType)
      di_builder.create_basic_type(type.to_s, 8, 8, LLVM::DwarfTypeEncoding::Boolean)
    end

    def create_debug_type(type : EnumType)
      elements = type.types.map do |name, item|
        value = if item.is_a?(Const) && (value2 = item.value).is_a?(NumberLiteral)
                  value2.value.to_i64 rescue value2.value.to_u64
                else
                  0
                end
        di_builder.create_enumerator(name, value)
      end
      elements = di_builder.get_or_create_array(elements)
      di_builder.create_enumeration_type(nil, type.to_s, nil, 1, 32, 32, elements, get_debug_type(type.base_type))
    end

    def create_debug_type(type : NonGenericModuleType)
      # puts "Unsupported type for debugging: #{type} (#{type.class})"
    end

    def create_debug_type(type : InstanceVarContainer)
      ivars = type.all_instance_vars
      element_types = [] of LibLLVMExt::Metadata
      struct_type = llvm_struct_type(type)

      tmp_debug_type = di_builder.create_replaceable_composite_type(nil, type.to_s, nil, 1, llvm_context)
      debug_type_cache[type] = tmp_debug_type

      ivars.each_with_index do |(name, ivar), idx|
        if (ivar_type = ivar.type?) && (ivar_debug_type = get_debug_type(ivar_type))
          offset = @program.target_machine.data_layout.offset_of_element(struct_type, idx + (type.struct? ? 0 : 1))
          size = @program.target_machine.data_layout.size_in_bits(llvm_embedded_type(ivar_type))
          member = di_builder.create_member_type(nil, name[1..-1], nil, 1, size, size, offset * 8, LLVM::DIFlags::Zero, ivar_debug_type)
          element_types << member
        end
      end

      size = @program.target_machine.data_layout.size_in_bits(struct_type)
      debug_type = di_builder.create_struct_type(nil, type.to_s, nil, 1, size, size, LLVM::DIFlags::Zero, nil, di_builder.get_or_create_type_array(element_types))
      unless type.struct?
        debug_type = di_builder.create_pointer_type(debug_type, llvm_typer.pointer_size * 8, llvm_typer.pointer_size * 8, type.to_s)
      end
      di_builder.replace_temporary(tmp_debug_type, debug_type)
      debug_type
    end

    def create_debug_type(type : PointerInstanceType)
      element_type = get_debug_type(type.element_type)
      return unless element_type
      di_builder.create_pointer_type(element_type, llvm_typer.pointer_size * 8, llvm_typer.pointer_size * 8, type.to_s)
    end

    def create_debug_type(type : StaticArrayInstanceType)
      # puts "Unsupported type for debugging: #{type} (#{type.class})"
    end

    def create_debug_type(type)
      # puts "Unsupported type for debugging: #{type} (#{type.class})"
    end

    def declare_parameter(arg_name, arg_type, arg_no, alloca, location)
      declare_local(arg_type, alloca, location) do |scope, file, line_number, debug_type|
        di_builder.create_parameter_variable scope, arg_name, arg_no, file, line_number, debug_type
      end
    end

    def declare_variable(var_name, var_type, alloca, location)
      declare_local(var_type, alloca, location) do |scope, file, line_number, debug_type|
        di_builder.create_auto_variable scope, var_name, file, line_number, debug_type, align_of(var_type)
      end
    end

    private def align_of(type)
      case type
      when CharType    then 32
      when IntegerType then type.bits
      when FloatType   then type.bytes * 8
      when BoolType    then 8
      else                  0 # unsupported
      end
    end

    private def declare_local(type, alloca, location)
      location = location.try &.original_location
      return unless location

      debug_type = get_debug_type(type)
      return unless debug_type

      scope = get_current_debug_scope(location)
      return unless scope

      file, dir = file_and_dir(location.filename)
      file = di_builder.create_file(file, dir)

      var = yield scope, file, location.line_number, debug_type
      expr = di_builder.create_expression(nil, 0)

      di_builder.insert_declare_at_end(alloca, var, expr, builder.current_debug_location, alloca_block)
    end

    # Emit debug info for toplevel variables. Used for the main module and all
    # required files.
    def emit_vars_debug_info(vars)
      in_alloca_block do
        vars.each do |name, var|
          llvm_var = context.vars[name]
          set_current_debug_location var.location
          declare_variable name, var.type, llvm_var.pointer, var.location
        end
        clear_current_debug_location
      end
    end

    def file_and_dir(filename)
      # We should have expanded locations with VirtualFiles in them to
      # the location where they expanded. Debug locations will point
      # to the single line where the macro was expanded. This is not
      # convenient for debugging macro code, but the other solution
      # involves creating temporary files to hold the expanded macro
      # code, but that prevents reusing previous compilations. In
      # any case, macro code *should* be simple so that it doesn't
      # need to be debugged at runtime (because macros work at compile-time.)
      unless filename.is_a?(String)
        raise "BUG: expected debug filename to be a String, not #{filename.class}"
      end

      {
        File.basename(filename), # File
        File.dirname(filename),  # Directory
      }
    end

    def metadata(args)
      values = args.map do |value|
        case value
        when String         then llvm_context.md_string(value.to_s)
        when Symbol         then llvm_context.md_string(value.to_s)
        when Number         then int32(value)
        when Bool           then int1(value ? 1 : 0)
        when LLVM::Value    then value
        when LLVM::Function then value.to_value
        when Nil            then LLVM::Value.null
        else                     raise "Unsuported value type: #{value.class}"
        end
      end
      llvm_context.md_node(values)
    end

    def set_current_debug_location(node : ASTNode)
      location = node.location
      if location
        set_current_debug_location(location)
      else
        clear_current_debug_location
      end
    end

    def get_current_debug_scope(location)
      if context.fun.name == MAIN_NAME
        main_scopes = (@main_scopes ||= {} of {String, String} => LibLLVMExt::Metadata)
        file, dir = file_and_dir(location.filename)
        main_scopes[{file, dir}] ||= begin
          di_builder = di_builder(@main_mod)
          file = di_builder.create_file(file, dir)
          di_builder.create_lexical_block(fun_metadatas[context.fun], file, 1, 1)
        end
      else
        fun_metadatas[context.fun]?
      end
    end

    def set_current_debug_location(location)
      location = location.try &.original_location
      return unless location

      @current_debug_location = location

      scope = get_current_debug_scope(location)

      if scope
        builder.set_current_debug_location(location.line_number || 1, location.column_number, scope)
      else
        clear_current_debug_location
      end
    end

    def clear_current_debug_location
      @current_debug_location = nil

      builder.set_current_debug_location(0, 0, nil)
    end

    def emit_main_def_debug_metadata(main_fun, filename)
      file, dir = file_and_dir(filename)
      scope = di_builder.create_file(file, dir)
      fn_metadata = di_builder.create_function(scope, MAIN_NAME, MAIN_NAME, scope,
        0, fun_metadata_type, true, true, 0, LLVM::DIFlags::Zero, false, main_fun)
      fun_metadatas[main_fun] = fn_metadata
    end

    def emit_def_debug_metadata(target_def)
      location = target_def.location.try &.original_location
      return unless location

      file, dir = file_and_dir(location.filename)
      scope = di_builder.create_file(file, dir)
      fn_metadata = di_builder.create_function(scope, target_def.name, target_def.name, scope,
        location.line_number, fun_metadata_type, true, true,
        location.line_number, LLVM::DIFlags::Zero, false, context.fun)
      fun_metadatas[context.fun] = fn_metadata
    end
  end
end
