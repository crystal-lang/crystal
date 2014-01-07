module Crystal
  class MacroExpander
    SLOW = ENV["SLOW_MACROS"] == "1"

    def initialize(@mod, @untyped_def)
      @macro_name = "~~macro_#{untyped_def.name}"
    end

    def expand(node)
      body = @untyped_def.body

      # A simple case: when the macro is just a string interpolation with variables,
      # we do it without a JIT
      if body.is_a?(StringInterpolation)
        if body.expressions.all? { |exp| exp.is_a?(StringLiteral) || exp.is_a?(Var) }
          return String.build do |str|
            body.expressions.each do |exp|
              case exp
              when StringLiteral
                str << exp.value
              when Var
                index = @untyped_def.args.index { |arg| arg.name == exp.name }.not_nil!
                str << node.args[index].to_s
              end
            end
          end
        end
      end

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

      macro_args = mapped_args.map &.to_crystal_macro_node

      macro_arg_types = mapped_args.map &.crystal_type_id
      info = @untyped_def.lookup_instance(macro_arg_types)
      if SLOW || !info
        args = Array(ASTNode).new(mapped_args.length)
        mapped_args.each do |arg|
          args.push arg.to_crystal_node.not_nil!
        end

        typed_def = Def.new(@macro_name, @untyped_def.args.map(&.clone), @untyped_def.body.clone)

        macro_call = Call.new(nil, @macro_name, args)
        macro_nodes = Expressions.new([typed_def, macro_call] of ASTNode)
        macro_nodes = @mod.normalize(macro_nodes)

        @mod.infer_type macro_nodes

        if macro_nodes.type != @mod.string
          node.raise "macro return value must be a String, not #{typed_def.type}"
        end

        llvm_mod = LLVM::Module.new @macro_name
        engine = LLVM::JITCompiler.new llvm_mod

        @mod.build macro_nodes, true, llvm_mod

        # llvm_mod.dump

        func = llvm_mod.functions[macro_call.target_def.mangled_name(nil)]?

        info = Macro::Info.new(llvm_mod, engine, func)
        @untyped_def.add_instance info, macro_arg_types
      end

      @mod.load_libs

      info = info.not_nil!
      func = info.func

      if func && !SLOW
        macro_args = macro_args.map do |arg|
          pointer = Pointer(Void).new(arg.object_id)
          LibLLVM.create_generic_value_of_pointer(pointer)
        end
        macro_value = info.engine.run_function func, macro_args
      else
        argc = LibLLVM.create_generic_value_of_int(LLVM::Int32, 0_u64, 1)
        argv = LibLLVM.create_generic_value_of_pointer(nil)
        macro_value = info.engine.run_function info.llvm_mod.functions[MAIN_NAME], [argc, argv]
      end

      macro_value.to_string
    end

    def lookup_node_type(node)
      @mod.types["Crystal"].types[node.class_name]
    end
  end
end
