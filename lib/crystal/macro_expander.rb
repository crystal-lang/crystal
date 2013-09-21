module Crystal
  class MacroExpander
    def initialize(mod, untyped_def)
      @mod = mod
      @untyped_def = untyped_def
      @macro_name = "#macro_#{untyped_def.object_id}"
      @typed_def = Def.new(@macro_name, untyped_def.args.map(&:clone), untyped_def.body ? untyped_def.body.clone : nil)
      @llvm_mod = LLVM::Module.new @macro_name
      @engine = LLVM::JITCompiler.new @llvm_mod
    end

    def expand(node)
      args = node.args.map do |arg|
        if arg.is_a?(Call) && !arg.obj && !arg.block && !arg.block_arg && arg.args.length == 0
          Var.new(arg.name)
        else
          arg
        end
      end

      macro_call = Call.new(nil, @macro_name, args.map(&:to_crystal_node))
      macro_nodes = Expressions.new [@typed_def, macro_call]
      macro_nodes = @mod.normalize(macro_nodes)

      @mod.infer_type macro_nodes

      if macro_nodes.type != @mod.string
        node.raise "macro return value must be a String, not #{macro_nodes.type}"
      end

      macro_arg_types = macro_call.args.map(&:type)
      fun = @untyped_def.lookup_instance(macro_arg_types)
      unless fun
        @mod.build macro_nodes, nil, false, @llvm_mod
        fun = @llvm_mod.functions[macro_call.target_def.mangled_name(nil)]
        @untyped_def.add_instance fun, macro_arg_types
      end

      @mod.load_libs

      macro_args = args.map &:to_crystal_binary
      macro_value = @engine.run_function fun, *macro_args

      macro_value.to_string
    end

    def number_lines(source)
      source.lines.to_s_with_line_numbers
    end

  end
end
