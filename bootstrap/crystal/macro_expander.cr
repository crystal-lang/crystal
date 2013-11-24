module Crystal
  class MacroExpander
    def initialize(@mod, @untyped_def)
      @macro_name = "#macro_#{untyped_def.object_id}"
      @typed_def = Def.new(@macro_name, untyped_def.args.map(&.clone), untyped_def.body.clone)
      @llvm_mod = LLVM::Module.new @macro_name
      @engine = LLVM::JITCompiler.new @llvm_mod
    end

    def expand(node)
      mapped_args = node.args.map do |arg|
        if arg.is_a?(Call) && !arg.obj && !arg.block && !arg.block_arg && arg.args.length == 0
          Var.new(arg.name)
        elsif arg.is_a?(Ident) && arg.names.length == 1
          Var.new(arg.names.first)
        elsif arg.is_a?(SymbolLiteral)
          Var.new(arg.value)
        elsif arg.is_a?(StringLiteral)
          Var.new(arg.value)
        elsif arg.is_a?(Assign)
          arg.value
        else
          arg
        end
      end

      macro_arg_types = mapped_args.map &.crystal_type_id
      func = @untyped_def.lookup_instance(macro_arg_types)
      unless func
        args = Array(ASTNode).new(mapped_args.length)
        mapped_args.each do |arg|
          args.push arg.to_crystal_node.not_nil!
        end

        macro_call = Call.new(nil, @macro_name, args)
        macro_nodes = Expressions.new([@typed_def, macro_call] of ASTNode)
        macro_nodes = @mod.normalize(macro_nodes)

        @mod.infer_type macro_nodes

        if macro_nodes.type != @mod.string
          node.raise "macro return value must be a String, not #{macro_nodes.type}"
        end

        @mod.build macro_nodes, true, @llvm_mod
        func = @llvm_mod.functions[macro_call.target_def.mangled_name(nil)]?
        if func
          @untyped_def.add_instance func, macro_arg_types
        end
      end

      # TODO
      # @mod.load_libs

      if func
        macro_args = mapped_args.map do |arg|
          pointer = Pointer(Void).new(arg.object_id)
          LibLLVM.create_generic_value_of_pointer(pointer)
        end
        macro_value = @engine.run_function func, macro_args
      else
        argc = LibLLVM.create_generic_value_of_int(LLVM::Int32, 0_u64, 1)
        argv = LibLLVM.create_generic_value_of_pointer(nil)
        macro_value = @engine.run_function @llvm_mod.functions[MAIN_NAME], [argc, argv]
      end

      macro_value.to_string
    end
  end
end
