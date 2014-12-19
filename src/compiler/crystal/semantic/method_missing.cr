require "../types"

module Crystal
  class Type
    def check_method_missing(signature)
      false
    end

    def lookup_method_missing
      # method_missing is actually stored in the metaclass
      method_missing = metaclass.lookup_macro("method_missing", 3, nil)
      return method_missing if method_missing

      parents.try &.each do |parent|
        method_missing = parent.lookup_method_missing
        return method_missing if method_missing
      end

      nil
    end
  end

  module MatchesLookup
    def check_method_missing(signature)
      if !metaclass? && signature.name != "initialize"
        # Make sure to define method missing in the whole hierarchy
        virtual_type = virtual_type()
        if virtual_type == self
          method_missing = lookup_method_missing
          if method_missing
            define_method_from_method_missing(method_missing, signature)
            return true
          end
        else
          return virtual_type.check_method_missing(signature)
        end
      end

      false
    end

    def define_method_from_method_missing(method_missing, signature)
      name_node = StringLiteral.new(signature.name)
      args_nodes = [] of ASTNode
      args_nodes_names = Set(String).new
      signature.arg_types.each_index do |index|
        arg_node_name = "_arg#{index}"
        args_nodes << MacroId.new(arg_node_name)
        args_nodes_names << arg_node_name
      end
      args_node = ArrayLiteral.new(args_nodes)
      if block = signature.block
        block_vars = block.args.map_with_index do |var, index|
          Var.new("_block_arg#{index}")
        end
        yield_exps = block_vars.map { |var| var.clone as ASTNode }
        block_body = Yield.new(yield_exps)
        block_node = Block.new(block_vars, block_body)
      else
        block_node = Nop.new
      end

      a_def = Def.new(signature.name, args_nodes_names.map { |name| Arg.new(name) })

      fake_call = Call.new(nil, "method_missing", [name_node, args_node, block_node] of ASTNode)
      expanded_macro = program.expand_macro self, method_missing, fake_call
      generated_nodes = program.parse_macro_source(expanded_macro, method_missing, method_missing, args_nodes_names) do |parser|
        parser.parse_to_def(a_def)
      end

      a_def.body = generated_nodes
      a_def.yields = block.try &.args.length

      owner = self
      owner = owner.base_type if owner.is_a?(VirtualType)
      owner.add_def(a_def) if owner.is_a?(DefContainer)
    end
  end

  class GenericClassInstanceType
    delegate check_method_missing, @generic_class
  end

  class VirtualType
    def check_method_missing(signature)
      method_missing = base_type.lookup_method_missing
      defined = false
      if method_missing
        defined = base_type.define_method_from_method_missing(method_missing, signature) || defined
      end

      defined = add_subclasses_method_missing_matches(base_type, method_missing, signature) || defined
      defined
    end

    def add_subclasses_method_missing_matches(base_type, method_missing, signature)
      defined = false

      base_type.subclasses.each do |subclass|
        next unless subclass.is_a?(DefContainer)

        # First check if we can find the method
        existing_def = subclass.lookup_first_def(signature.name, signature.block)
        next if existing_def

        subclass_method_missing = subclass.lookup_method_missing

        # Check if the subclass redefined the method_missing
        if subclass_method_missing && subclass_method_missing.object_id != method_missing.object_id
          subclass.define_method_from_method_missing(subclass_method_missing, signature)
          defined = true
        elsif method_missing
          # Otherwise, we need to define this method missing because of macro vars like @name
          subclass.define_method_from_method_missing(method_missing, signature)
          subclass_method_missing = method_missing
          defined = true
        end

        defined = add_subclasses_method_missing_matches(subclass, subclass_method_missing, signature) || defined
      end

      defined
    end
  end
end
