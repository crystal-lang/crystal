require "levenshtein"
require "../syntax/ast"
require "../types"
require "./type_lookup"

class Crystal::Call
  property! scope : Type
  property with_scope : Type?
  property! parent_visitor : MainVisitor
  property target_defs : Array(Def)?
  property expanded : ASTNode?
  property expanded_macro : Macro?
  property? uses_with_scope = false
  getter? raises = false

  def program
    scope.program
  end

  def target_def
    if defs = @target_defs
      if defs.size == 1
        return defs.first
      else
        ::raise "#{defs.size} target defs for #{self}"
      end
    end

    ::raise "Zero target defs for #{self}"
  end

  def recalculate
    obj = @obj
    obj_type = obj.type? if obj

    case obj_type
    when NoReturnType
      # A call on NoReturn will be NoReturn, so there's nothing to do
      return
    when LibType
      # `LibFoo.call` has a separate logic
      return recalculate_lib_call obj_type
    end

    # Check if it's call inside LibFoo
    # (can happen when assigning the call to a constant)
    if !obj && (lib_type = scope()).is_a?(LibType)
      return recalculate_lib_call lib_type
    end

    check_not_lib_out_args

    return if args.any? &.type?.try &.no_return?

    return unless obj_and_args_types_set?

    block = @block

    unbind_from @target_defs if @target_defs
    unbind_from block.break if block

    @target_defs = nil

    if block_arg = @block_arg
      replace_block_arg_with_block(block_arg)
    end

    matches = lookup_matches

    # If @target_defs is set here it means there was a recalculation
    # fired as a result of a recalculation. We keep the last one.

    return if @target_defs

    @target_defs = matches

    bind_to matches if matches
    bind_to block.break if block

    if (parent_visitor = @parent_visitor) && matches
      if parent_visitor.typed_def? && matches.any?(&.raises?)
        @raises = true
        parent_visitor.typed_def.raises = true
      end

      matches.each do |match|
        match.special_vars.try &.each do |special_var_name|
          special_var = match.vars.not_nil![special_var_name]
          parent_visitor.define_special_var(special_var_name, special_var)
        end
      end
    end
  end

  def lookup_matches
    if args.any? { |arg| arg.is_a?(Splat) || arg.is_a?(DoubleSplat) }
      lookup_matches_with_splat
    else
      arg_types = args.map(&.type)
      named_args_types = NamedArgumentType.from_args(named_args)
      lookup_matches_without_splat arg_types, named_args_types
    end
  end

  def lookup_matches_with_splat
    # Check if all splat are of tuples
    arg_types = Array(Type).new(args.size * 2)
    named_args_types = nil
    args.each_with_index do |arg, i|
      case arg
      when Splat
        case arg_type = arg.type
        when TupleInstanceType
          arg_types.concat arg_type.tuple_types
        when UnionType
          arg.raise "splatting a union #{arg_type} is not yet supported"
        else
          arg.raise "argument to splat must be a tuple, not #{arg_type}"
        end
      when DoubleSplat
        case arg_type = arg.type
        when NamedTupleInstanceType
          arg_type.entries.each do |entry|
            name, type = entry.name, entry.type

            named_args_types ||= [] of NamedArgumentType
            raise "duplicate key: #{name}" if named_args_types.any? &.name.==(name)
            named_args_types << NamedArgumentType.new(name, type)
          end
        when UnionType
          arg.raise "double splatting a union #{arg_type} is not yet supported"
        else
          arg.raise "argument to double splat must be a named tuple, not #{arg_type}"
        end
      else
        arg_types << arg.type
      end
    end

    # Leave named arguments at the end, so double splat args come before them
    # (they will be passed in this order)
    if named_args = self.named_args
      named_args_types ||= [] of NamedArgumentType
      named_args.each do |named_arg|
        raise "duplicate key: #{named_arg.name}" if named_args_types.any? &.name.==(named_arg.name)
        named_args_types << NamedArgumentType.new(named_arg.name, named_arg.value.type)
      end
    end

    lookup_matches_without_splat arg_types, named_args_types
  end

  def lookup_matches_without_splat(arg_types, named_args_types)
    if obj = @obj
      lookup_matches_in(obj.type, arg_types, named_args_types)
    elsif name == "super"
      lookup_super_matches(arg_types, named_args_types)
    elsif name == "previous_def"
      lookup_previous_def_matches(arg_types, named_args_types)
    elsif with_scope = @with_scope
      lookup_matches_with_scope_in with_scope, arg_types, named_args_types
    else
      lookup_matches_in scope, arg_types, named_args_types
    end
  end

  def lookup_matches_in(owner : AliasType, arg_types, named_args_types, self_type = nil, def_name = self.name, search_in_parents = true)
    lookup_matches_in(owner.remove_alias, arg_types, named_args_types, search_in_parents: search_in_parents)
  end

  def lookup_matches_in(owner : UnionType, arg_types, named_args_types, self_type = nil, def_name = self.name, search_in_parents = true)
    owner.union_types.flat_map { |type| lookup_matches_in(type, arg_types, named_args_types, search_in_parents: search_in_parents) }
  end

  def lookup_matches_in(owner : Program, arg_types, named_args_types, self_type = nil, def_name = self.name, search_in_parents = true)
    lookup_matches_in_type(owner, arg_types, named_args_types, self_type, def_name, search_in_parents)
  end

  def lookup_matches_in(owner : FileModule, arg_types, named_args_types, self_type = nil, def_name = self.name, search_in_parents = true)
    lookup_matches_in program, arg_types, named_args_types, search_in_parents: search_in_parents
  end

  def lookup_matches_in(owner : NonGenericModuleType | GenericModuleInstanceType | GenericType, arg_types, named_args_types, self_type = nil, def_name = self.name, search_in_parents = true)
    attach_subclass_observer owner

    including_types = owner.including_types
    if including_types
      lookup_matches_in(including_types, arg_types, named_args_types, search_in_parents: search_in_parents)
    else
      [] of Def
    end
  end

  def lookup_matches_in(owner : LibType, arg_types, named_args_types, self_type = nil, def_name = self.name, search_in_parents = true)
    raise "lib fun call is not supported in dispatch"
  end

  def lookup_matches_in(owner : Type, arg_types, named_args_types, self_type = nil, def_name = self.name, search_in_parents = true)
    lookup_matches_in_type(owner, arg_types, named_args_types, self_type, def_name, search_in_parents)
  end

  def lookup_matches_with_scope_in(owner, arg_types, named_args_types)
    signature = CallSignature.new(name, arg_types, block, named_args_types)

    matches = lookup_matches_checking_expansion(owner, signature)

    if matches.empty? && owner.class? && owner.abstract?
      matches = owner.virtual_type.lookup_matches(signature)
    end

    if matches.empty?
      @uses_with_scope = false
      return lookup_matches_in scope, arg_types, named_args_types
    end

    @uses_with_scope = true
    instantiate matches, owner, self_type: nil
  end

  def lookup_matches_in_type(owner, arg_types, named_args_types, self_type, def_name, search_in_parents, search_in_toplevel = true)
    signature = CallSignature.new(def_name, arg_types, block, named_args_types)

    matches = check_tuple_indexer(owner, def_name, args, arg_types)
    matches ||= lookup_matches_checking_expansion(owner, signature, search_in_parents)

    # If we didn't find a match and this call doesn't have a receiver,
    # and we are not at the top level, let's try searching the top-level
    if matches.empty? && !obj && owner != program && search_in_toplevel
      program_matches = lookup_matches_with_signature(program, signature, search_in_parents)
      matches = program_matches unless program_matches.empty?
    end

    if matches.empty? && owner.class? && owner.abstract? && name != "super"
      matches = owner.virtual_type.lookup_matches(signature)
    end

    if matches.empty?
      defined_method_missing = owner.check_method_missing(signature, self)
      if defined_method_missing
        matches = owner.lookup_matches(signature)
      elsif with_scope = @with_scope
        defined_method_missing = with_scope.check_method_missing(signature, self)
        if defined_method_missing
          matches = with_scope.lookup_matches(signature)
          @uses_with_scope = true
        end
      end
    end

    if matches.empty?
      # If the owner is abstract type without subclasses,
      # or if the owner is an abstract generic instance type,
      # don't give error. This is to allow small code comments without giving
      # compile errors, which will anyway appear once you add concrete
      # subclasses and instances.
      if def_name == "new" || !(!owner.metaclass? && owner.abstract? && (owner.leaf? || owner.is_a?(GenericClassInstanceType)))
        raise_matches_not_found(matches.owner || owner, def_name, arg_types, named_args_types, matches)
      end
    end

    # If this call is an implicit call to self
    if !obj && !program_matches && !owner.is_a?(Program)
      parent_visitor.check_self_closured
    end

    instance_type = owner.instance_type
    if instance_type.is_a?(VirtualType)
      attach_subclass_observer instance_type.base_type
    end

    instantiate matches, owner, self_type
  end

  def lookup_matches_checking_expansion(owner, signature, search_in_parents = true)
    # If this call is an expansion (because of default or named args) we must
    # resolve the call in the type that defined the original method, without
    # triggering a virtual lookup. But the context of lookup must be preseved.
    if expansion?
      matches = bubbling_exception do
        target = parent_visitor.typed_def.original_owner
        if search_in_parents
          target.lookup_matches signature
        else
          target.lookup_matches_without_parents signature
        end
      end
      matches.each do |match|
        match.context.instantiated_type = owner
        match.context.defining_type = parent_visitor.path_lookup.not_nil!
      end
      matches
    else
      bubbling_exception { lookup_matches_with_signature(owner, signature, search_in_parents) }
    end
  end

  def lookup_matches_with_signature(owner : Program, signature, search_in_parents)
    location = self.location
    if location && (filename = location.original_filename)
      matches = owner.lookup_private_matches filename, signature
    end

    if matches
      if matches.empty?
        matches = owner.lookup_matches signature
      end
    else
      matches = owner.lookup_matches signature
    end

    matches
  end

  def lookup_matches_with_signature(owner, signature, search_in_parents)
    if search_in_parents
      owner.lookup_matches signature
    else
      owner.lookup_matches_without_parents signature
    end
  end

  def instantiate(matches, owner, self_type)
    block = @block

    typed_defs = Array(Def).new(matches.size)

    matches.each do |match|
      check_visibility match

      yield_vars, block_arg_type = match_block_arg(match)
      use_cache = !block || match.def.block_arg

      if block && match.def.block_arg
        if block_arg_type.is_a?(ProcInstanceType)
          block_type = block_arg_type.return_type
        end
        use_cache = false unless block_type
      end

      lookup_self_type = self_type || match.context.instantiated_type
      if self_type
        lookup_arg_types = Array(Type).new(match.arg_types.size + 1)
        lookup_arg_types.push self_type
        lookup_arg_types.concat match.arg_types
      else
        lookup_arg_types = match.arg_types
      end
      match_owner = match.context.instantiated_type
      def_instance_owner = (self_type || match_owner).as(DefInstanceContainer)
      named_args_types = match.named_arg_types

      def_instance_key = DefInstanceKey.new(match.def.object_id, lookup_arg_types, block_type, named_args_types)
      typed_def = def_instance_owner.lookup_def_instance def_instance_key if use_cache

      unless typed_def
        typed_def, typed_def_args = prepare_typed_def_with_args(match.def, match_owner, lookup_self_type, match.arg_types, block_arg_type, named_args_types)
        def_instance_owner.add_def_instance(def_instance_key, typed_def) if use_cache

        if typed_def_return_type = typed_def.return_type
          check_return_type(typed_def, typed_def_return_type, match, match_owner)
        end

        check_recursive_splat_call match.def, typed_def_args do
          bubbling_exception do
            visitor = MainVisitor.new(program, typed_def_args, typed_def)
            visitor.yield_vars = yield_vars
            visitor.match_context = match.context
            visitor.untyped_def = match.def
            visitor.call = self
            visitor.scope = lookup_self_type
            visitor.path_lookup = match.context.defining_type

            yields_to_block = block && !match.def.uses_block_arg?

            if yields_to_block
              raise_if_block_too_nested(match.def.block_nest)
              match.def.block_nest += 1
            end

            typed_def.body.accept visitor

            if yields_to_block
              match.def.block_nest -= 1
            end

            if visitor.is_initialize
              if match.def.macro_def?
                visitor.check_initialize_instance_vars_types(owner)
              end
              visitor.bind_initialize_instance_vars(owner)
            end
          end
        end
      end

      typed_defs << typed_def
    end

    typed_defs
  end

  def raise_if_block_too_nested(block_nest)
    # When we visit this def's body, we nest. If we are nesting
    # over and over again, and there's a block, it means this will go on forever
    #
    # TODO Ideally this should check `> 1`, but the algorithm isn't precise. However,
    # manually nested blocks don't nest this deep.
    if block_nest > 15
      raise "recursive block expansion: blocks that yield are always inlined, and this call leads to an infinite inlining"
    end
  end

  def check_return_type(typed_def, typed_def_return_type, match, match_owner)
    return_type = lookup_node_type(match.context, typed_def_return_type)
    return_type = program.nil if return_type.void?
    typed_def.freeze_type = return_type
    typed_def.type = return_type if return_type.no_return? || return_type.nil_type?
  end

  def check_tuple_indexer(owner, def_name, args, arg_types)
    return unless args.size == 1

    case def_name
    when "[]"
      nilable = false
    when "[]?"
      nilable = true
    else
      return
    end

    if owner.is_a?(TupleInstanceType)
      # Check tuple indexer
      tuple_indexer_helper(args, arg_types, owner, owner, nilable) do |instance_type, index|
        instance_type.tuple_indexer(index)
      end
    elsif owner.metaclass? && (instance_type = owner.instance_type).is_a?(TupleInstanceType)
      # Check tuple metaclass indexer
      tuple_indexer_helper(args, arg_types, owner, instance_type, nilable) do |instance_type, index|
        instance_type.tuple_metaclass_indexer(index)
      end
    elsif owner.is_a?(NamedTupleInstanceType)
      # Check named tuple indexer
      named_tuple_indexer_helper(args, arg_types, owner, owner, nilable) do |instance_type, index|
        instance_type.tuple_indexer(index)
      end
    elsif owner.metaclass? && (instance_type = owner.instance_type).is_a?(NamedTupleInstanceType)
      # Check named tuple metaclass indexer
      named_tuple_indexer_helper(args, arg_types, owner, instance_type, nilable) do |instance_type, index|
        instance_type.tuple_metaclass_indexer(index)
      end
    end
  end

  def tuple_indexer_helper(args, arg_types, owner, instance_type, nilable)
    arg = args.first
    if arg.is_a?(NumberLiteral) && arg.kind == :i32
      index = arg.value.to_i
      index += instance_type.size if index < 0
      in_bounds = (0 <= index < instance_type.size)
      if nilable || in_bounds
        indexer_def = yield instance_type, (in_bounds ? index : -1)
        indexer_match = Match.new(indexer_def, arg_types, MatchContext.new(owner, owner))
        return Matches.new([indexer_match] of Match, true)
      elsif instance_type.size == 0
        raise "index '#{arg}' out of bounds for empty tuple"
      else
        raise "index out of bounds for #{owner} (#{arg} not in #{-instance_type.size}..#{instance_type.size - 1})"
      end
    end
    nil
  end

  def named_tuple_indexer_helper(args, arg_types, owner, instance_type, nilable)
    arg = args.first

    case arg
    when SymbolLiteral, StringLiteral
      name = arg.value
    end

    if name
      index = instance_type.name_index(name)
      if index || nilable
        indexer_def = yield instance_type, (index || -1)
        indexer_match = Match.new(indexer_def, arg_types, MatchContext.new(owner, owner))
        return Matches.new([indexer_match] of Match, true)
      else
        raise "missing key '#{name}' for named tuple #{owner}"
      end
    end
    nil
  end

  def replace_splats
    return unless args.any? { |arg| arg.is_a?(Splat) || arg.is_a?(DoubleSplat) }

    new_args = [] of ASTNode
    args.each_with_index do |arg, i|
      case arg
      when Splat
        arg_type = arg.type
        unless arg_type.is_a?(TupleInstanceType)
          arg.raise "BUG: splat expects a tuple, not #{arg_type}"
        end

        arg_type.tuple_types.each_with_index do |tuple_type, index|
          num = NumberLiteral.new(index)
          num.type = program.int32
          tuple_indexer = Call.new(arg.exp, "[]", num).at(arg)
          parent_visitor.prepare_call(tuple_indexer)
          tuple_indexer.recalculate
          new_args << tuple_indexer
          arg.remove_enclosing_call(self)
        end
      when DoubleSplat
        arg_type = arg.type
        unless arg_type.is_a?(NamedTupleInstanceType)
          arg.raise "BUG: double splat expects a named tuple, not #{arg_type}"
        end

        arg_type.entries.each do |entry|
          sym = SymbolLiteral.new(entry.name)
          sym.type = program.symbol
          program.symbols.add sym.value
          tuple_indexer = Call.new(arg.exp, "[]", sym).at(arg)
          parent_visitor.prepare_call(tuple_indexer)
          tuple_indexer.recalculate
          new_args << tuple_indexer
          arg.remove_enclosing_call(self)
        end
      else
        new_args << arg
      end
    end
    self.args = new_args
  end

  def replace_block_arg_with_block(block_arg)
    block_arg_type = block_arg.type
    if block_arg_type.is_a?(ProcInstanceType)
      vars = [] of Var
      args = [] of ASTNode
      block_arg_type.arg_types.map_with_index do |type, i|
        arg = Var.new("__arg#{i}").at(block_arg)
        vars << arg
        args << arg
      end
      block = Block.new(vars, Call.new(block_arg.clone, "call", args).at(block_arg)).at(block_arg)
      block.vars = self.before_vars
      self.block = block
    else
      block_arg.raise "expected a function type, not #{block_arg.type}"
    end
  end

  def lookup_super_matches(arg_types, named_args_types)
    if scope.is_a?(Program)
      raise "there's no superclass in this scope"
    end

    enclosing_def = enclosing_def("super")

    # TODO: do this better
    lookup = enclosing_def.owner

    case lookup
    when VirtualType
      parents = lookup.base_type.ancestors
    when NonGenericModuleType
      ancestors = parent_visitor.scope.ancestors
      index_of_ancestor = ancestors.index(lookup).not_nil!
      parents = ancestors[index_of_ancestor + 1..-1]
    when GenericModuleType
      ancestors = parent_visitor.scope.ancestors
      index_of_ancestor = ancestors.index { |ancestor| ancestor.is_a?(GenericModuleInstanceType) && ancestor.generic_type == lookup }.not_nil!
      parents = ancestors[index_of_ancestor + 1..-1]
    when GenericType
      ancestors = parent_visitor.scope.ancestors
      index_of_ancestor = ancestors.index { |ancestor| ancestor.is_a?(GenericClassInstanceType) && ancestor.generic_type == lookup }
      if index_of_ancestor
        parents = ancestors[index_of_ancestor + 1..-1]
      else
        parents = ancestors
      end
    else
      parents = lookup.ancestors
    end

    in_initialize = enclosing_def.name == "initialize"

    if parents && parents.size > 0
      parents.each_with_index do |parent, i|
        if parent.lookup_first_def(enclosing_def.name, block)
          return lookup_matches_in_type(parent, arg_types, named_args_types, scope, enclosing_def.name, !in_initialize, search_in_toplevel: false)
        end
      end
      lookup_matches_in_type(parents.last, arg_types, named_args_types, scope, enclosing_def.name, !in_initialize, search_in_toplevel: false)
    else
      raise "there's no superclass in this scope"
    end
  end

  def lookup_previous_def_matches(arg_types, named_args_types)
    enclosing_def = enclosing_def("previous_def")

    previous_item = enclosing_def.previous
    unless previous_item
      return raise "there is no previous definition of '#{enclosing_def.name}'"
    end

    previous = previous_item.def

    signature = CallSignature.new(previous.name, arg_types, block, named_args_types)
    context = MatchContext.new(scope, scope, def_free_vars: previous.free_vars)
    match = Match.new(previous, arg_types, context, named_args_types)
    matches = Matches.new([match] of Match, true)

    unless signature.match(previous_item, context)
      raise_matches_not_found scope, previous.name, arg_types, named_args_types, matches
    end

    unless scope.is_a?(Program)
      parent_visitor.check_self_closured
    end

    typed_defs = instantiate matches, scope, self_type: nil
    typed_defs.each do |typed_def|
      typed_def.next = parent_visitor.typed_def
    end
    typed_defs
  end

  def enclosing_def(context)
    fun_literal_context = parent_visitor.fun_literal_context
    if fun_literal_context.is_a?(Def)
      return fun_literal_context
    end

    untyped_def = parent_visitor.untyped_def?
    if untyped_def
      return untyped_def
    end

    raise "can't use '#{context}' outside method"
  end

  def on_new_subclass
    recalculate
  end

  def lookup_macro
    in_macro_target do |target|
      result = target.lookup_macro(name, args, named_args)
      case result
      when Macro
        return result
      when Type::DefInMacroLookup
        return nil
      end
    end
  end

  def in_macro_target
    if with_scope = @with_scope
      macros = yield with_scope
      return macros if macros
    end

    node_scope = scope
    node_scope = node_scope.base_type if node_scope.is_a?(VirtualType)

    macros = yield node_scope

    # If the scope is a module (through its instance type), lookup in Object too
    # (so macros like `property` and others, defined in Object, work at the module level)
    if !macros && node_scope.instance_type.module?
      macros = yield program.object
    end

    macros ||= yield program

    if !macros && (location = self.location) && (filename = location.original_filename).is_a?(String) && (file_module = program.file_module?(filename))
      macros ||= yield file_module
    end

    macros
  end

  # Match the given block with the given block argument specification (&block : A, B, C -> D)
  def match_block_arg(match)
    block_arg = match.def.block_arg
    return nil, nil unless block_arg
    return nil, nil unless match.def.yields || match.def.uses_block_arg?

    yield_vars = nil
    block_arg_type = nil

    block = @block.not_nil!

    block_arg_restriction = block_arg.restriction

    # If the block spec is &block : A, B, C -> D, we solve the argument types
    if block_arg_restriction.is_a?(ProcNotation)
      # If there are input types, solve them and creating the yield vars
      if inputs = block_arg_restriction.inputs
        yield_vars = Array(Var).new(inputs.size + 1)
        i = 0
        inputs.each do |input|
          if input.is_a?(Splat)
            tuple_type = lookup_node_type(match.context, input.exp)
            unless tuple_type.is_a?(TupleInstanceType)
              input.raise "expected type to be a tuple type, not #{tuple_type}"
            end
            tuple_type.tuple_types.each do |arg_type|
              MainVisitor.check_type_allowed_as_proc_argument(input, arg_type)
              yield_vars << Var.new("var#{i}", arg_type.virtual_type)
              i += 1
            end
          else
            arg_type = lookup_node_type(match.context, input)
            MainVisitor.check_type_allowed_as_proc_argument(input, arg_type)

            yield_vars << Var.new("var#{i}", arg_type.virtual_type)
            i += 1
          end
        end
      end
      output = block_arg_restriction.output
    elsif block_arg_restriction
      # Otherwise, the block spec could be something like &block : Foo, and that
      # is valid too only if Foo is an alias/typedef that referes to a FunctionType
      block_arg_type = lookup_node_type(match.context, block_arg_restriction).remove_typedef
      unless block_arg_type.is_a?(ProcInstanceType)
        block_arg_restriction.raise "expected block type to be a function type, not #{block_arg_type}"
        return nil, nil
      end

      yield_vars = block_arg_type.arg_types.map_with_index do |input, i|
        Var.new("var#{i}", input)
      end
      output = block_arg_type.return_type
      output_type = output
      output_type = program.nil if output_type.void?
    end

    if yield_vars
      # Check if tuple unpkacing is needed
      if yield_vars.size == 1 &&
         (yield_var_type = yield_vars.first.type).is_a?(TupleInstanceType) &&
         block.args.size > 1
        yield_var_type.tuple_types.each_with_index do |tuple_type, i|
          arg = block.args[i]?
          arg.type = tuple_type if arg
        end
      else
        yield_vars.each_with_index do |yield_var, i|
          yield_var_type = yield_var.type
          arg = block.args[i]?
          arg.bind_to(yield_var || program.nil_var) if arg
        end
      end
    end

    # If the block is used, we convert it to a function pointer
    if match.def.uses_block_arg?
      # Create the arguments of the function literal
      if yield_vars
        fun_args = yield_vars.map_with_index do |var, i|
          arg_name = block.args[i]?.try(&.name) || program.new_temp_var_name
          Arg.new(arg_name, type: var.type)
        end
      else
        fun_args = [] of Arg
      end

      if match.def.free_var?(output)
        # Nothing, output is a free variable
      elsif output.is_a?(ASTNode) && !output.is_a?(Underscore)
        output_type = lookup_node_type?(match.context, output)
        if output_type
          output_type = program.nil if output_type.void?
          Crystal.check_type_allowed_in_generics(output, output_type, "can't use #{output_type} as a block return type")
          output_type = output_type.virtual_type
        end
      end

      # Check if the call has a block arg (foo &bar). If so, we need to see if the
      # passed block has the same signature as the def's block arg. We use that
      # same ProcLiteral (bar) for this call.
      fun_literal = block.fun_literal
      unless fun_literal
        if call_block_arg = self.block_arg
          check_call_block_arg_matches_def_block_arg(call_block_arg, yield_vars)
          fun_literal = call_block_arg
        else
          # Otherwise, we create a ProcLiteral and type it
          if block.args.size > fun_args.size
            wrong_number_of "block arguments", block.args.size, fun_args.size
          end

          a_def = Def.new("->", fun_args, block.body)
          a_def.captured_block = true

          fun_literal = ProcLiteral.new(a_def).at(self)
          fun_literal.expected_return_type = output_type if output_type
          fun_literal.force_nil = true unless output
          fun_literal.accept parent_visitor
        end
        block.fun_literal = fun_literal
      end

      # Now check if the ProcLiteral's type (the block's type) matches the block arg specification.
      # If not, we delay it for later and compute the type based on the block arg return type, if any.
      fun_literal_type = fun_literal.type?
      if fun_literal_type
        block_arg_type = fun_literal_type
        block_type = fun_literal_type.as(ProcInstanceType).return_type
        if output
          match.context.def_free_vars = match.def.free_vars
          matched = block_type.restrict(output, match.context)
          if !matched && !void_return_type?(match.context, output)
            if output.is_a?(ASTNode) && !output.is_a?(Underscore) && block_type.no_return?
              block_type = lookup_node_type(match.context, output).virtual_type
              block.type = output_type || block_type
              block.freeze_type = output_type || block_type
              block_arg_type = program.proc_of(fun_args, block_type)
            else
              raise "expected block to return #{output}, not #{block_type}"
            end
          elsif output_type
            block.bind_to(block)
            block.type = output_type
            block.freeze_type = output_type
          end
        end
      else
        if output
          if !match.def.free_var?(output) && output.is_a?(ASTNode) && !output.is_a?(Underscore)
            output_type = lookup_node_type(match.context, output).virtual_type
            output_type = program.nil if output_type.void?
            block.type = output_type
            block.freeze_type = output_type
            block_arg_type = program.proc_of(fun_args, output_type)
          else
            cant_infer_block_return_type
          end
        else
          block.body.type = program.void
          block.type = program.void
          block_arg_type = program.proc_of(fun_args, program.void)
        end
      end

      # Because the block's type might be used as a free variable, we bind
      # ourself to the block so when its type changes we recalculate ourself.
      if output
        block.try &.remove_enclosing_call(self)
        block.try &.set_enclosing_call(self)
      end
    else
      block.accept parent_visitor

      # Similar to above: we check that the block's type matches the block arg specification,
      # and we delay it if possible.
      if output
        if !block.type?
          if !match.def.free_var?(output) && output.is_a?(ASTNode) && !output.is_a?(Underscore)
            begin
              block_type = lookup_node_type(match.context, output).virtual_type
              block_type = program.nil if block_type.void?
            rescue ex : Crystal::Exception
              cant_infer_block_return_type
            end
          else
            cant_infer_block_return_type
          end
        else
          block_type = block.type
          match.context.def_free_vars = match.def.free_vars
          matched = block_type.restrict(output, match.context)
          if (!matched || (matched && !block_type.implements?(matched))) && !void_return_type?(match.context, output)
            if output.is_a?(ASTNode) && !output.is_a?(Underscore) && block_type.no_return?
              begin
                block_type = lookup_node_type(match.context, output).virtual_type
              rescue ex : Crystal::Exception
                if block_type
                  raise "couldn't match #{block_type} to #{output}", ex
                else
                  cant_infer_block_return_type
                end
              end
            else
              if output.is_a?(Self)
                raise "expected block to return #{match.context.instantiated_type}, not #{block_type}"
              else
                raise "expected block to return #{output}, not #{block_type}"
              end
            end
          end
        end
        block.freeze_type = block_type
      end
    end

    {yield_vars, block_arg_type}
  end

  private def check_call_block_arg_matches_def_block_arg(call_block_arg, yield_vars)
    call_block_arg_types = call_block_arg.type.as(ProcInstanceType).arg_types
    if yield_vars
      if yield_vars.size != call_block_arg_types.size
        wrong_number_of "block argument's arguments", call_block_arg_types.size, yield_vars.size
      end

      i = 1
      yield_vars.zip(call_block_arg_types) do |yield_var, call_block_arg_type|
        if yield_var.type != call_block_arg_type
          raise "expected block argument's argument ##{i} to be #{yield_var.type}, not #{call_block_arg_type}"
        end
        i += 1
      end
    elsif call_block_arg_types.size != 0
      wrong_number_of "block argument's arguments", call_block_arg_types.size, 0
    end
  end

  private def void_return_type?(match_context, output)
    if output.is_a?(Path)
      type = lookup_node_type(match_context, output)
    else
      type = output
    end

    type.is_a?(Type) && (type.void? || type.nil_type?)
  end

  private def cant_infer_block_return_type
    raise "can't infer block return type, try to cast the block body with `as`. See: https://github.com/crystal-lang/crystal/wiki/Compiler-error-messages#cant-infer-block-return-type"
  end

  private def lookup_node_type(context, node)
    bubbling_exception do
      context.defining_type.lookup_type(node, self_type: context.instantiated_type.instance_type, free_vars: context.free_vars)
    end
  end

  private def lookup_node_type?(context, node)
    context.defining_type.lookup_type?(node, self_type: context.instantiated_type.instance_type, free_vars: context.free_vars)
  end

  def bubbling_exception
    begin
      yield
    rescue ex : Crystal::Exception
      if obj = @obj
        if name == "initialize"
          # Avoid putting 'initialize' in the error trace
          # because it's most likely that this is happening
          # inside a generated 'new' method
          ::raise ex
        else
          raise "instantiating '#{obj.type}##{name}(#{args.map(&.type).join ", "})'", ex
        end
      else
        raise "instantiating '#{name}(#{args.map(&.type).join ", "})'", ex
      end
    end
  end

  def obj_and_args_types_set?
    obj = @obj
    block_arg = @block_arg
    named_args = @named_args

    return false unless args.all? &.type?
    return false if obj && !obj.type?
    return false if block_arg && !block_arg.type?
    return false if named_args && named_args.any? { |arg| !arg.value.type? }

    true
  end

  def prepare_typed_def_with_args(untyped_def, owner, self_type, arg_types, block_arg_type, named_args_types)
    original_untyped_def = untyped_def

    # If there's an argument count mismatch, or we have a splat, or a double splat, or there are
    # named arguments, we create another def that sets ups everything for the real call.
    if arg_types.size != untyped_def.args.size || untyped_def.splat_index || named_args_types || untyped_def.double_splat
      named_args_names = named_args_types.try &.map &.name

      # We expand new in a different way, because default arguments need to be solved at the instance level,
      # not at the class level. So we simply create a `new` that simply forwards all arguments to the `initialize`
      # call (first allocating an object, and later hooking it to the GC finalizer if needed): the `initialize`
      # method will set up default values and repack splats if needed.
      if untyped_def.new?
        untyped_def = untyped_def.expand_new_default_arguments(self_type.instance_type, arg_types.size, named_args_names)
      else
        untyped_def = untyped_def.expand_default_arguments(program, arg_types.size, named_args_names)
      end

      # This is the case of Proc#call(*args), but could be applied to any primitive really
      body = original_untyped_def.body
      untyped_def.body = body.clone if body.is_a?(Primitive)
    end

    typed_def = untyped_def.clone
    typed_def.owner = owner
    typed_def.original_owner = untyped_def.owner

    if body = typed_def.body
      typed_def.bind_to body
    end

    args = MetaVars.new

    if self_type
      args["self"] = MetaVar.new("self", self_type)
    end

    strict_check = body.is_a?(Primitive) && body.name == "proc_call"

    arg_types.each_index do |index|
      arg = typed_def.args[index]
      type = arg_types[index]
      var = MetaVar.new(arg.name, type).at(arg.location)
      var.bind_to(var)
      args[arg.name] = var

      if strict_check
        owner = owner.as(ProcInstanceType)
        proc_arg_type = owner.arg_types[index]
        unless type.covariant?(proc_arg_type)
          self.args[index].raise "type must be #{proc_arg_type}, not #{type}"
        end
      end

      arg.type = type
    end

    # Fill magic constants (__LINE__, __FILE__, __DIR__)
    named_args_size = named_args_types.try(&.size) || 0
    (arg_types.size + named_args_size).upto(typed_def.args.size - 1) do |index|
      arg = typed_def.args[index]
      default_value = arg.default_value.as(MagicConstant)
      case default_value.name
      when :__LINE__, :__END_LINE__
        type = program.int32
      when :__FILE__, :__DIR__
        type = program.string
      else
        default_value.raise "BUG: unknown magic constant: #{default_value.name}"
      end
      var = MetaVar.new(arg.name, type).at(arg.location)
      var.bind_to(var)
      args[arg.name] = var
      arg.type = type
    end

    named_args_types.try &.each do |named_arg|
      arg = typed_def.args.find { |arg| arg.external_name == named_arg.name }.not_nil!

      type = named_arg.type
      var = MetaVar.new(arg.name, type)
      var.bind_to(var)

      args[arg.name] = var
      arg.type = type
    end

    fun_literal = @block.try &.fun_literal
    if fun_literal && block_arg_type
      block_arg = untyped_def.block_arg.not_nil!
      var = MetaVar.new(block_arg.name, block_arg_type)
      args[block_arg.name] = var

      typed_def.block_arg.not_nil!.type = block_arg_type
    end

    {typed_def, args}
  end

  def attach_subclass_observer(type : Type)
    if subclass_notifier = @subclass_notifier
      subclass_notifier.as(SubclassObservable).remove_subclass_observer(self)
    end

    type.as(SubclassObservable).add_subclass_observer(self)
    @subclass_notifier = type
  end

  def raises=(value)
    if @raises != value
      @raises = value
      typed_def = parent_visitor.typed_def?
      if typed_def
        typed_def.raises = value
      end
    end
  end
end
