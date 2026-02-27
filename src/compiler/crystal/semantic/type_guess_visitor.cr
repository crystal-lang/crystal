require "./semantic_visitor"

module Crystal
  # Guess the type of class and instance variables
  # from assignments to them.
  class TypeGuessVisitor < SemanticVisitor
    alias TypeDeclarationWithLocation = TypeDeclarationProcessor::TypeDeclarationWithLocation
    alias InitializeInfo = TypeDeclarationProcessor::InitializeInfo
    alias InstanceVarTypeInfo = TypeDeclarationProcessor::InstanceVarTypeInfo
    alias Error = TypeDeclarationProcessor::Error

    getter class_vars
    getter initialize_infos
    getter errors

    class TypeInfo
      property type
      property outside_def
      getter location

      def initialize(@type : Type, @location : Location)
        @outside_def = false
      end
    end

    @args : Array(Arg)?
    @block_arg : Arg?
    @splat_index : Int32?
    @double_splat : Arg?
    @splat : Arg?

    @args_hash_initialized = true
    @args_hash = {} of String => Arg

    # Before checking types, we set this to nil.
    # Afterwards, this is non-nil if an error was found
    # (a type like Class or Reference is used)
    @error : Error?

    @type_override : Type?

    # We increment this when we start searching types inside another
    # type that's not the current type we are guessing vars for.
    # See more comments in `lookup_type?` below.
    @dont_find_root_generic_type_parameters = 0

    def initialize(mod,
                   @explicit_instance_vars : Hash(Type, Hash(String, TypeDeclarationWithLocation)),
                   @guessed_instance_vars : Hash(Type, Hash(String, InstanceVarTypeInfo)),
                   @initialize_infos : Hash(Type, Array(InitializeInfo)),
                   @instance_vars_outside : Hash(Type, Array(String)),
                   @errors : Hash(Type, Hash(String, Error)))
      super(mod)

      @class_vars = {} of ClassVarContainer => Hash(String, TypeInfo)

      # Was `self` access found? If so, instance variables assigned after it
      # don't go to an InitializeInfo (they are considered as not being assigned
      # in that initialize)
      @found_self = false
      @has_self_visitor = HasSelfVisitor.new

      # This is to prevent infinite resolution of constants, like in
      #
      # ```
      # A = B
      # B = A
      # $x = A
      # ```
      @consts = [] of Const

      # Methods being checked for a type guess. We must remember
      # them to avoid infinite recursive lookup
      @methods_being_checked = [] of Def

      @outside_def = true
      @inside_class_method = false
    end

    def visit(node : Var)
      # Check for an argument that matches this var, and see
      # if it has a default value. If so, we do a `self` check
      # to make sure `self` isn't used
      if (arg = args_hash[node.name]?) && (default_value = arg.default_value)
        check_has_self(default_value)
      end

      check_var_is_self(node)
      false
    end

    def visit(node : UninitializedVar)
      var = node.var
      if var.is_a?(InstanceVar)
        if @inside_class_method
          node.raise "@instance_vars are not yet allowed in metaclasses: use @@class_vars instead"
        end

        @error = nil

        add_to_initialize_info(var.name)

        case owner = current_type
        when NonGenericClassType
          process_uninitialized_instance_var(owner, var, node.declared_type)
        when Program, FileModule
          # Nothing
        when NonGenericModuleType
          process_uninitialized_instance_var(owner, var, node.declared_type)
        when GenericClassType
          process_uninitialized_instance_var(owner, var, node.declared_type)
        when GenericModuleType
          process_uninitialized_instance_var(owner, var, node.declared_type)
        else
          # TODO: can this be reached?
        end
      end
      false
    end

    def visit(node : Assign)
      # Invalidate the argument after assigned
      if (target = node.target).is_a?(Var)
        args_hash.delete target.name
      end

      process_assign(node)
      false
    end

    def visit(node : MultiAssign)
      # Invalidate the argument after assigned
      node.targets.each do |target|
        args_hash.delete target.name if target.is_a?(Var)
      end

      process_multi_assign(node)
      false
    end

    def visit(node : Call)
      if @outside_def
        node.scope = node.global? ? @program : current_type.metaclass
        super
      else
        # If it's "self.class", don't consider this as self being passed to a method
        return false if self_dot_class?(node)

        guess_type_call_lib_out(node)
        true
      end
    end

    def guess_type_call_lib_out(node : Call)
      # Check if this call is LibFoo.fun(out @x), and deduce
      # the type from it
      node.args.each_with_index do |arg, index|
        next unless arg.is_a?(Out)

        exp = arg.exp
        next unless exp.is_a?(InstanceVar)

        add_to_initialize_info(exp.name)

        obj = node.obj
        next unless obj.is_a?(Path)

        obj_type = lookup_type?(obj)
        next unless obj_type.is_a?(LibType)

        defs = obj_type.defs.try &.[node.name]?
        # There should be only one, if there is any
        defs.try &.each do |metadata|
          external = metadata.def.as(External)
          fun_def = external.fun_def?
          next unless fun_def

          fun_arg = fun_def.args[index]?
          next unless fun_arg

          type = obj_type.lookup_type?(fun_arg.restriction.not_nil!)
          next unless type.is_a?(PointerInstanceType)

          type = type.element_type

          case owner = current_type
          when NonGenericClassType
            process_lib_out(owner, exp, type)
          when Program, FileModule
            # Nothing
          when NonGenericModuleType
            process_lib_out(owner, exp, type)
          when GenericClassType
            process_lib_out(owner, exp, type)
          when GenericModuleType
            process_lib_out(owner, exp, type)
          else
            # TODO: can this be reached?
          end
        end
      end
    end

    def process_assign(node : Assign)
      process_assign(node.target, node.value)
    end

    def process_assign(target, value)
      check_has_self(value)

      @error = nil

      result =
        case target
        when ClassVar
          process_assign_class_var(target, value)
        when InstanceVar
          if @inside_class_method
            target.raise "@instance_vars are not yet allowed in metaclasses: use @@class_vars instead"
          end

          process_assign_instance_var(target, value)
        when Path
          # Don't guess anything from constant values
          false
        else
          # Process the right hand side in case there's an assignment there too
          value.accept self
          nil
        end

      if error = @error
        errors = @errors[current_type] ||= {} of String => Error
        errors[target.to_s] ||= error
      end

      result
    end

    def process_multi_assign(node : MultiAssign)
      @error = nil

      if node.targets.size == node.values.size
        node.targets.zip(node.values) do |target, value|
          process_assign(target, value)
        end
      else
        node.values.each do |value|
          check_has_self(value)
        end

        node.targets.each do |target|
          if target.is_a?(InstanceVar)
            if @inside_class_method
              target.raise "@instance_vars are not yet allowed in metaclasses: use @@class_vars instead"
            end

            add_to_initialize_info(target.name)
          end
        end

        # If it's something like
        #
        # ```
        # @x, @y = exp
        # ```
        #
        # and we can guess the type of `exp` and it's a tuple type,
        # we can guess the type of @x and @y
        if node.values.size == 1 &&
           node.targets.any? { |t| t.is_a?(InstanceVar) || t.is_a?(ClassVar) || t.is_a?(Global) }
          type = guess_type(node.values.first)
          if type.is_a?(TupleInstanceType) && type.size >= node.targets.size
            node.targets.zip(type.tuple_types) do |target, tuple_type|
              case target
              when InstanceVar
                owner_vars = @guessed_instance_vars[current_type] ||= {} of String => InstanceVarTypeInfo
                add_instance_var_type_info(owner_vars, target.name, tuple_type, target)
              when ClassVar
                owner = class_var_owner(target)

                # If the class variable already exists no need to guess its type
                next if owner.class_vars[target.name]?

                owner_vars = @class_vars[owner] ||= {} of String => TypeInfo
                add_type_info(owner_vars, target.name, tuple_type, target)
              else
                # TODO: can this be reached?
              end
            end
          end
        end
      end
    end

    def process_assign_class_var(target, value)
      owner = class_var_owner(target)

      # If the class variable already exists no need to guess its type
      if var = owner.class_vars[target.name]?
        return var.type
      end

      type = guess_type(value)
      if type
        owner_vars = @class_vars[owner] ||= {} of String => TypeInfo
        add_type_info(owner_vars, target.name, type, target)
      end
      type
    end

    def process_assign_instance_var(target, value)
      case owner = current_type
      when NonGenericClassType
        value = process_assign_instance_var(owner, target, value)
      when Program, FileModule
        # Nothing
      when NonGenericModuleType
        value = process_assign_instance_var(owner, target, value)
      when GenericClassType
        value = process_assign_instance_var(owner, target, value)
      when GenericModuleType
        value = process_assign_instance_var(owner, target, value)
      end

      unless current_type.allows_instance_vars?
        target.raise "can't declare instance variables in #{current_type}"
      end

      add_to_initialize_info(target.name)

      value
    end

    def add_to_initialize_info(name)
      if !@found_self && (initialize_info = @initialize_info)
        vars = initialize_info.instance_vars ||= [] of String
        vars << name unless vars.includes?(name)
      end
    end

    def process_assign_instance_var(owner, target, value)
      if @outside_def
        outside_vars = @instance_vars_outside[owner] ||= [] of String
        outside_vars << target.name unless outside_vars.includes?(target.name)
      end

      # If there is already a type restriction, skip
      existing = @explicit_instance_vars[owner]?.try &.[target.name]?
      if existing
        # Accept the value in case there are assigns there
        value.accept self
        return existing.type.as(Type)
      end

      # For non-generic class we can solve the type now
      type = guess_type(value)
      if type
        owner_vars = @guessed_instance_vars[owner] ||= {} of String => InstanceVarTypeInfo
        add_instance_var_type_info(owner_vars, target.name, type, target)
      end
      type
    end

    def process_uninitialized_instance_var(owner, target, value)
      if @outside_def
        outside_vars = @instance_vars_outside[owner] ||= [] of String
        outside_vars << target.name unless outside_vars.includes?(target.name)
      end

      # If there is already a type restriction, skip
      existing = @explicit_instance_vars[owner]?.try &.[target.name]?
      if existing
        return existing.type.as(Type)
      end

      # For non-generic class we can solve the type now
      type = lookup_type?(value)
      if type
        owner_vars = @guessed_instance_vars[owner] ||= {} of String => InstanceVarTypeInfo
        add_instance_var_type_info(owner_vars, target.name, type, target)
      end
      type
    end

    def process_lib_out(owner, target, type)
      # If there is already a type restriction, skip
      existing = @explicit_instance_vars[owner]?.try &.[target.name]?
      if existing
        return existing.type.as(Type)
      end

      owner_vars = @guessed_instance_vars[owner] ||= {} of String => InstanceVarTypeInfo
      add_instance_var_type_info(owner_vars, target.name, type, target)
    end

    def add_type_info(vars, name, type, node)
      info = vars[name]?
      if info
        info.type = Type.merge!(type, info.type)
      else
        info = TypeInfo.new(type, node.location.not_nil!)
      end
      info.outside_def = true if @outside_def
      vars[name] = info
    end

    def add_instance_var_type_info(vars, name, type : Type, node)
      annotations = nil
      process_annotations(@annotations) do |annotation_type, ann|
        annotations ||= [] of {AnnotationKey, Annotation}
        annotations << {annotation_type, ann}
      end

      info = vars[name]?
      if info
        info.type = Type.merge!(info.type, type)
      else
        info = InstanceVarTypeInfo.new(node.location.not_nil!, type)
      end
      info.outside_def = true if @outside_def
      info.add_annotations(annotations) if annotations
      vars[name] = info
    end

    def guess_type(node : NumberLiteral)
      program.type_from_literal_kind node.kind
    end

    def guess_type(node : CharLiteral)
      program.char
    end

    def guess_type(node : BoolLiteral)
      program.bool
    end

    def guess_type(node : NilLiteral)
      program.nil
    end

    def guess_type(node : StringLiteral)
      program.string
    end

    def guess_type(node : StringInterpolation)
      program.string
    end

    def guess_type(node : SymbolLiteral)
      program.symbol
    end

    def guess_type(node : ArrayLiteral)
      if name = node.name
        type = lookup_type_no_check?(name)
        if type.is_a?(GenericClassType)
          element_types = guess_array_literal_element_types(node)
          if element_types
            return type.instantiate([Type.merge!(element_types)] of TypeVar).virtual_type
          end
        else
          return check_can_be_stored(node, type)
        end
      elsif node_of = node.of
        type = lookup_type?(node_of)
        if type
          return program.array_of(type.virtual_type).virtual_type
        end
      else
        element_types = guess_array_literal_element_types(node)
        if element_types
          return program.array_of(Type.merge!(element_types)).virtual_type
        end
      end

      nil
    end

    def guess_array_literal_element_types(node)
      element_types = nil
      node.elements.each do |element|
        # Splats here require the yield type of `#each`, which we cannot guess
        return nil if element.is_a?(Splat)

        element_type = guess_type(element)
        next unless element_type

        element_types ||= [] of Type
        element_types << element_type
      end
      element_types
    end

    def guess_type(node : HashLiteral)
      if name = node.name
        type = lookup_type_no_check?(name)
        if type.is_a?(GenericClassType)
          key_types, value_types = guess_hash_literal_key_value_types(node)
          if key_types && value_types
            return type.instantiate([Type.merge!(key_types), Type.merge!(value_types)] of TypeVar).virtual_type
          end
        else
          return check_can_be_stored(node, type)
        end
      elsif node_of = node.of
        key_type = lookup_type?(node_of.key)
        return nil unless key_type

        value_type = lookup_type?(node_of.value)
        return nil unless value_type

        return program.hash_of(key_type.virtual_type, value_type.virtual_type).virtual_type
      else
        key_types, value_types = guess_hash_literal_key_value_types(node)
        if key_types && value_types
          return program.hash_of(Type.merge!(key_types), Type.merge!(value_types)).virtual_type
        end
      end

      nil
    end

    def guess_hash_literal_key_value_types(node : HashLiteral)
      key_types = nil
      value_types = nil
      node.entries.each do |entry|
        key_type = guess_type(entry.key)
        if key_type
          key_types ||= [] of Type
          key_types << key_type
        end

        value_type = guess_type(entry.value)
        if value_type
          value_types ||= [] of Type
          value_types << value_type
        end
      end
      {key_types, value_types}
    end

    def guess_type(node : RangeLiteral)
      from_type = guess_type(node.from)
      to_type = guess_type(node.to)

      if from_type && to_type
        program.range_of(from_type, to_type)
      else
        nil
      end
    end

    def guess_type(node : RegexLiteral)
      program.regex
    end

    def guess_type(node : TupleLiteral)
      element_types = nil
      node.elements.each do |element|
        if element.is_a?(Splat)
          element_type = guess_type(element.exp)
          return nil unless element_type.is_a?(TupleInstanceType)

          next if element_type.tuple_types.empty?
          element_types ||= [] of Type
          element_types.concat(element_type.tuple_types)
        else
          element_type = guess_type(element)
          return nil unless element_type

          element_types ||= [] of Type
          element_types << element_type
        end
      end

      if element_types
        program.tuple_of(element_types)
      else
        nil
      end
    end

    def guess_type(node : NamedTupleLiteral)
      entries = nil
      node.entries.each do |entry|
        element_type = guess_type(entry.value)
        return nil unless element_type

        entries ||= [] of NamedArgumentType
        entries << NamedArgumentType.new(entry.key, element_type)
      end

      if entries
        program.named_tuple_of(entries)
      else
        nil
      end
    end

    def guess_type(node : ProcLiteral)
      output = node.def.return_type
      return nil unless output

      types = nil

      node.def.args.each do |input|
        restriction = input.restriction
        return nil unless restriction

        input_type = lookup_type?(restriction)
        return nil unless input_type

        types ||= [] of Type
        types << input_type.virtual_type
      end

      output_type = lookup_type?(output)
      return nil unless output_type

      types ||= [] of Type
      types << output_type.virtual_type

      program.proc_of(types)
    end

    def guess_type(node : Call)
      if expanded = node.expanded
        return guess_type(expanded)
      end

      guess_type_call_lib_out(node)

      obj = node.obj

      # If it's something like T.new, guess T.
      # If it's something like T(X).new, guess T(X).
      if node.name == "new" && obj && (obj.is_a?(Path) || obj.is_a?(Generic))
        type = lookup_type?(obj)
        if type
          # See if the "new" method has a return type annotation, and use it if so
          return_type = guess_type_from_class_method(type, node)
          return return_type if return_type

          # Otherwise, infer it to be T
          return type
        end
      end

      # If it's `new(...)` and this is a non-generic class type, guess it to be that class
      if node.name == "new" && !obj && (
           current_type.is_a?(NonGenericClassType) ||
           current_type.is_a?(PrimitiveType) ||
           current_type.is_a?(GenericClassInstanceType)
         )
        # See if the "new" method has a return type annotation
        return_type = guess_type_from_class_method(current_type, node)
        return return_type if return_type

        # Otherwise, infer it to the current type
        return current_type
      end

      # If it's Pointer(T).malloc or Pointer(T).null, guess it to Pointer(T)
      if obj.is_a?(Generic) &&
         (name = obj.name).is_a?(Path) && name.single?("Pointer") &&
         node.name.in?("malloc", "null")
        type = lookup_type?(obj)
        return type if type.is_a?(PointerInstanceType)
      end

      type = guess_type_call_pointer_malloc_two_args(node)
      return type if type

      type = guess_type_call_lib_fun(node)
      return type if type

      type = guess_type_call_with_type_annotation(node)

      # If the type is unbound (uninstantiated generic) but the call
      # wasn't something like `Gen(Int32).something` then we can never
      # guess a type, the type is probably inferred from type restrictions
      if !obj.is_a?(Generic) && type.try &.unbound?
        return nil
      end

      return type if type

      nil
    end

    # If it's Pointer.malloc(size, value), infer element type from value
    # to T and then infer to Pointer(T)
    def guess_type_call_pointer_malloc_two_args(node)
      obj = node.obj

      if node.args.size == 2 && obj.is_a?(Path) &&
         obj.single?("Pointer") && node.name == "malloc"
        type = lookup_type_no_check?(obj)
        if type.is_a?(PointerType)
          element_type = guess_type(node.args[1])
          if element_type
            return @program.pointer_of(element_type)
          end
        end
      end
      nil
    end

    def guess_type_call_lib_fun(node)
      # If it's LibFoo.function, where LibFoo is a lib type,
      # get the type from there
      obj = node.obj
      return unless obj.is_a?(Path)

      obj_type = lookup_type?(obj)
      return unless obj_type.is_a?(LibType)

      defs = obj_type.defs.try &.[node.name]?
      # There should be only one, if there is any
      defs.try &.each do |metadata|
        external = metadata.def.as(External)
        if def_return_type = external.fun_def?.try &.return_type
          return_type = obj_type.lookup_type(def_return_type)
          return return_type if return_type
        elsif external_type = external.type?
          # This is the case of an External being an external variable
          return external_type
        end
      end
      nil
    end

    # Guess type from T.method, where T is a Path and
    # method solves to a method with a type annotation
    # (use the type annotation)
    def guess_type_call_with_type_annotation(node : Call)
      if node.global?
        return guess_type_from_class_method(@program, node)
      end

      obj = node.obj
      return nil unless obj

      if obj.is_a?(Path) || obj.is_a?(Generic)
        obj_type = lookup_type_no_check?(obj)
        return nil unless obj_type

        return guess_type_from_class_method(obj_type, node)
      end

      obj_type = guess_type(obj)
      return nil unless obj_type

      guess_type_from_method(obj_type, node)
    end

    def guess_type_from_class_method(obj_type, node : Call)
      @dont_find_root_generic_type_parameters += 1 if obj_type != current_type

      type = guess_type_from_class_method_impl(obj_type, node)

      @dont_find_root_generic_type_parameters -= 1 if obj_type != current_type

      type
    end

    def guess_type_from_class_method_impl(obj_type, node : Call)
      metaclass = obj_type.devirtualize.metaclass

      defs = metaclass.lookup_defs(node.name)
      defs = defs.select do |a_def|
        a_def_has_block = !!a_def.block_arity
        call_has_block = !!(node.block || node.block_arg)
        next unless a_def_has_block == call_has_block

        min_size, max_size = a_def.min_max_args_sizes
        min_size <= node.args.size <= max_size
      end

      # If there are no matching defs we can't guess anything
      return if defs.empty?

      # If it's a "new" method without arguments, keep the first one
      # (might happen that a parent new is found here)
      if node.name == "new" && node.args.empty? && !node.named_args && !node.block
        defs = [defs.first]
      end

      # Only use return type if all matching defs have a return type
      if defs.all? &.return_type
        # We can only infer the type if all overloads return
        # the same type (because we can't know the call
        # argument's type)
        return_types = defs.map { |a_def| lookup_type?(a_def.return_type.not_nil!, obj_type) || return nil }.uniq!
        return unless return_types.size == 1

        return return_types[0]
      end

      # If we only have one def, check the body, we might be
      # able to infer something from it if it's sufficiently simple
      return nil unless defs.size == 1

      a_def = defs.first
      body = a_def.body

      # Prevent infinite recursion
      if @methods_being_checked.any? &.same?(a_def)
        return nil
      end

      @methods_being_checked.push a_def

      # Try to guess from the method's body, but now
      # the current lookup type is obj_type
      old_type_override = @type_override
      @type_override = obj_type

      # Wrap everything in Expressions to check for explicit `return`
      exps = Expressions.new([body] of ASTNode)
      type = guess_type_in_method_body(exps)

      @type_override = old_type_override

      @methods_being_checked.pop

      type
    end

    def guess_type_from_method(obj_type, node : Call)
      @dont_find_root_generic_type_parameters += 1 if obj_type != current_type

      type = guess_type_from_method_impl(obj_type, node)

      @dont_find_root_generic_type_parameters -= 1 if obj_type != current_type

      type
    end

    def guess_type_from_method_impl(obj_type, node : Call)
      return nil if node.block || node.block_arg

      arg_types = node.args.map do |arg|
        guessed_arg_type = guess_type(arg)
        return unless guessed_arg_type

        guessed_arg_type
      end

      named_args_types = node.named_args.try(&.map do |named_arg|
        guessed_arg_type = guess_type(named_arg.value)
        return unless guessed_arg_type

        NamedArgumentType.new(named_arg.name, guessed_arg_type)
      end)

      signature = CallSignature.new(
        name: node.name,
        arg_types: arg_types,
        named_args: named_args_types,
        block: nil,
      )
      matches = obj_type.lookup_matches(signature).matches
      return nil unless matches

      return_types = matches.compact_map do |match|
        return_type = match.def.return_type
        next unless return_type

        lookup_type?(return_type, match.context.defining_type, match.context.instantiated_type.instance_type)
      end

      return nil if return_types.empty?

      Type.merge(return_types)
    end

    def guess_type(node : Cast)
      to = node.to

      # Check for exp.as(typeof(something))
      #
      # In this case we can use the same rules for `something`.
      # This is specially useful for the playground and other tools
      # that will rewrite code.
      if to.is_a?(TypeOf) && to.expressions.size == 1
        exp = to.expressions.first
        return guess_type(exp)
      end

      lookup_type?(to)
    end

    def guess_type(node : NilableCast)
      type = lookup_type?(node.to)
      type ? @program.nilable(type) : nil
    end

    def guess_type(node : UninitializedVar)
      lookup_type?(node.declared_type)
    end

    def guess_type(node : Var)
      if node.name == "self"
        if current_type.is_a?(NonGenericClassType)
          return current_type.virtual_type
        else
          return nil
        end
      end

      if arg = args_hash[node.name]?
        # If the argument has a restriction, guess the type from it
        if restriction = arg.restriction
          # It is for something like `def foo(*@foo : *T)`.
          if @splat.same?(arg)
            # If restriction is not splat (like `*foo : T`),
            # we cannot guess the type.
            # (We can also guess `Indexable(T)`, but it is not perfect.)
            # And this early return is no problem because splat argument
            # cannot have a default value.
            return unless restriction.is_a?(Splat)
            restriction = restriction.exp
            # It is for something like `def foo(**@foo : **T)`.
          elsif @double_splat.same?(arg)
            return unless restriction.is_a?(DoubleSplat)
            restriction = restriction.exp
          end
          type = lookup_type?(restriction)
          return type if type
        end

        # If the argument has a default value, guess the type from it
        if default_value = arg.default_value
          return guess_type(default_value)
        end

        # If the node points block args and there's no restriction,
        # it means it's a `-> Void` proc
        if (block_arg = @block_arg) && block_arg.name == node.name
          return @program.proc_of([@program.void] of Type)
        end
      end

      nil
    end

    def guess_type(node : InstanceVar)
      # In an assignment like @x = @y, we use the info gathered so far for @y
      type_decl = @explicit_instance_vars[current_type]?.try &.[node.name]?
      if (type = type_decl.try &.type).is_a?(Type)
        return type
      end

      info = @guessed_instance_vars[current_type]?.try &.[node.name]?
      if info
        info.type
      else
        nil
      end
    end

    def guess_type(node : BinaryOp)
      left_type = guess_type(node.left)
      right_type = guess_type(node.right)
      guess_from_two(left_type, right_type, is_or: node.is_a?(Or))
    end

    def guess_type(node : If)
      then_type = guess_type(node.then)
      else_type = guess_type(node.else)
      guess_from_two(then_type, else_type)
    end

    def guess_type(node : Unless)
      then_type = guess_type(node.then)
      else_type = guess_type(node.else)
      guess_from_two(then_type, else_type)
    end

    def guess_type(node : Case)
      types = nil

      node.whens.each do |when|
        type = guess_type(when.body)
        next unless type

        types ||= [] of Type
        types << type
      end

      if node_else = node.else
        type = guess_type(node_else)
        if type
          types ||= [] of Type
          types << type
        end
      end

      types ? Type.merge!(types) : nil
    end

    def guess_type(node : Path)
      type = lookup_type_var?(node)
      return nil unless type

      if type.is_a?(Const)
        # Don't solve a constant we've already seen
        return nil if @consts.includes?(type)

        # Check if the const's value is actually an enum member
        if type.value.type?.try &.is_a?(EnumType)
          type.value.type
        else
          @consts.push(type)
          type = guess_type(type.value)
          @consts.pop
          type
        end
      else
        type.virtual_type.metaclass
      end
    end

    def guess_type(node : Expressions)
      last = node.expressions.last?
      last ? guess_type(last) : nil
    end

    def guess_type_in_method_body(node : Expressions)
      nodes = gather_returns(node)
      last = node.expressions.last?
      nodes << last if last

      types = nil
      nodes.each do |node|
        type = guess_type(node)
        return nil unless type

        types ||= [] of Type
        types << type
      end

      if types
        Type.merge!(types)
      else
        nil
      end
    end

    def guess_type(node : Assign)
      if node.target.is_a?(Var)
        return guess_type(node.value)
      end

      type_var = process_assign(node)
      type_var.is_a?(Type) ? type_var : nil
    end

    def guess_type(node : Not)
      @program.bool
    end

    def guess_type(node : IsA)
      @program.bool
    end

    def guess_type(node : RespondsTo)
      @program.bool
    end

    def guess_type(node : SizeOf)
      @program.int32
    end

    def guess_type(node : InstanceSizeOf)
      @program.int32
    end

    def guess_type(node : AlignOf)
      @program.int32
    end

    def guess_type(node : InstanceAlignOf)
      @program.int32
    end

    def guess_type(node : OffsetOf)
      @program.int32
    end

    def guess_type(node : Nop)
      @program.nil
    end

    def guess_from_two(type1, type2, is_or = false)
      type1 = TruthyFilter.instance.apply(type1) if type1 && is_or

      if type1
        if type2
          Type.merge!(type1, type2)
        else
          type1
        end
      else
        type2
      end
    end

    def guess_type(node : ASTNode)
      nil
    end

    def check_has_self(node)
      return false if node.is_a?(Var)

      @has_self_visitor.reset
      @has_self_visitor.accept(node)
      @found_self = true if @has_self_visitor.has_self
    end

    def check_var_is_self(node : Var)
      @found_self = true if node.name == "self"
    end

    def lookup_type?(node, root = nil, self_type = nil)
      find_root_generic_type_parameters =
        @dont_find_root_generic_type_parameters == 0

      # When searching a type that's not relative to the current type,
      # we don't want to find type parameters of those types, because they
      # are not bound.
      #
      # For example:
      #
      #    class Gen(T)
      #      def self.new
      #        Gen(T).new
      #      end
      #    end
      #
      #    class Foo
      #      @x = Gen.new
      #    end
      #
      # In the above example we would find `Gen.new`'s body to be
      # `Gen(T).new` so infer it to return `Gen(T)`, and `T` would be
      # found because we are searching types relative to `Gen`. But
      # since our current type is Foo, `T` is unbound, and we don't
      # want to find it.
      #
      # For this code:
      #
      #    class Foo(T)
      #      @x : T
      #    end
      #
      # we *do* want to find T as a type parameter relative to Foo,
      # even if it's unbound, because we are in the context of Foo.
      if root
        find_root_generic_type_parameters = root == current_type
      else
        root = current_type
      end

      type = root.lookup_type?(
        node,
        self_type: self_type || root.instance_type,
        allow_typeof: false,
        find_root_generic_type_parameters: find_root_generic_type_parameters
      )
      check_can_be_stored(node, type)
    end

    def lookup_type_var?(node, root = current_type)
      type_var = root.lookup_type_var?(node)
      return nil unless type_var.is_a?(Type)

      check_can_be_stored(node, type_var)
      type_var
    end

    def lookup_type_no_check?(node)
      current_type.lookup_type?(node, allow_typeof: false)
    end

    def check_can_be_stored(node, type)
      if type.is_a?(GenericClassType)
        nil
      elsif type.is_a?(GenericModuleType)
        nil
      elsif type && !type.can_be_stored?
        # Types such as Object, Int, etc., are not allowed in generics
        # and as variables types, so we disallow them.
        @error = Error.new(node, type)
        nil
      elsif type.is_a?(NonGenericClassType)
        type.virtual_type
      else
        type
      end
    end

    def visit(node : ClassDef)
      @initialize_infos[node.resolved_type] ||= [] of InitializeInfo
      super
    end

    def visit(node : ModuleDef)
      @initialize_infos[node.resolved_type] ||= [] of InitializeInfo
      super
    end

    def visit(node : TypeDeclaration)
      if value = node.value
        process_assign(node.var, value)
      end
      false
    end

    def visit(node : Def)
      # If this method was redefined and this new method doesn't
      # call `previous_def`, this method will never be called,
      # so we ignore it
      if (next_def = node.next) && !next_def.calls_previous_def?
        return false
      end

      super

      @outside_def = false
      @found_self = false
      @args = node.args
      @block_arg = node.block_arg
      @double_splat = node.double_splat
      @splat_index = node.splat_index
      @args_hash_initialized = false

      if !node.receiver && node.name == "initialize" && !current_type.is_a?(Program)
        initialize_info = @initialize_info = InitializeInfo.new(node)
      end

      @inside_class_method = !!node.receiver

      node.body.accept self

      @inside_class_method = false

      if initialize_info
        @initialize_infos[current_type] << initialize_info
      end

      @initialize_info = nil
      @block_arg = nil
      @args = nil
      @double_splat = nil
      @splat_index = nil
      @splat = nil
      @args_hash.clear
      @args_hash_initialized = true
      @outside_def = true

      false
    end

    def visit(node : FunDef)
      if body = node.body
        @outside_def = false
        @args = node.args
        @args_hash_initialized = false
        body.accept self
        @args = nil
        @args_hash.clear
        @args_hash_initialized = true
        @outside_def = true
      end

      false
    end

    def visit(node : ProcLiteral)
      node.def.body.accept self
      false
    end

    def visit(node : InstanceSizeOf | SizeOf | InstanceAlignOf | AlignOf | OffsetOf | TypeOf | PointerOf)
      false
    end

    def visit(node : MacroExpression)
      @outside_def ? super : false
    end

    def visit(node : MacroIf)
      @outside_def ? super : false
    end

    def visit(node : MacroFor)
      @outside_def ? super : false
    end

    def gather_returns(node)
      gatherer = ReturnGatherer.new
      node.accept gatherer
      gatherer.returns
    end

    def current_type
      @type_override || @current_type
    end

    def args_hash
      unless @args_hash_initialized
        @args.try &.each_with_index do |arg, i|
          @splat = arg if @splat_index == i
          @args_hash[arg.name] = arg
        end

        @double_splat.try do |arg|
          @args_hash[arg.name] = arg
        end

        @block_arg.try do |arg|
          @args_hash[arg.name] = arg
        end

        @args_hash_initialized = true
      end

      @args_hash
    end
  end

  class HasSelfVisitor < Visitor
    getter has_self

    def initialize
      @has_self = false
    end

    def reset
      @has_self = false
    end

    def visit(node : Call)
      # If it's "self.class", don't consider this as self being passed to a method
      return false if self_dot_class?(node)

      true
    end

    def visit(node : Var)
      if node.name == "self"
        @has_self = true
      end
      false
    end

    def visit(node : ASTNode)
      true
    end
  end

  class ReturnGatherer < Visitor
    getter returns

    def initialize
      @returns = [] of ASTNode
    end

    def visit(node : Return)
      @returns << (node.exp || NilLiteral.new)
      true
    end

    def visit(node : ASTNode)
      true
    end
  end
end

private def self_dot_class?(node : Crystal::Call)
  obj = node.obj
  obj.is_a?(Crystal::Var) && obj.name == "self" && node.name == "class" && node.args.empty?
end
