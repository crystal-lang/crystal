require "./codegen"

module Crystal
  class CodeGenVisitor
    CRYSTAL_LANG_DEBUG_IDENTIFIER = 0x28_u32
    #
    # We have to use it because LLDB has builtin type system support for C++/clang that we can use for now for free.
    # Later on we can implement LLDB Crystal type system so we can get official Language ID
    #
    CPP_LANG_DEBUG_IDENTIFIER = 0x0004_u32

    record FunMetadata, filename : String, metadata : LibLLVMExt::Metadata

    @current_debug_location : Location?
    @debug_files = {} of Crystal::VirtualFile | String? => LibLLVMExt::Metadata
    @current_debug_file : LibLLVMExt::Metadata?

    def di_builder(llvm_module = @llvm_mod || @main_mod)
      di_builders = @di_builders ||= {} of LLVM::Module => LLVM::DIBuilder
      di_builders[llvm_module] ||= LLVM::DIBuilder.new(llvm_module).tap do |di_builder|
        file, dir = file_and_dir(llvm_module.name == "" ? "main" : llvm_module.name)
        # @debug.variables? is set to true if parameter --debug is set in command line.
        # This flag affects only debug variables generation. It sets Optimized parameter to false.
        is_optimised = !@debug.variables?
        di_builder.create_compile_unit(CPP_LANG_DEBUG_IDENTIFIER, file, dir, "Crystal", is_optimised, "", 0_u32)
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
      @fun_metadatas ||= {} of LLVM::Function => Array(FunMetadata)
    end

    def fun_metadata_type(debug_types = [] of LibLLVMExt::Metadata)
      if debug_types.empty?
        int = di_builder.create_basic_type("int", 32, 32, LLVM::DwarfTypeEncoding::Signed)
        debug_types << int
      end
      debug_types_array = di_builder.get_or_create_type_array(debug_types)
      di_builder.create_subroutine_type(nil, debug_types_array)
    end

    def debug_type_cache
      # We must cache debug types per module so metadata of a type
      # from one module isn't incorrectly used in another module.
      debug_types_per_module =
        @debug_types_per_module ||=
          {} of LLVM::Module => Hash(Type, LibLLVMExt::Metadata?)

      debug_types_per_module[@llvm_mod] ||= {} of Type => LibLLVMExt::Metadata?
    end

    def get_debug_type(type, original_type : Type)
      type = type.remove_indirection
      debug_type_cache[original_type] ||= create_debug_type(type, original_type)
    end

    def create_debug_type(type : NilType, original_type : Type)
      di_builder.create_unspecified_type("decltype(nullptr)")
    end

    def create_debug_type(type : VoidType, original_type : Type)
      di_builder.create_basic_type("Void", 8u64 * llvm_typer.pointer_size, 8u64 * llvm_typer.pointer_size, LLVM::DwarfTypeEncoding::Address)
    end

    def create_debug_type(type : CharType, original_type : Type)
      di_builder.create_basic_type("char32_t", 32, 32, LLVM::DwarfTypeEncoding::Utf)
    end

    def create_debug_type(type : IntegerType, original_type : Type)
      di_builder.create_basic_type(type.to_s, type.bits, type.bits,
        type.signed? ? LLVM::DwarfTypeEncoding::Signed : LLVM::DwarfTypeEncoding::Unsigned)
    end

    def create_debug_type(type : SymbolType, original_type : Type)
      di_builder.create_basic_type(type.to_s, 32, 32, LLVM::DwarfTypeEncoding::Unsigned)
    end

    def create_debug_type(type : FloatType, original_type : Type)
      di_builder.create_basic_type(type.to_s, 8u64 * type.bytes, 8u64 * type.bytes, LLVM::DwarfTypeEncoding::Float)
    end

    def create_debug_type(type : BoolType, original_type : Type)
      di_builder.create_basic_type(type.to_s, 8, 8, LLVM::DwarfTypeEncoding::Boolean)
    end

    def create_debug_type(type : EnumType, original_type : Type)
      elements = type.types.map do |name, item|
        value = if item.is_a?(Const) && (value2 = item.value).is_a?(NumberLiteral)
                  value2.value.to_i64 rescue value2.value.to_u64
                else
                  0
                end
        di_builder.create_enumerator(name, value)
      end
      elements = di_builder.get_or_create_array(elements)
      di_builder.create_enumeration_type(nil, original_type.to_s, nil, 1, 32, 32, elements, get_debug_type(type.base_type))
    end

    def create_debug_type(type : InstanceVarContainer, original_type : Type)
      ivars = type.all_instance_vars
      element_types = [] of LibLLVMExt::Metadata
      struct_type = llvm_struct_type(type)

      tmp_debug_type = di_builder.create_replaceable_composite_type(nil, original_type.to_s, nil, 1, llvm_context)
      debug_type_cache[original_type] = tmp_debug_type

      ivars.each_with_index do |(name, ivar), idx|
        next if ivar.type.is_a?(NilType)
        if (ivar_type = ivar.type?) && (ivar_debug_type = get_debug_type(ivar_type))
          offset = @program.target_machine.data_layout.offset_of_element(struct_type, idx &+ (type.struct? ? 0 : 1))
          size = @program.target_machine.data_layout.size_in_bits(llvm_embedded_type(ivar_type))

          # FIXME structs like LibC::PthreadMutexT generate huge offset values
          next if offset > UInt64::MAX // 8u64

          member = di_builder.create_member_type(nil, name[1..-1], nil, 1, size, size, 8u64 * offset, LLVM::DIFlags::Zero, ivar_debug_type)
          element_types << member
        end
      end

      size = @program.target_machine.data_layout.size_in_bits(struct_type)
      debug_type = di_builder.create_struct_type(nil, original_type.to_s, nil, 1, size, size, LLVM::DIFlags::Zero, nil, di_builder.get_or_create_type_array(element_types))
      unless type.struct?
        debug_type = di_builder.create_pointer_type(debug_type, 8u64 * llvm_typer.pointer_size, 8u64 * llvm_typer.pointer_size, original_type.to_s)
      end
      di_builder.replace_temporary(tmp_debug_type, debug_type)
      debug_type
    end

    def create_debug_type(type : PointerInstanceType, original_type : Type)
      element_type = get_debug_type(type.element_type)
      return unless element_type
      di_builder.create_pointer_type(element_type, 8u64 * llvm_typer.pointer_size, 8u64 * llvm_typer.pointer_size, original_type.to_s)
    end

    def create_debug_type(type : MixedUnionType, original_type : Type)
      element_types = [] of LibLLVMExt::Metadata
      struct_type = llvm_type(type)
      struct_type_size = @program.target_machine.data_layout.size_in_bits(struct_type)
      is_struct = struct_type.struct_element_types.size == 1

      tmp_debug_type = di_builder.create_replaceable_composite_type(nil, original_type.to_s, nil, 1, llvm_context)
      debug_type_cache[original_type] = tmp_debug_type

      type.expand_union_types.each do |ivar_type|
        next if ivar_type.is_a?(NilType)
        if ivar_debug_type = get_debug_type(ivar_type)
          embedded_type = llvm_type(ivar_type)
          size = @program.target_machine.data_layout.size_in_bits(embedded_type)
          align = llvm_typer.align_of(embedded_type) * 8u64
          member = di_builder.create_member_type(nil, ivar_type.to_s, nil, 1, size, align, 0, LLVM::DIFlags::Zero, ivar_debug_type)
          element_types << member
        end
      end

      size = @program.target_machine.data_layout.size_in_bits(struct_type.struct_element_types[is_struct ? 0 : 1])
      offset = @program.target_machine.data_layout.offset_of_element(struct_type, 1) * 8u64
      debug_type = di_builder.create_union_type(nil, nil, @current_debug_file.not_nil!, 1, size, size, LLVM::DIFlags::Zero, di_builder.get_or_create_type_array(element_types))
      unless is_struct
        element_types.clear
        element_types << di_builder.create_member_type(nil, "type_id", nil, 1, 32, 32, 0, LLVM::DIFlags::Zero, get_debug_type(@program.uint32))
        element_types << di_builder.create_member_type(nil, "union", nil, 1, size, size, offset, LLVM::DIFlags::Zero, debug_type)
        debug_type = di_builder.create_struct_type(nil, original_type.to_s, nil, 1, struct_type_size, struct_type_size, LLVM::DIFlags::Zero, nil, di_builder.get_or_create_type_array(element_types))
      end
      di_builder.replace_temporary(tmp_debug_type, debug_type)
      debug_type
    end

    def create_debug_type(type : NilableReferenceUnionType | ReferenceUnionType, original_type : Type)
      element_types = [] of LibLLVMExt::Metadata
      struct_type = llvm_type(type)
      tmp_debug_type = di_builder.create_replaceable_composite_type(nil, original_type.to_s, nil, 1, llvm_context)
      debug_type_cache[original_type] = tmp_debug_type

      type.expand_union_types.each do |ivar_type|
        next if ivar_type.is_a?(NilType)
        if ivar_debug_type = get_debug_type(ivar_type)
          embedded_type = llvm_type(ivar_type)
          size = @program.target_machine.data_layout.size_in_bits(embedded_type)
          member = di_builder.create_member_type(nil, ivar_type.to_s, nil, 1, size, size, 0, LLVM::DIFlags::Zero, ivar_debug_type)
          element_types << member
        end
      end

      size = @program.target_machine.data_layout.size_in_bits(struct_type)
      debug_type = di_builder.create_union_type(nil, original_type.to_s, @current_debug_file.not_nil!, 1, size, size, LLVM::DIFlags::Zero, di_builder.get_or_create_type_array(element_types))
      di_builder.replace_temporary(tmp_debug_type, debug_type)
      debug_type
    end

    def create_debug_type(type : NilableType, original_type : Type)
      get_debug_type(type.not_nil_type, original_type)
    end

    def create_debug_type(type : NilablePointerType, original_type : Type)
      get_debug_type(type.pointer_type, original_type)
    end

    def create_debug_type(type : StaticArrayInstanceType, original_type : Type)
      debug_type = get_debug_type(type.element_type)
      return unless debug_type
      subrange = di_builder.get_or_create_array_subrange(0, type.size.as(NumberLiteral).value.to_i)
      di_builder.create_array_type(type.size.as(NumberLiteral).value.to_i, llvm_typer.pointer_size, debug_type, [subrange])
    end

    def create_debug_type(type : TypeDefType, original_type : Type)
      get_debug_type(type.typedef, original_type)
    end

    def create_debug_type(type : TupleInstanceType, original_type : Type)
      ivars = type.tuple_types
      element_types = [] of LibLLVMExt::Metadata
      struct_type = llvm_struct_type(type)

      tmp_debug_type = di_builder.create_replaceable_composite_type(nil, original_type.to_s, nil, 1, llvm_context)
      debug_type_cache[original_type] = tmp_debug_type

      ivars.each_with_index do |ivar_type, idx|
        next if ivar_type.is_a?(NilType)
        if ivar_debug_type = get_debug_type(ivar_type)
          offset = @program.target_machine.data_layout.offset_of_element(struct_type, idx &+ (type.struct? ? 0 : 1))
          size = @program.target_machine.data_layout.size_in_bits(llvm_embedded_type(ivar_type))
          next if offset > UInt64::MAX // 8u64 # TODO: Figure out why it is happening sometimes with offset
          member = di_builder.create_member_type(nil, "[#{idx}]", nil, 1, size, size, 8u64 * offset, LLVM::DIFlags::Zero, ivar_debug_type)
          element_types << member
        end
      end

      size = @program.target_machine.data_layout.size_in_bits(struct_type)
      debug_type = di_builder.create_struct_type(nil, original_type.to_s, nil, 1, size, size, LLVM::DIFlags::Zero, nil, di_builder.get_or_create_type_array(element_types))
      unless type.struct?
        debug_type = di_builder.create_pointer_type(debug_type, 8u64 * llvm_typer.pointer_size, 8u64 * llvm_typer.pointer_size, original_type.to_s)
      end
      di_builder.replace_temporary(tmp_debug_type, debug_type)
      debug_type
    end

    def create_debug_type(type : NamedTupleInstanceType, original_type : Type)
      ivars = type.entries
      element_types = [] of LibLLVMExt::Metadata
      struct_type = llvm_struct_type(type)

      tmp_debug_type = di_builder.create_replaceable_composite_type(nil, original_type.to_s, nil, 1, llvm_context)
      debug_type_cache[original_type] = tmp_debug_type

      ivars.each_with_index do |ivar, idx|
        next if (ivar_type = ivar.type).is_a?(NilType)
        if ivar_debug_type = get_debug_type(ivar_type)
          offset = @program.target_machine.data_layout.offset_of_element(struct_type, idx &+ (type.struct? ? 0 : 1))
          size = @program.target_machine.data_layout.size_in_bits(llvm_embedded_type(ivar_type))

          # FIXME structs like LibC::PthreadMutexT generate huge offset values
          next if offset > UInt64::MAX // 8u64

          member = di_builder.create_member_type(nil, ivar.name, nil, 1, size, size, 8u64 * offset, LLVM::DIFlags::Zero, ivar_debug_type)
          element_types << member
        end
      end

      size = @program.target_machine.data_layout.size_in_bits(struct_type)
      debug_type = di_builder.create_struct_type(nil, original_type.to_s, nil, 1, size, size, LLVM::DIFlags::Zero, nil, di_builder.get_or_create_type_array(element_types))
      unless type.struct?
        debug_type = di_builder.create_pointer_type(debug_type, 8u64 * llvm_typer.pointer_size, 8u64 * llvm_typer.pointer_size, original_type.to_s)
      end
      di_builder.replace_temporary(tmp_debug_type, debug_type)
      debug_type
    end

    # This is a sinkhole for debug types that most likely does not need to be implemented
    def create_debug_type(type : NonGenericModuleType | GenericClassInstanceMetaclassType | MetaclassType | NilableProcType | VirtualMetaclassType, original_type : Type)
    end

    def create_debug_type(type, original_type : Type)
      # "Unsupported type for debugging: #{type} (#{type.class}), original_type=#{original_type.to_s}" }
    end

    def get_debug_type(type)
      get_debug_type(type, type)
    end

    def declare_parameter(arg_name, arg_type, arg_no, alloca, location)
      return alloca unless @debug.variables?

      declare_local(arg_type, alloca, location) do |scope, file, line_number, debug_type|
        di_builder.create_parameter_variable scope, arg_name, arg_no, file, line_number, debug_type
      end
    end

    def declare_variable(var_name, var_type, alloca, location, basic_block : LLVM::BasicBlock? = nil)
      return false unless @debug.variables?
      declare_local(var_type, alloca, location, basic_block) do |scope, file, line_number, debug_type|
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

    private def declare_local(type, alloca, location, basic_block : LLVM::BasicBlock? = nil)
      location = location.try &.expanded_location
      return false unless location

      file, dir = file_and_dir(location.filename)
      @current_debug_file = file = @debug_files[location.filename] ||= di_builder.create_file(file, dir)

      debug_type = get_debug_type(type)
      return false unless debug_type

      scope = get_current_debug_scope(location)
      return false unless scope

      var = yield scope, file, location.line_number, debug_type
      expr = di_builder.create_expression(nil, 0)
      if basic_block
        block = basic_block
      else
        block = context.fun.basic_blocks.last? || new_block("alloca")
      end
      old_debug_location = @current_debug_location
      set_current_debug_location location
      if builder.current_debug_location != llvm_nil && (ptr = alloca)
        di_builder.insert_declare_at_end(ptr, var, expr, builder.current_debug_location, block)
        set_current_debug_location old_debug_location
        true
      else
        set_current_debug_location old_debug_location
        false
      end
    end

    # Emit debug info for toplevel variables. Used for the main module and all
    # required files.
    def emit_vars_debug_info(vars)
      return if @debug.none?
      in_alloca_block do
        vars.each do |name, var|
          llvm_var = context.vars[name]
          next if llvm_var.debug_variable_created
          set_current_debug_location var.location
          declare_variable name, var.type, llvm_var.pointer, var.location, alloca_block
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
        else                     raise "Unsupported value type: #{value.class}"
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
        main_scope = main_scopes[{file, dir}] ||= begin
          di_builder = di_builder(@main_mod)
          file = di_builder.create_file(file, dir)
          di_builder.create_lexical_block(fun_metadatas[context.fun][0].metadata, file, 1, 1)
        end
        main_scope
      else
        scope = nil
        if array = fun_metadatas[context.fun]?
          array.each do |scope_pair|
            return scope_pair.metadata if scope_pair.filename == location.filename
          end
          file, dir = file_and_dir(location.filename)
          di_builder = di_builder()
          file_scope = di_builder.create_file(file, dir)
          scope = di_builder.create_lexical_block_file(fun_metadatas[context.fun][0].metadata, file_scope)
          array << FunMetadata.new(location.original_filename || "??", scope)
        end
        scope
      end
    end

    def set_current_debug_location(location)
      location = location.try &.expanded_location
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
      fun_metadatas[main_fun] = [FunMetadata.new(filename || "??", fn_metadata)]
    end

    def emit_def_debug_metadata(target_def)
      location = target_def.location.try &.expanded_location
      return unless location

      file, dir = file_and_dir(location.filename)
      scope = di_builder.create_file(file, dir)
      is_optimised = !@debug.variables?
      fn_metadata = di_builder.create_function(scope, target_def.name, target_def.name, scope,
        location.line_number, fun_metadata_type(context.fun_debug_params), true, true,
        location.line_number, LLVM::DIFlags::Zero, is_optimised, context.fun)
      fun_metadatas[context.fun] = [FunMetadata.new(location.original_filename || "??", fn_metadata)]
    end

    def declare_debug_for_function_argument(arg_name, arg_type, arg_no, alloca, location)
      return alloca unless @debug.variables?
      old_debug_location = @current_debug_location
      set_current_debug_location location
      debug_alloca = alloca alloca.type, "dbg.#{arg_name}"
      store alloca, debug_alloca
      declare_parameter(arg_name, arg_type, arg_no, debug_alloca, location)
      alloca = load debug_alloca
      set_current_debug_location old_debug_location
      alloca
    end
  end
end
