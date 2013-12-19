module Crystal
  class MacroExpander
    def initialize(@mod, @untyped_def)
      @macro_name = "~~macro_#{untyped_def.name}"
    end

    def expand(node)
      mapped_args = node.args.map do |arg|
        if arg.is_a?(Call) && !arg.obj && !arg.block && !arg.block_arg && arg.args.length == 0
          Var.new(arg.name)
        else
          arg
        end
      end

      macro_arg_types = mapped_args.map &.crystal_type_id
      info = @untyped_def.lookup_instance(macro_arg_types)
      unless info
        typed_def = Def.new(@macro_name, @untyped_def.args.map(&.clone), @untyped_def.body.clone)
        typed_def = @mod.normalize(typed_def)
        assert_type typed_def, Def

        vars = {} of String => Var
        typed_def.args.zip(mapped_args) do |def_arg, macro_arg|
          arg_type = lookup_node_type(macro_arg)
          def_arg.set_type(arg_type)

          var = Var.new(def_arg.name, arg_type)
          var.bind_to(var)
          vars[def_arg.name] = var
        end

        visitor = TypeVisitor.new(@mod, vars)
        typed_def.bind_to typed_def.body
        typed_def.body.accept visitor

        if typed_def.type != @mod.string
          node.raise "macro return value must be a String, not #{typed_def.type}"
        end

        llvm_mod = LLVM::Module.new @macro_name
        engine = LLVM::JITCompiler.new llvm_mod

        visitor = CodeGenVisitor.new(@mod, typed_def, llvm_mod, true, true)
        visitor.codegen_fun(@macro_name, typed_def, nil)

        # llvm_mod.dump

        func = llvm_mod.functions[@macro_name]?
        info = Macro::Info.new(llvm_mod, engine, func)
        @untyped_def.add_instance info, macro_arg_types
      end

      @mod.load_libs

      func = info.func

      if func
        macro_args = mapped_args.map do |arg|
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
