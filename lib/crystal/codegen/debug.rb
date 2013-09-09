module Crystal
  LLVMDebugVersion = (12 << 16)

  class CodeGenVisitor < Visitor
    def add_compile_unit_metadata(file)
      LLVM::C.add_named_metadata_operand @llvm_mod, "llvm.dbg.cu", metadata(
        LLVMDebugVersion + 17,                   # Tag = 17 (DW_TAG_compile_unit)
        file_metadata(file),                     # Source directory (including trailing slash) & file pair
        100,                                     # DWARF language identifier (ex. DW_LANG_C89)
        "Crystal",                               # Producer
        false,                                   # True if this is optimized
        "",                                      # Flags
        0,                                       # Runtime version
        @empty_md_list,                          # List of enums types
        @empty_md_list,                          # List of retained types
        metadata(*@subprograms),                 # List of subprograms
        @empty_md_list,                          # List of global variables
        @empty_md_list,                          # List of imported entities
        @empty_md_list                           # Split debug filename
      )
    end

    def fun_metadata(fun, name, file, line)
      return nil unless file && line
      @fun_metadatas ||= {}
      unless md = @fun_metadatas[fun]
        md = metadata(
          46 + LLVMDebugVersion,        # Tag
          file_metadata(file),          # Source directory (including trailing slash) & file pair
          file_descriptor(file),        # Reference to context descriptor
          name,                         # Name
          name,                         # Display name
          fun.name,                     # MIPS linkage name (for C++)
          line,                         # Line number
          fun_type,                     # Reference to type descriptor
          false,                        # True if the global is local to compile unit (static)
          true,                         # True if the global is defined in the compile unit (not extern)
          0,                            # Virtuality, e.g. dwarf::DW_VIRTUALITY__virtual
          0,                            # Index into a virtual function
          nil,                          # Type that holds virtual table.
          0,                            # Flags
          false,                        # True if this function is optimized
          fun,                          # Pointer to llvm::Function
          nil,                          # Lists function template parameters
          nil,                          # Function declaration descriptor
          @empty_md_list,               # List of function variables
          line                          # Line number where the scope of the subprogram begins
        )
      end
      @fun_metadatas[fun] = md
      md
    end

    def fun_type
      # TODO: fill with something meaningful
      metadata(
        786453, 0, "", 0, 0, 0, 0, 0, 0, nil, metadata(metadata(
          786468, nil, "int", nil, 0, 32, 32, 0, 0, 5
        )), 0, 0
      )
    end

    def def_metadata(fun, crystal_def)
      fun_metadata(fun, crystal_def.name, crystal_def.filename, crystal_def.line_number)
    end

    def file_descriptor(file)
      file ||= ""
      @file_descriptor ||= {}
      @file_descriptor[file] ||= metadata(
        41 + LLVMDebugVersion,                # Tag
        file_metadata(file)
      )
    end

    def file_metadata(file)
      file ||= ""
      @file_metadata ||= {}
      @file_metadata[file] ||= metadata(
        File.basename(file),                  # File
        File.dirname(file)                    # Directory
      )
    end

    def lexical_block_metadata(fun, node)
      metadata(
        11 + LLVMDebugVersion,                  # Tag
        @fun_metadatas[fun],
        node.line_number,
        node.column_number,
        file_descriptor(node.filename),
        0
      )
    end

    def dbg_metadata
      return unless @current_node && @current_node.line_number && @current_node.filename
      metadata(
        @current_node.line_number || 1,
        @current_node.column_number,
        # lexical_block_metadata(@fun, @current_node),
        @fun_metadatas[@fun],
        nil
      )
    end

    def type_metadata(type)
      @type_metadata ||= {}
      @type_metadata[type] ||= begin
        if type.integer?
          base_type(type.name, type.bits, type.signed? ? 5 : 7)
        elsif type == @mod.bool
          base_type(type.name, 8, 2)
        end
      end
    end

    def base_type(name, bits, encoding)
      metadata(
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
          )
    end

    def local_var_metadata(var)
      metadata(
        256 + LLVMDebugVersion,      # Tag (see below)
        @fun_metadatas[@fun],        # Context
        var.name,                    # Name
        nil,                         # Reference to file where defined
        0,                           # 24 bit - Line number where defined
                                     # 8 bit - Argument number. 1 indicates 1st argument.
        type_metadata(var.type),     # Type descriptor
        0,                           # flags
        0                            # (optional) Reference to inline location
      )
    end

    def metadata *values
      values = values.map do |value|
        case value
        when String then LLVM::C.md_string(value, value.length)
        when Symbol then LLVM::C.md_string(value.to_s, value.to_s.length)
        when Numeric then LLVM::Int(value)
        when TrueClass then LLVM::Int.from_i(1)
        when FalseClass then LLVM::Int.from_i(0)
        else value
        end
      end
      pointers = LLVM::Support.allocate_pointers values
      LLVM::Value.from_ptr LLVM::C.md_node(pointers, values.length)
    end

    def dbg_declare
      @dbg_declare ||= begin
        metadata_type = metadata.type # HACK get metadata type from LLVM
        llvm_mod.functions.add("llvm.dbg.declare", [metadata_type, metadata_type], LLVM.Void)
      end
    end
  end
end
