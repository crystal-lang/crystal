module Crystal
  class MacroExpander
    def initialize(@mod, @untyped_def)
      @macro_name = "#macro_#{untyped_def.object_id}"
      @typed_def = Def.new(@macro_name, untyped_def.args.map(&.clone), untyped_def.body.clone)
      @llvm_mod = LLVM::Module.new @macro_name
      @engine = LLVM::JITCompiler.new @llvm_mod
    end

    def expand(node)
      # macro_call = Call.new(nil, @macro_name, args.map(&:to_crystal_node))
      macro_call = Call.new(nil, @macro_name)
      macro_nodes = Expressions.new([@typed_def, macro_call] of ASTNode)
      macro_nodes = @mod.normalize(macro_nodes)

      @mod.infer_type macro_nodes

      if macro_nodes.type != @mod.string
        node.raise "macro return value must be a String, not #{macro_nodes.type}"
      end

      macro_arg_types = macro_call.args.map(&.type)
      func = @untyped_def.lookup_instance(macro_arg_types)
      unless func
        @mod.build macro_nodes, @llvm_mod#, single_module: true
        func = @llvm_mod.functions[macro_call.target_def.mangled_name(nil)]?
        if func
          @untyped_def.add_instance func, macro_arg_types
        end
      end

      # @mod.load_libs

      if func
        # macro_args = args.map &:to_crystal_binary
        macro_value = @engine.run_function func#, *macro_args
      else
        macro_value = @engine.run_function @llvm_mod.functions[MAIN_NAME]#, 0, nil
      end

      macro_value.to_string
    end
  end
end
