module Crystal
  LLVMDebugVersion = (12 << 16)

  class CodeGenVisitor < Visitor
    def add_compile_unit_metadata(mod, file)
      return unless @subprograms[mod]?
      LibLLVM.add_named_metadata_operand mod, "llvm.dbg.cu", metadata([
        LLVMDebugVersion + 17,                   # Tag = 17 (DW_TAG_compile_unit)
        file_metadata(file),                     # Source directory (including trailing slash) & file pair
        100,                                     # DWARF language identifier (ex. DW_LANG_C89)
        "Crystal",                               # Producer
        false,                                   # True if this is optimized
        "",                                      # Flags
        0,                                       # Runtime version
        @empty_md_list,                          # List of enums types
        @empty_md_list,                          # List of retained types
        metadata(@subprograms[mod]),                  # List of subprograms
        @empty_md_list,                          # List of global variables
        @empty_md_list,                          # List of imported entities
        ""                                       # Split debug filename
      ])
    end

    def fun_metadatas
      @fun_metadatas ||= {} of LLVM::Function => LibLLVM::ValueRef
    end

    def fun_metadata(a_fun, name, file, line)
      return nil unless file && line

      fun_metadatas[a_fun] = begin
        metadata([
          46 + LLVMDebugVersion,        # Tag
          file_metadata(file),          # Source directory (including trailing slash) & file pair
          file_descriptor(file),        # Reference to context descriptor
          name,                         # Name
          name,                         # Display name
          a_fun.name,                     # MIPS linkage name (for C++)
          line,                         # Line number
          fun_type,                     # Reference to type descriptor
          false,                        # True if the global is local to compile unit (static)
          true,                         # True if the global is defined in the compile unit (not extern)
          0,                            # Virtuality, e.g. dwarf::DW_VIRTUALITY__virtual
          0,                            # Index into a virtual function
          nil,                          # Type that holds virtual table.
          0,                            # Flags
          false,                        # True if this function is optimized
          a_fun,                          # Pointer to llvm::Function
          nil,                          # Lists function template parameters
          nil,                          # Function declaration descriptor
          @empty_md_list,               # List of function variables
          line                          # Line number where the scope of the subprogram begins
        ])
      end
    end

    def fun_type
      # TODO: fill with something meaningful
      metadata([
        786453, 0, "", 0, 0, 0, 0, 0, 0, nil, metadata([metadata([
          786468, nil, "int", nil, 0, 32, 32, 0, 0, 5
        ])]), 0, 0
      ])
    end

    def def_metadata(a_fun, crystal_def)
      location = crystal_def.location
      return unless location

      fun_metadata(a_fun, crystal_def.name, location.filename, location.line_number)
    end

    def file_descriptor(file)
      file ||= ""
      @file_descriptor ||= {} of String | VirtualFile => LibLLVM::ValueRef
      @file_descriptor.not_nil![file] ||= metadata([
        41 + LLVMDebugVersion,                # Tag
        file_metadata(file)
      ])
    end

    def file_metadata(file)
      file ||= ""

      @file_metadata ||= {} of String | VirtualFile => LibLLVM::ValueRef
      @file_metadata.not_nil![file] ||= begin
        realfile = case file
          when String then file
          when VirtualFile
            Dir.mkdir_p(".crystal")
            File.write(".crystal/macro#{file.object_id}.cr", file.source)
            ".crystal/macro#{file.object_id}.cr"
          else
            raise "Unknown file type: #{file}"
          end
        metadata([
          File.basename(realfile),                  # File
          File.dirname(realfile)                    # Directory
        ])
      end
    end

    def lexical_block_metadata(a_fun, node)
      location = node ? node.location : nil
      metadata([
        11 + LLVMDebugVersion,                  # Tag
        fun_metadatas[a_fun],
        location ? location.line_number : 0,
        location ? location.column_number : 0,
        location ? file_descriptor(location.filename) : nil,
        0
      ])
    end

    def dbg_metadata(node)
      location = node.location
      return unless location
      fun_md = fun_metadatas[context.fun]?
      return unless fun_md

      metadata([
        location.line_number || 1,
        location.column_number,
        # lexical_block_metadata(context.fun, node),
        fun_md,
        nil
      ])
    end

    def type_metadata(type)
      @type_metadata ||= {} of Type => LibLLVM::ValueRef
      @type_metadata[type] ||= begin
        if type.integer?
          base_type(type.name, type.bits, type.signed? ? 5 : 7)
        elsif type == @mod.bool
          base_type(type.name, 8, 2)
        end
      end
    end

    def base_type(name, bits, encoding)
      metadata([
            36 + LLVMDebugVersion,      # Tag = 36 (DW_TAG_base_type)
            nil,                        # Source directory (including trailing slash) & file pair (may be null)
            nil,                        # Reference to context
            name,                       # Name (may be "" for anonymous types)
            0,                          # Line number where defined (may be 0)
            bits,                       # Size in bits
            bits,                       # Alignment in bits
            0,                          # Offset in bits
            0,                          # Flags
            encoding                    # DWARF type encoding
          ])
    end

    def local_var_metadata(var)
      metadata([
        256 + LLVMDebugVersion,      # Tag (see below)
        @fun_metadatas[context.fun],        # Context
        var.name,                    # Name
        nil,                         # Reference to file where defined
        0,                           # 24 bit - Line number where defined
                                     # 8 bit - Argument number. 1 indicates 1st argument.
        type_metadata(var.type),     # Type descriptor
        0,                           # flags
        0                            # (optional) Reference to inline location
      ])
    end

    def metadata args
      values = args.map do |value|
        case value
        when String then LibLLVM.md_string(value, value.length)
        when Symbol then LibLLVM.md_string(value.to_s, value.to_s.length)
        when Number then int32(value)
        when Bool then int1(value ? 1 : 0)
        when LibLLVM::ValueRef then value
        when LLVM::Function then value.unwrap
        when Nil then Pointer(Void).null as LibLLVM::ValueRef
        else raise "Unsuported value type"
        end
      end
      LibLLVM.md_node(values, values.length)
    end

    def dbg_declare
      @dbg_declare ||= begin
        metadata_type = metadata.type # HACK get metadata type from LLVM
        llvm_mod.functions.add("llvm.dbg.declare", [metadata_type, metadata_type], LLVM::Void)
      end
    end

    def emit_debug_metadata(node, value)
      # if value.is_a?(LibLLVM::ValueRef) && !LLVM.constant?(value) && !value.is_a?(LibLLVM::BasicBlockRef)
        if md = dbg_metadata(node)
          LibLLVM.set_metadata(value, @dbg_kind, md) rescue nil
        end
      # end
    end

    def emit_def_debug_metadata(target_def)
      unless target_def.name == MAIN_NAME
        if def_md = def_metadata(context.fun, target_def)
          @subprograms[@llvm_mod] ||= [] of LibLLVM::ValueRef?
          @subprograms[@llvm_mod] << def_md
        end
      end
    end
  end
end
