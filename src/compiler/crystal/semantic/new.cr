module Crystal
  class Program
    # This is a recording of a `new` method (expanded) that
    # was created from an `initialize` method (original)
    record NewExpansion, original : Def, expanded : Def

    @new_expansions = [] of NewExpansion
    getter new_expansions

    def define_new_methods
      # Here we complete the body of `self.new` methods
      # created from `initialize` methods.
      @new_expansions.each do |expansion|
        expansion.expanded.fill_body_from_initialize(expansion.original.owner)
      end

      # We also need to define empty `new` methods for types
      # that don't have any `initialize` methods.
      define_default_new(@program)
    end

    def define_default_new(type)
      return if type.is_a?(AliasType) || type.is_a?(TypeDefType)

      type.types?.try &.each_value do |type|
        define_default_new_single(type)
      end
    end

    def define_default_new_single(type)
      check = case type
              when self.object, self.value, self.number, self.int, self.float,
                   self.struct, self.enum, self.tuple, self.proc
                false
              when NonGenericClassType, GenericClassType
                true
              end

      if check
        self_initialize_methods = type.lookup_defs_without_parents("initialize")

        # Check to see if a default `new` needs to be defined
        initialize_methods = type.lookup_defs("initialize", lookup_ancestors_for_new: true)
        has_new_or_initialize = !initialize_methods.empty?
        if !has_new_or_initialize
          new_methods = type.metaclass.lookup_defs("new", lookup_ancestors_for_new: true)
          has_new_or_initialize = !new_methods.empty?
        end

        if !has_new_or_initialize
          # Add self.new
          new_method = Def.argless_new(type)
          type.metaclass.add_def(new_method)

          # Also add `initialize`, so `super` in a subclass
          # inside an `initialize` will find this one
          type.add_def Def.argless_initialize
        end

        # Check to see if a type doesn't define `initialize`
        # nor `self.new` on its own. In this case, when we
        # search a `new` method and we can't find it in this
        # type we must search in the superclass. We record
        # this information here instead of having to do this
        # check every time.
        has_self_initialize_methods = !self_initialize_methods.empty?
        if !has_self_initialize_methods
          if type.is_a?(GenericClassType) || type.ancestors.any?(&.is_a?(InheritedGenericClass))
            # For a generic class type we need to define `new` even
            # if a superclass defines it, because the generated new
            # uses, for example, Foo(T) to match free vars, and here
            # we might need Bar(T) with Bar(T) < Foo(T).
            # (we can probably improve this in the future)
            if initialize_methods.empty?
              type.metaclass.add_def(Def.argless_new(type))
              type.add_def(Def.argless_initialize)
            else
              initialize_methods.each do |initialize|
                new_method = initialize.expand_new_from_initialize(type)
                type.metaclass.add_def(new_method)
              end
            end
          else
            type.lookup_new_in_ancestors = true
          end
        end
      end

      define_default_new(type)
    end
  end

  class Def
    def expand_new_from_initialize(instance_type)
      new_def = expand_new_signature_from_initialize(instance_type)
      new_def.fill_body_from_initialize(instance_type)
      new_def
    end

    def expand_new_signature_from_initialize(instance_type)
      def_args = args.clone

      new_def = Def.new("new", def_args, Nop.new)
      new_def.splat_index = splat_index
      new_def.yields = yields
      new_def.visibility = Visibility::Private if visibility.private?

      # Forward block argument if any
      if uses_block_arg
        block_arg = block_arg.not_nil!
        new_def.block_arg = block_arg.clone
        new_def.uses_block_arg = true
      end

      new_def
    end

    def fill_body_from_initialize(instance_type)
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
      exps << init
      exps << Call.new(Path.global("GC"), "add_finalizer", var) if instance_type.has_finalizer?
      exps << var

      # Forward block argument if any
      if uses_block_arg
        block_arg = block_arg.not_nil!
        init.block_arg = Var.new(block_arg.name)
      end

      self.body = Expressions.from(exps)
    end

    def self.argless_new(instance_type)
      # This creates:
      #
      #    def new
      #      x = allocate
      #      GC.add_finalizer x
      #      x
      #    end
      var = Var.new("x")
      alloc = Call.new(nil, "allocate")
      assign = Assign.new(var, alloc)

      exps = Array(ASTNode).new(3)
      exps << assign
      exps << Call.new(Path.global("GC"), "add_finalizer", var) if instance_type.has_finalizer?
      exps << var

      Def.new("new", body: exps)
    end

    def self.argless_initialize
      Def.new("initialize", body: Nop.new)
    end
  end
end
