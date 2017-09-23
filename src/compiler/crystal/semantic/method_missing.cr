require "../types"

module Crystal
  class Type
    ONE_ARG = [Arg.new("a1")]

    def check_method_missing(signature, call)
      if !metaclass? && signature.name != "initialize"
        # Make sure to define method missing in the whole hierarchy
        virtual_type = virtual_type()
        if virtual_type == self
          method_missing = lookup_method_missing
          if method_missing
            define_method_from_method_missing(method_missing, signature, call)
            return true
          end
        else
          return virtual_type.check_method_missing(signature, call)
        end
      end

      false
    end

    def lookup_method_missing
      a_macro = lookup_macro("method_missing", ONE_ARG, nil)
      a_macro.is_a?(Macro) ? a_macro : nil
    end

    def define_method_from_method_missing(method_missing, signature, original_call)
      name_node = StringLiteral.new(signature.name)
      args_nodes = [] of ASTNode
      named_args_nodes = nil
      args_nodes_names = Set(String).new
      signature.arg_types.each_index do |index|
        arg_node_name = "_arg#{index}"
        args_nodes << MacroId.new(arg_node_name)
        args_nodes_names << arg_node_name
      end
      if named_args = signature.named_args
        args_nodes_names << ""
        named_args.each do |named_arg|
          named_args_nodes ||= [] of NamedArgument
          named_args_nodes << NamedArgument.new(named_arg.name, MacroId.new(named_arg.name))
          args_nodes_names << named_arg.name
        end
      end
      if block = signature.block
        block_vars = block.args.map_with_index do |var, index|
          Var.new("_block_arg#{index}")
        end
        yield_exps = block_vars.map { |var| var.clone.as(ASTNode) }
        block_body = Yield.new(yield_exps)
        block_node = Block.new(block_vars, block_body)
      else
        block_node = Nop.new
      end

      a_def = Def.new(signature.name, args_nodes_names.map { |name| Arg.new(name) })
      a_def.splat_index = signature.arg_types.size if signature.named_args

      call = Call.new(nil, signature.name,
        args: args_nodes,
        named_args: named_args_nodes,
        block: block_node.is_a?(Block) ? block_node : nil)
      fake_call = Call.new(nil, "method_missing", [call] of ASTNode)

      expanded_macro = program.expand_macro method_missing, fake_call, self, self

      # Check if the expanded macro is a def. We do this
      # by just lexing the result and seeing if the first
      # token is `def`
      expands_to_def = starts_with_def?(expanded_macro)
      generated_nodes =
        program.parse_macro_source(expanded_macro, method_missing, method_missing, args_nodes_names) do |parser|
          if expands_to_def
            parser.parse
          else
            parser.parse_to_def(a_def)
          end
        end

      if generated_nodes.is_a?(Def)
        a_def = generated_nodes
      else
        if expands_to_def
          raise_wrong_method_missing_expansion(
            "it should only expand to a single def",
            expanded_macro,
            original_call)
        end

        a_def.body = generated_nodes
        a_def.yields = block.try &.args.size
      end

      owner = self
      owner = owner.base_type if owner.is_a?(VirtualType)

      return false unless owner.is_a?(ModuleType)

      owner.add_def(a_def)

      # If it expanded to a def, we check if the def
      # is now found by regular lookup. It should!
      # Otherwise there's a mistake in the macro.
      if expands_to_def && owner.lookup_matches(signature).empty?
        raise_wrong_method_missing_expansion(
          "the generated method won't be found by the original call invocation",
          expanded_macro,
          original_call)
      end

      true
    end

    private def raise_wrong_method_missing_expansion(msg, expanded_macro, original_call)
      str = String.build do |io|
        io << "wrong method_missing expansion\n\n"
        io << "The method_missing macro expanded to:\n\n"
        io << Crystal.with_line_numbers(expanded_macro)
        io << "\n\n"
        io << "However, " << msg
      end
      original_call.raise str
    end
  end

  class GenericInstanceType
    delegate check_method_missing, to: @generic_type
  end

  class VirtualType
    def check_method_missing(signature, call)
      method_missing = base_type.lookup_method_missing
      defined = false
      if method_missing
        defined = base_type.define_method_from_method_missing(method_missing, signature, call) || defined
      end

      defined = add_subclasses_method_missing_matches(base_type, method_missing, signature, call) || defined
      defined
    end

    def add_subclasses_method_missing_matches(base_type, method_missing, signature, call)
      defined = false

      base_type.subclasses.each do |subclass|
        next unless subclass.is_a?(ModuleType)

        # First check if we can find the method
        existing_def = subclass.lookup_first_def(signature.name, signature.block)
        next if existing_def

        subclass_method_missing = subclass.lookup_method_missing

        # Check if the subclass redefined the method_missing
        if subclass_method_missing && subclass_method_missing.object_id != method_missing.object_id
          subclass.define_method_from_method_missing(subclass_method_missing, signature, call)
          defined = true
        elsif method_missing
          # Otherwise, we need to define this method missing because of macro vars like @name
          subclass.define_method_from_method_missing(method_missing, signature, call)
          subclass_method_missing = method_missing
          defined = true
        end

        defined = add_subclasses_method_missing_matches(subclass, subclass_method_missing, signature, call) || defined
      end

      defined
    end
  end
end

private def starts_with_def?(source)
  lexer = Crystal::Lexer.new(source)
  while true
    token = lexer.next_token
    return true if token.keyword?(:def)
    break if token.type == :EOF
  end
  false
end
