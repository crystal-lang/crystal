module Crystal
  LLVMDebugVersion = (12 << 16)

  class CodeGenVisitor < Visitor
    def add_compile_unit_metadata(file)
      LLVM::C.add_named_metadata_operand @llvm_mod, "llvm.dbg.cu", metadata(
        LLVMDebugVersion + 17,                   # Tag = 17 + LLVMDebugVersion (DW_TAG_compile_unit)
        0,                                       # Unused field
        100,                                     # DWARF language identifier
        File.basename(file),                     # Source file name
        File.dirname(file),                      # Source file directory
        "Crystal",                               # Producer
        true,                                    # True if this is a main compile unit
        false,                                   # True if this is optimized
        "",                                      # Flags
        0,                                       # Runtime version
        @empty_md_list,                          # List of enums types
        @empty_md_list,                          # List of retained types
        metadata(metadata(*@subprograms)),       # List of subprograms
        @empty_md_list,                          # List of global variables
      )
    end

    def fun_metadata(fun, name, file, line)
      @fun_metadatas ||= {}
      unless md = @fun_metadatas[fun]
        md = metadata(
          46 + LLVMDebugVersion,        # Tag
          0,                            # Unused
          file_metadata(file),          # Context
          name,                         # Name
          name,                         # Display name
          fun.name,                     # Linkage name
          file_metadata(file),          # File
          line,                         # Line number
          fun_type,                            # Type
          false,                        # Is local
          true,                         # Is definition
          0,                            # Virtuality attribute, e.g. pure virtual function
          0,                            # Index into virtual table for C++ methods
          nil,                          # Type that holds virtual table.
          0,                            # Flags
          false,                        # True if this function is optimized
          fun                           # Pointer to llvm::Function
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

    def file_metadata(file)
      file ||= ""
      @file_metadata ||= {}
      @file_metadata[file] ||= metadata(
        41 + LLVMDebugVersion,                # Tag
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
        file_metadata(node.filename),
        0
      )
    end

    def dbg_metadata
      return unless @current_node && @current_node.line_number && @current_node.filename
      metadata(
        @current_node.line_number,
        @current_node.column_number,
        lexical_block_metadata(@fun, @current_node),
        nil
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
  end
end