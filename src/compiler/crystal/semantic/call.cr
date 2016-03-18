require "levenshtein"
require "../syntax/ast"
require "../types"
require "../primitives"
require "./type_lookup"

class Crystal::Call
  property! scope : Type
  property with_scope : Type?
  property! parent_visitor : MainVisitor?
  property target_defs : Array(Def)?
  property expanded : ASTNode?

  property? is_expansion : Bool
  @is_expansion = false

  property? uses_with_scope : Bool
  @uses_with_scope = false

  getter? raises : Bool
  @raises = false

  @subclass_notifier : ModuleType?

  def mod
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

  def update_input(from)
    recalculate
  end

  def recalculate
    obj = @obj
    obj_type = obj.type? if obj

    if obj_type.is_a?(LibType)
      recalculate_lib_call obj_type
      return
    end

    if !obj && (lib_type = scope()).is_a?(LibType)
      recalculate_lib_call lib_type
      return
    end

    check_not_lib_out_args

    if args.any? &.type?.try &.no_return?
      return
    end

    return unless obj_and_args_types_set?

    block = @block

    unbind_from @target_defs if @target_defs
    unbind_from block.break if block

    block.try &.args.each &.unbind_all

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
      if parent_visitor.typed_def? && matches.any?(&.raises)
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
    if args.any? &.is_a?(Splat)
      lookup_matches_with_splat
    else
      lookup_matches_without_splat args.map(&.type)
    end
  end

  def lookup_matches_with_splat
    # Check if all splat are of tuples
    arg_types = Array(Type).new(args.size * 2)
    args.each do |arg|
      if arg.is_a?(Splat)
        case arg_type = arg.type
        when TupleInstanceType
          arg_types.concat arg_type.tuple_types
        when UnionType
          arg.raise "splatting a union #{arg_type} is not yet supported"
        else
          arg.raise "argument to splat must be a tuple, not #{arg_type}"
        end
      else
        arg_types << arg.type
      end
    end
    lookup_matches_without_splat arg_types
  end

  def lookup_matches_without_splat(arg_types)
    if obj = @obj
      lookup_matches_in(obj.type, arg_types)
    elsif name == "super"
      lookup_matches_in_super(arg_types)
    elsif name == "previous_def"
      lookup_previous_def_matches(arg_types)
    elsif with_scope = @with_scope
      lookup_matches_in_with_scope with_scope, arg_types
    else
      lookup_matches_in scope, arg_types
    end
  end

  def lookup_matches_in(owner : AliasType, arg_types, self_type = nil, def_name = self.name, search_in_parents = true)
    lookup_matches_in(owner.remove_alias, arg_types, search_in_parents: search_in_parents)
  end

  def lookup_matches_in(owner : UnionType, arg_types, self_type = nil, def_name = self.name, search_in_parents = true)
    owner.union_types.flat_map { |type| lookup_matches_in(type, arg_types, search_in_parents: search_in_parents) }
  end

  def lookup_matches_in(owner : Program, arg_types, self_type = nil, def_name = self.name, search_in_parents = true)
    lookup_matches_in_type(owner, arg_types, self_type, def_name, search_in_parents)
  end

  def lookup_matches_in(owner : FileModule, arg_types, self_type = nil, def_name = self.name, search_in_parents = true)
    lookup_matches_in mod, arg_types, search_in_parents: search_in_parents
  end

  def lookup_matches_in(owner : NonGenericModuleType, arg_types, self_type = nil, def_name = self.name, search_in_parents = true)
    attach_subclass_observer owner

    including_types = owner.including_types
    if including_types
      lookup_matches_in(including_types, arg_types, search_in_parents: search_in_parents)
    else
      [] of Def
    end
  end

  def lookup_matches_in(owner : GenericClassType, arg_types, self_type = nil, def_name = self.name, search_in_parents = true)
    including_types = owner.including_types
    if including_types
      attach_subclass_observer owner

      lookup_matches_in(including_types, arg_types, search_in_parents: search_in_parents)
    else
      raise "no type inherits #{owner}"
    end
  end

  def lookup_matches_in(owner : LibType, arg_types, self_type = nil, def_name = self.name, search_in_parents = true)
    raise "lib fun call is not supported in dispatch"
  end

  def lookup_matches_in(owner : Type, arg_types, self_type = nil, def_name = self.name, search_in_parents = true)
    lookup_matches_in_type(owner, arg_types, self_type, def_name, search_in_parents)
  end

  def lookup_matches_in_with_scope(owner, arg_types)
    signature = CallSignature.new(name, arg_types, block, named_args)

    matches = check_tuple_indexer(owner, name, args, arg_types)
    matches ||= lookup_matches_checking_expansion(owner, signature)

    if matches.empty? && owner.class? && owner.abstract?
      matches = owner.virtual_type.lookup_matches(signature)
    end

    if matches.empty?
      @uses_with_scope = false
      return lookup_matches_in scope, arg_types
    end

    if matches.empty?
      raise_matches_not_found(matches.owner || owner, name, matches)
    end

    @uses_with_scope = true
    instantiate matches, owner, nil
  end

  def lookup_matches_in_type(owner, arg_types, self_type, def_name, search_in_parents)
    signature = CallSignature.new(def_name, arg_types, block, named_args)

    matches = check_tuple_indexer(owner, def_name, args, arg_types)
    matches ||= lookup_matches_checking_expansion(owner, signature, search_in_parents)

    if matches.empty?
      if def_name == "new" && owner.metaclass? && (owner.instance_type.class? || owner.instance_type.virtual?) && !owner.instance_type.pointer?
        new_matches = define_new owner, arg_types
        unless new_matches.empty?
          if owner.virtual_metaclass?
            matches = owner.lookup_matches(signature)
          else
            matches = new_matches
          end
        end
      elsif name == "super" && def_name == "initialize" && args.empty?
        # If the superclass has no `new` and no `initialize`, we can safely
        # define an empty initialize
        has_new = owner.metaclass.has_def_without_parents?("new")
        has_initialize = owner.has_def_without_parents?("initialize")
        unless has_new || has_initialize
          initialize_def = Def.new("initialize")
          owner.add_def initialize_def
          matches = Matches.new([Match.new(initialize_def, arg_types, MatchContext.new(owner, owner))], true)
        end
      elsif !obj && owner != mod
        mod_matches = lookup_matches_with_signature(mod, signature, search_in_parents)
        matches = mod_matches unless mod_matches.empty?
      end
    end

    if matches.empty? && owner.class? && owner.abstract? && name != "super"
      matches = owner.virtual_type.lookup_matches(signature)
    end

    if matches.empty?
      defined_method_missing = owner.check_method_missing(signature)
      if defined_method_missing
        matches = owner.lookup_matches(signature)
      end
    end

    if matches.empty?
      # For now, if the owner is a NoReturn just ignore the error (this call should be recomputed later)
      unless owner.no_return?
        # If the owner is abstract type without subclasses,
        # or if the owner is an abstract generic instance type,
        # don't give error. This is to allow small code comments without giving
        # compile errors, which will anyway appear once you add concrete
        # subclasses and instances.
        unless owner.abstract? && (owner.leaf? || owner.is_a?(GenericClassInstanceType))
          raise_matches_not_found(matches.owner || owner, def_name, matches)
        end
      end
    end

    # If this call is an implicit call to self
    if !obj && !mod_matches && !owner.is_a?(Program)
      parent_visitor.check_self_closured
    end

    instance_type = owner.instance_type
    if instance_type.is_a?(VirtualType)
      attach_subclass_observer instance_type.base_type
    end

    instantiate matches, owner, self_type
  end

  def lookup_matches_in(owner : Nil, arg_types)
    raise "Bug: trying to lookup matches in nil in #{self}"
  end

  def lookup_matches_checking_expansion(owner, signature, search_in_parents = true)
    # If this call is an expansion (because of default or named args) we must
    # resolve the call in the type that defined the original method, without
    # triggering a virtual lookup. But the context of lookup must be preseved.
    if is_expansion?
      matches = bubbling_exception do
        target = parent_visitor.typed_def.original_owner
        if search_in_parents
          target.lookup_matches signature
        else
          target.lookup_matches_without_parents signature
        end
      end
      matches.each do |match|
        match.context.owner = owner
        match.context.type_lookup = parent_visitor.type_lookup.not_nil!
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

  def instantiate(matches, owner, self_type = nil)
    block = @block

    typed_defs = Array(Def).new(matches.size)

    matches.each do |match|
      # Discard abstract defs for abstract classes
      next if match.def.abstract? && match.context.owner.abstract?

      check_visibility match

      yield_vars, block_arg_type = match_block_arg(match)
      use_cache = !block || match.def.block_arg

      if block && match.def.block_arg
        if block_arg_type.is_a?(FunInstanceType)
          block_type = block_arg_type.return_type
        end
        use_cache = false unless block_type
      end

      lookup_self_type = self_type || match.context.owner
      if self_type
        lookup_arg_types = Array(Type).new(match.arg_types.size + 1)
        lookup_arg_types.push self_type
        lookup_arg_types.concat match.arg_types
      else
        lookup_arg_types = match.arg_types
      end
      match_owner = match.context.owner
      def_instance_owner = self_type || match_owner

      if named_args = @named_args
        named_args_key = named_args.map { |named_arg| {named_arg.name, named_arg.value.type} }
      else
        named_args_key = nil
      end

      def_instance_key = DefInstanceKey.new(match.def.object_id, lookup_arg_types, block_type, named_args_key)
      typed_def = def_instance_owner.lookup_def_instance def_instance_key if use_cache
      unless typed_def
        typed_def, typed_def_args = prepare_typed_def_with_args(match.def, match_owner, lookup_self_type, match.arg_types, block_arg_type)
        def_instance_owner.add_def_instance(def_instance_key, typed_def) if use_cache

        if typed_def.macro_def?
          return_type = typed_def.return_type.not_nil!
          typed_def.type = TypeLookup.lookup(match.def.macro_owner.not_nil!, return_type, match_owner.instance_type)
          mod.push_def_macro typed_def
        else
          if typed_def_return_type = typed_def.return_type
            check_return_type(typed_def, typed_def_return_type, match, match_owner)
          end

          check_recursive_splat_call match.def, typed_def_args do
            bubbling_exception do
              visitor = MainVisitor.new(mod, typed_def_args, typed_def)
              visitor.yield_vars = yield_vars
              visitor.free_vars = match.context.free_vars
              visitor.untyped_def = match.def
              visitor.call = self
              visitor.scope = lookup_self_type
              visitor.type_lookup = match.context.type_lookup

              yields_to_block = block && !match.def.uses_block_arg

              if yields_to_block
                raise_if_block_too_nested(match.def.block_nest)
                match.def.block_nest += 1
              end

              typed_def.body.accept visitor

              if yields_to_block
                match.def.block_nest -= 1
              end

              if visitor.is_initialize
                visitor.bind_initialize_instance_vars(owner)
              end
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
    self_type = match_owner.instance_type
    root_type = self_type.ancestors.find(&.instance_of?(match.def.owner.instance_type)) || self_type
    return_type = TypeLookup.lookup(root_type, typed_def_return_type, match_owner.instance_type).virtual_type
    typed_def.freeze_type = return_type
  end

  def check_tuple_indexer(owner, def_name, args, arg_types)
    return unless args.size == 1 && def_name == "[]"

    if owner.is_a?(TupleInstanceType)
      tuple_indexer_helper(args, arg_types, owner, owner) do |instance_type, index|
        instance_type.tuple_indexer(index)
      end
    elsif owner.metaclass? && (instance_type = owner.instance_type).is_a?(TupleInstanceType)
      tuple_indexer_helper(args, arg_types, owner, instance_type) do |instance_type, index|
        instance_type.tuple_metaclass_indexer(index)
      end
    end
  end

  def tuple_indexer_helper(args, arg_types, owner, instance_type)
    arg = args.first
    if arg.is_a?(NumberLiteral) && arg.kind == :i32
      index = arg.value.to_i
      if 0 <= index < instance_type.tuple_types.size
        indexer_def = yield instance_type, index
        indexer_match = Match.new(indexer_def, arg_types, MatchContext.new(owner, owner))
        return Matches.new([indexer_match] of Match, true)
      else
        raise "index out of bounds for tuple #{owner}"
      end
    end
    nil
  end

  def replace_splats
    return unless args.any? &.is_a?(Splat)

    new_args = [] of ASTNode
    args.each_with_index do |arg, i|
      if arg.is_a?(Splat)
        arg_type = arg.type
        unless arg_type.is_a?(TupleInstanceType)
          arg.raise "splat expects a tuple, not #{arg_type}"
        end
        arg_type.tuple_types.each_index do |index|
          num = NumberLiteral.new(index)
          num.type = mod.int32
          tuple_indexer = Call.new(arg.exp, "[]", num)
          parent_visitor.prepare_call(tuple_indexer)
          tuple_indexer.recalculate
          new_args << tuple_indexer
          arg.remove_input_observer(self)
        end
      else
        new_args << arg
      end
    end
    self.args = new_args
  end

  def replace_block_arg_with_block(block_arg)
    block_arg_type = block_arg.type
    if block_arg_type.is_a?(FunInstanceType)
      vars = [] of Var
      args = [] of ASTNode
      block_arg_type.arg_types.map_with_index do |type, i|
        arg = Var.new("__arg#{i}")
        vars << arg
        args << arg
      end
      block = Block.new(vars, Call.new(block_arg.clone, "call", args))
      block.vars = self.before_vars
      self.block = block
    else
      block_arg.raise "expected a function type, not #{block_arg.type}"
    end
  end

  def lookup_matches_in_super(arg_types)
    if scope.is_a?(Program)
      raise "there's no superclass in this scope"
    end

    enclosing_def = enclosing_def()

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
      index_of_ancestor = ancestors.index { |ancestor| ancestor.is_a?(IncludedGenericModule) && ancestor.module == lookup }.not_nil!
      parents = ancestors[index_of_ancestor + 1..-1]
    when GenericType
      ancestors = parent_visitor.scope.ancestors
      index_of_ancestor = ancestors.index { |ancestor| ancestor.is_a?(InheritedGenericClass) && ancestor.extended_class == lookup }
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
          return lookup_matches_in_type(parent, arg_types, scope, enclosing_def.name, !in_initialize)
        end
      end
      lookup_matches_in_type(parents.last, arg_types, scope, enclosing_def.name, !in_initialize)
    else
      raise "there's no superclass in this scope"
    end
  end

  def lookup_previous_def_matches(arg_types)
    enclosing_def = enclosing_def()

    previous_item = enclosing_def.previous
    unless previous_item
      return raise "there is no previous definition of '#{enclosing_def.name}'"
    end

    previous = previous_item.def

    signature = CallSignature.new(previous.name, arg_types, block, named_args)
    context = MatchContext.new(scope, scope)
    match = Match.new(previous, arg_types, context)
    matches = Matches.new([match] of Match, true)

    unless MatchesLookup.match_def(signature, previous_item, context)
      raise_matches_not_found scope, previous.name, matches
    end

    unless scope.is_a?(Program)
      parent_visitor.check_self_closured
    end

    typed_defs = instantiate matches, scope
    typed_defs.each do |typed_def|
      typed_def.next = parent_visitor.typed_def
    end
    typed_defs
  end

  def enclosing_def
    fun_literal_context = parent_visitor.fun_literal_context
    if fun_literal_context.is_a?(Def)
      fun_literal_context
    else
      parent_visitor.untyped_def
    end
  end

  def on_new_subclass
    # @types_signature = nil
    recalculate
  end

  def lookup_macro
    in_macro_target &.lookup_macro(name, args.size, named_args)
  end

  def in_macro_target
    if with_scope = @with_scope
      with_scope = with_scope.metaclass unless with_scope.metaclass?
      macros = yield with_scope
      return macros if macros
    end

    node_scope = scope
    node_scope = node_scope.base_type if node_scope.is_a?(VirtualType)
    node_scope = node_scope.metaclass unless node_scope.metaclass?

    macros = yield node_scope
    if !macros && node_scope.metaclass? && node_scope.instance_type.module?
      macros = yield mod.object.metaclass
    end

    macros ||= yield mod

    if !macros && (location = self.location) && (filename = location.original_filename).is_a?(String) && (file_module = mod.file_module?(filename))
      macros ||= yield file_module
    end

    macros
  end

  # Match the given block with the given block argument specification (&block : A, B, C -> D)
  def match_block_arg(match)
    block_arg = match.def.block_arg
    return nil, nil unless block_arg
    return nil, nil unless match.def.yields || match.def.uses_block_arg

    yield_vars = nil
    block_arg_type = nil

    block = @block.not_nil!
    ident_lookup = MatchTypeLookup.new(self, match.context)

    block_arg_restriction = block_arg.restriction

    # If the block spec is &block : A, B, C -> D, we solve the argument types
    if block_arg_restriction.is_a?(Fun)
      # If there are input types, solve them and creating the yield vars
      if inputs = block_arg_restriction.inputs
        yield_vars = inputs.map_with_index do |input, i|
          arg_type = ident_lookup.lookup_node_type(input)
          MainVisitor.check_type_allowed_as_proc_argument(input, arg_type)

          Var.new("var#{i}", arg_type.virtual_type)
        end
      end
      output = block_arg_restriction.output
    elsif block_arg_restriction
      # Otherwise, the block spec could be something like &block : Foo, and that
      # is valid too only if Foo is an alias/typedef that referes to a FunctionType
      block_arg_type = ident_lookup.lookup_node_type(block_arg_restriction).remove_typedef
      unless block_arg_type.is_a?(FunInstanceType)
        block_arg_restriction.raise "expected block type to be a function type, not #{block_arg_type}"
        return nil, nil
      end

      yield_vars = block_arg_type.arg_types.map_with_index do |input, i|
        Var.new("var#{i}", input)
      end
      output = block_arg_type.return_type
      output_type = output
    end

    # Bind block arguments to the yield vars, if any, or to nil otherwise
    block.args.each_with_index do |arg, i|
      arg.bind_to(yield_vars.try(&.[i]?) || mod.nil_var)
    end

    # If the block is used, we convert it to a function pointer
    if match.def.uses_block_arg
      # Create the arguments of the function literal
      if yield_vars
        fun_args = yield_vars.map_with_index do |var, i|
          arg_name = block.args[i]?.try(&.name) || mod.new_temp_var_name
          Arg.new(arg_name, type: var.type)
        end
      else
        fun_args = [] of Arg
      end

      if output.is_a?(ASTNode) && !output.is_a?(Underscore)
        output_type = ident_lookup.lookup_node_type?(output).try &.virtual_type
      end

      # Check if the call has a block arg (foo &bar). If so, we need to see if the
      # passed block has the same signature as the def's block arg. We use that
      # same FunLiteral (bar) for this call.
      fun_literal = block.fun_literal
      unless fun_literal
        if call_block_arg = self.block_arg
          check_call_block_arg_matches_def_block_arg(call_block_arg, yield_vars)
          fun_literal = call_block_arg
        else
          # Otherwise, we create a FunLiteral and type it
          if block.args.size > fun_args.size
            wrong_number_of "block arguments", block.args.size, fun_args.size
          end

          a_def = Def.new("->", fun_args, block.body)
          a_def.captured_block = true

          fun_literal = FunLiteral.new(a_def).at(self)
          fun_literal.expected_return_type = output_type if output_type
          fun_literal.force_void = true unless output
          fun_literal.accept parent_visitor
        end
        block.fun_literal = fun_literal
      end

      # Now check if the FunLiteral's type (the block's type) matches the block arg specification.
      # If not, we delay it for later and compute the type based on the block arg return type, if any.
      fun_literal_type = fun_literal.type?
      if fun_literal_type
        block_arg_type = fun_literal_type
        block_type = (fun_literal_type as FunInstanceType).return_type
        if output
          matched = MatchesLookup.match_arg(block_type, output, match.context)
          if !matched && !void_return_type?(match.context, output)
            if output.is_a?(ASTNode) && !output.is_a?(Underscore) && block_type.no_return?
              block_type = ident_lookup.lookup_node_type(output).virtual_type
              block.type = output_type || block_type
              block.freeze_type = output_type || block_type
              block_arg_type = mod.fun_of(fun_args, block_type)
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
          if output.is_a?(ASTNode) && !output.is_a?(Underscore)
            output_type = ident_lookup.lookup_node_type(output).virtual_type
            block.type = output_type
            block.freeze_type = output_type
            block_arg_type = mod.fun_of(fun_args, output_type)
          else
            cant_infer_block_return_type
          end
        else
          block.body.type = mod.void
          block.type = mod.void
          block_arg_type = mod.fun_of(fun_args, mod.void)
        end
      end

      # Because the block's type might be used as a free variable, we bind
      # ourself to the block so when its type changes we recalculate ourself.
      if output
        block.try &.remove_input_observer(self)
        block.try &.add_input_observer(self)
      end
    else
      block.accept parent_visitor

      # Similar to above: we check that the block's type matches the block arg specification,
      # and we delay it if possible.
      if output
        if !block.type?
          if output.is_a?(ASTNode) && !output.is_a?(Underscore)
            begin
              block_type = ident_lookup.lookup_node_type(output).virtual_type
            rescue ex : Crystal::Exception
              cant_infer_block_return_type
            end
          else
            cant_infer_block_return_type
          end
        else
          block_type = block.type
          matched = MatchesLookup.match_arg(block_type, output, match.context)
          if !matched && !void_return_type?(match.context, output)
            if output.is_a?(ASTNode) && !output.is_a?(Underscore)
              begin
                block_type = ident_lookup.lookup_node_type(output).virtual_type
              rescue ex : Crystal::Exception
                if block_type
                  raise "couldn't match #{block_type} to #{output}", ex
                else
                  cant_infer_block_return_type
                end
              end
            else
              if output.is_a?(Self)
                raise "expected block to return #{match.context.owner}, not #{block_type}"
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
    call_block_arg_types = (call_block_arg.type as FunInstanceType).arg_types
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
      type = match_context.type_lookup.lookup_type(output)
    else
      type = output
    end

    type.is_a?(Type) && type.void?
  end

  private def cant_infer_block_return_type
    raise "can't infer block return type, try to cast the block body with `as`. See: https://github.com/crystal-lang/crystal/wiki/Compiler-error-messages#cant-infer-block-return-type"
  end

  class MatchTypeLookup < TypeLookup
    @call : Call
    @context : MatchContext

    def initialize(@call, @context)
      super(@context.type_lookup)
    end

    def visit(node : Path)
      if node.names.size == 1 && @context.free_vars
        if type = @context.get_free_var(node.names.first)
          @type = type
          return
        end
      end

      super
    end

    def visit(node : Self)
      @type = @context.owner
      false
    end

    def lookup_node_type(node)
      @type = nil
      @call.bubbling_exception do
        node.accept self
      end
      type
    end

    def lookup_node_type?(node)
      @type = nil
      @raise, old_raise = false, @raise
      node.accept self
      @raise = old_raise
      @type
    end
  end

  def bubbling_exception
    begin
      yield
    rescue ex : Crystal::Exception
      if obj = @obj
        raise "instantiating '#{obj.type}##{name}(#{args.map(&.type).join ", "})'", ex
      else
        raise "instantiating '#{name}(#{args.map(&.type).join ", "})'", ex
      end
    end
  end

  def obj_and_args_types_set?
    obj = @obj
    block_arg = @block_arg
    named_args = @named_args

    unless args.all? &.type?
      return false
    end

    if obj && !obj.type?
      return false
    end

    if block_arg && !block_arg.type?
      return false
    end

    if named_args && named_args.any? { |arg| !arg.value.type? }
      return false
    end

    true
  end

  def prepare_typed_def_with_args(untyped_def, owner, self_type, arg_types, block_arg_type)
    named_args = @named_args

    # If there's an argument count mismatch, or we have a splat, or there are
    # named arguments, we create another def that sets ups everything for the real call.
    if arg_types.size != untyped_def.args.size || untyped_def.splat_index || named_args
      named_args_names = named_args.try &.map &.name
      untyped_def = untyped_def.expand_default_arguments(mod, arg_types.size, named_args_names)
    end

    args_start_index = 0

    typed_def = untyped_def.clone
    typed_def.owner = owner
    typed_def.original_owner = untyped_def.owner

    if body = typed_def.body
      typed_def.bind_to body
    end

    args = MetaVars.new

    if self_type # .is_a?(Type)
      args["self"] = MetaVar.new("self", self_type)
    end

    strict_check = body.is_a?(Primitive) && body.name == :fun_call

    arg_types.each_index do |index|
      arg = typed_def.args[index]
      type = arg_types[args_start_index + index]
      var = MetaVar.new(arg.name, type).at(arg.location)
      var.bind_to(var)
      args[arg.name] = var

      if strict_check
        unless type.covariant?(arg.type)
          self.args[index].raise "type must be #{arg.type}, not #{type}"
        end
      end

      arg.type = type
    end

    # Fill magic constants (__LINE__, __FILE__, __DIR__)
    named_args_size = named_args.try(&.size) || 0
    (arg_types.size + named_args_size).upto(typed_def.args.size - 1) do |index|
      arg = typed_def.args[index]
      default_value = arg.default_value as MagicConstant
      case default_value.name
      when :__LINE__
        type = mod.int32
      when :__FILE__, :__DIR__
        type = mod.string
      else
        default_value.raise "Bug: unknown magic constant: #{default_value.name}"
      end
      var = MetaVar.new(arg.name, type).at(arg.location)
      var.bind_to(var)
      args[arg.name] = var
      arg.type = type
    end

    named_args.try &.each do |named_arg|
      type = named_arg.value.type
      var = MetaVar.new(named_arg.name, type).at(named_arg.value.location)
      var.bind_to(var)
      args[named_arg.name] = var
      arg = typed_def.args.find { |arg| arg.name == named_arg.name }.not_nil!
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

  def attach_subclass_observer(type)
    detach_subclass_observer
    type.add_subclass_observer(self)
    @subclass_notifier = type
  end

  def detach_subclass_observer
    @subclass_notifier.try &.remove_subclass_observer(self)
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
