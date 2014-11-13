module Crystal
  class Call
    def define_new(scope, arg_types)
      instance_type = scope.instance_type
      if instance_type.abstract
        raise "can't instantiate abstract class #{scope}"
      end

      original_instance_type = instance_type

      if instance_type.is_a?(VirtualType)
        matches = define_new_recursive(instance_type.base_type, arg_types)
        return Matches.new(matches, scope)
      end

      # First check if this type has any initialize
      initializers = instance_type.lookup_defs_with_modules("initialize")

      # Go up the type hierarchy until we find the first "initialize" defined
      while initializers.empty?
        instance_type = instance_type.superclass
        if instance_type
          initializers = instance_type.lookup_defs_with_modules("initialize")
        else
          if arg_types.empty?
            initializers = [] of Def
            instance_type = original_instance_type
            break
          else
            # This will always raise, but we reuse the error message from this method
            return define_new_without_initialize original_instance_type, arg_types
          end
        end
      end

      signature = CallSignature.new("initialize", arg_types, block, named_args)

      if initializers.empty?
        # If there are no initialize at all, use parent's initialize
        matches = instance_type.lookup_matches signature
      else
        # Otherwise, use this type's initializers
        matches = instance_type.lookup_matches_with_modules signature
        if matches.empty?
          raise_matches_not_found original_instance_type, "initialize", matches
        end
      end

      if matches.empty?
        # We first need to check if there aren't any "new" methods in the class
        defs = scope.lookup_defs("new")
        if defs.any? { |a_def| a_def.args.length > 0 }
          Matches.new(nil, false)
        else
          define_new_without_initialize(scope, arg_types)
        end
      elsif matches.cover_all?
        define_new_with_initialize(scope, arg_types, matches)
      else
        raise_matches_not_found original_instance_type, "initialize", matches
      end
    end

    def define_new_without_initialize(scope, arg_types)
      defs = scope.instance_type.lookup_defs("initialize")
      if defs.length > 0
        raise_matches_not_found scope.instance_type, "initialize"
      end

      if defs.length == 0 && arg_types.length > 0
        raise "wrong number of arguments for '#{full_name(scope.instance_type)}' (#{self.args.length} for 0)"
      end

      new_def = Def.argless_new(scope.instance_type)
      match = Match.new(new_def, arg_types, MatchContext.new(scope, scope))
      scope.add_def new_def

      Matches.new([match], true)
    end

    def define_new_with_initialize(scope, arg_types, matches)
      instance_type = scope.instance_type
      instance_type = instance_type.generic_class if instance_type.is_a?(GenericClassInstanceType)

      ms = matches.map do |match|
        # Check that this call doesn't have a named arg not mentioned in new
        if named_args = @named_args
          check_named_args_mismatch named_args, match.def
        end

        new_def = match.def.expand_new_from_initialize(instance_type)
        new_match = Match.new(new_def, match.arg_types, MatchContext.new(scope, scope, match.context.free_vars))
        scope.add_def new_def

        new_match
      end
      Matches.new(ms, true)
    end

    def define_new_recursive(owner, arg_types, matches = [] of Match)
      unless owner.abstract
        owner_matches = define_new(owner.metaclass, arg_types)
        owner_matches_matches = owner_matches.matches
        if owner_matches_matches
          matches.concat owner_matches_matches
        end
      end

      owner.subclasses.each do |subclass|
        subclass_matches = define_new_recursive(subclass, arg_types)
        matches.concat subclass_matches
      end

      matches
    end
  end

  class Def
    def expand_new_from_initialize(instance_type)
      if instance_type.is_a?(GenericClassType)
        generic_type_args = instance_type.type_vars.map { |type_var| Path.new(type_var) as ASTNode }
        new_generic = Generic.new(Path.new(instance_type.name), generic_type_args)
        alloc = Call.new(new_generic, "allocate")
      else
        alloc = Call.new(nil, "allocate")
      end

      # This creates:
      #
      #    x = allocate
      #    GC.add_finalizer x
      #    x.initialize ..., &block
      #    x
      var = Var.new("_")
      new_vars = args.map { |arg| Var.new(arg.name) as ASTNode }

      if splat_index = self.splat_index
        new_vars[splat_index] = Splat.new(new_vars[splat_index])
      end

      assign = Assign.new(var, alloc)
      call_gc = Call.new(Path.global("GC"), "add_finalizer", var)
      init = Call.new(var, "initialize", new_vars)

      # If the initialize yields, call it with a block
      # that yields those arguments.
      if block_args_count = self.yields
        block_args = Array.new(block_args_count) { |i| Var.new("_arg#{i}") }
        vars = Array.new(block_args_count) { |i| Var.new("_arg#{i}") as ASTNode }
        init.block = Block.new(block_args, Yield.new(vars))
      end

      exps = Array(ASTNode).new(4)
      exps << assign
      exps << call_gc unless instance_type.struct?
      exps << init
      exps << var

      def_args = args.clone

      new_def = Def.new("new", def_args, exps)
      new_def.splat_index = splat_index
      new_def.yields = yields

      # Forward block argument if any
      if uses_block_arg
        block_arg = block_arg.not_nil!
        init.block_arg = Var.new(block_arg.name)
        new_def.block_arg = block_arg.clone
        new_def.uses_block_arg = true
      end

      new_def
    end

    def self.argless_new(instance_type)
      # This creates:
      #
      #    x = allocate
      #    GC.add_finalizer x
      #    x
      var = Var.new("x")
      alloc = Call.new(nil, "allocate")
      assign = Assign.new(var, alloc)
      call_gc = Call.new(Path.global("GC"), "add_finalizer", var)

      exps = Array(ASTNode).new(3)
      exps << assign
      exps << call_gc unless instance_type.struct?
      exps << var

      Def.new("new", body: exps)
    end
  end
end
