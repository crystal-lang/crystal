require "../syntax/ast"
require "../types"
require "../primitives"
require "../similar_name"
require "./type_lookup"

class Crystal::Call
  property! scope
  property! parent_visitor
  property target_defs
  property expanded
  property? is_expansion
  @is_expansion = false

  def mod
    scope.program
  end

  def target_def
    if defs = @target_defs
      if defs.length == 1
        return defs.first
      else
        ::raise "#{defs.length} target defs for #{self}"
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
      set_type mod.no_return
      return
    end

    return unless obj_and_args_types_set?

    block = @block

    unbind_from @target_defs if @target_defs
    unbind_from block.break if block
    detach_subclass_observer

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

    if (parent_visitor = @parent_visitor) && parent_visitor.typed_def? && matches && matches.any?(&.raises)
      parent_visitor.typed_def.raises = true
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
    arg_types = Array(Type).new(args.length * 2)
    args.each do |arg|
      if arg.is_a?(Splat)
        if (arg_type = arg.type).is_a?(TupleInstanceType)
          arg_types.concat arg_type.tuple_types
        else
          arg.raise "splatting a union (#{arg_type}) is not yet supported"
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
    else
      lookup_matches_in scope, arg_types
    end
  end

  def lookup_matches_in(owner : AliasType, arg_types)
    lookup_matches_in(owner.remove_alias, arg_types)
  end

  def lookup_matches_in(owner : UnionType, arg_types)
    owner.union_types.flat_map { |type| lookup_matches_in(type, arg_types) }
  end

  def lookup_matches_in(owner : Program, arg_types, self_type = nil, def_name = self.name)
    lookup_matches_in_type(owner, arg_types, self_type, def_name)
  end

  def lookup_matches_in(owner : FileModule, arg_types)
    lookup_matches_in mod, arg_types
  end

  def lookup_matches_in(owner : NonGenericModuleType, arg_types)
    including_types = owner.including_types
    if including_types
      attach_subclass_observer owner

      lookup_matches_in(including_types, arg_types)
    else
      raise "no type includes #{owner}"
    end
  end

  def lookup_matches_in(owner : GenericClassType, arg_types)
    including_types = owner.including_types
    if including_types
      attach_subclass_observer owner

      lookup_matches_in(including_types, arg_types)
    else
      raise "no type inherits #{owner}"
    end
  end

  def lookup_matches_in(owner : AbstractValueType, arg_types)
    attach_subclass_observer owner
    lookup_matches_in(owner.including_types, arg_types)
  end

  def lookup_matches_in(owner : LibType, arg_types, self_type = nil, def_name = self.name)
    raise "lib fun call is not supported in dispatch"
  end

  def lookup_matches_in(owner : Type, arg_types, self_type = nil, def_name = self.name)
    lookup_matches_in_type(owner, arg_types, self_type, def_name)
  end

  def lookup_matches_in_type(owner, arg_types, self_type, def_name)
    signature = CallSignature.new(def_name, arg_types, block, named_args)

    matches = check_tuple_indexer(owner, def_name, args, arg_types)

    unless matches
      # If this call is an expansion (because of default or named args) we must
      # resolve the call in the type that defined the original method, without
      # triggering a virtual lookup. But the context of lookup must be preseved.
      if is_expansion?
        matches = bubbling_exception { parent_visitor.typed_def.original_owner.lookup_matches signature }
        matches.each do |match|
          match.context.owner = owner
          match.context.type_lookup = owner
        end
      else
        matches = bubbling_exception { lookup_matches_with_signature(owner, signature) }
      end
    end

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
        mod_matches = lookup_matches_with_signature(mod, signature)
        matches = mod_matches unless mod_matches.empty?
      end
    end

    if matches.empty? && owner.class? && owner.abstract && name != "super"
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
        raise_matches_not_found(matches.owner || owner, def_name, matches)
      end
    end

    # If this call is an implicit call to self
    if !obj && !mod_matches && !owner.is_a?(Program)
      parent_visitor.check_self_closured
    end

    if owner.is_a?(VirtualType)
      attach_subclass_observer owner.base_type
    end

    instantiate matches, owner, self_type
  end

  def lookup_matches_in(owner : Nil, arg_types)
    raise "Bug: trying to lookup matches in nil in #{self}"
  end

  def lookup_matches_with_signature(owner : Program, signature)
    location = self.location
    if location && (filename = location.filename).is_a?(String)
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

  def lookup_matches_with_signature(owner, signature)
    owner.lookup_matches signature
  end

  def instantiate(matches, owner, self_type = nil)
    block = @block

    typed_defs = Array(Def).new(matches.length)

    matches.each do |match|
      # Discard abstract defs for abstract classes
      next if match.def.abstract && match.context.owner.abstract

      check_visibility match
      check_not_abstract match

      yield_vars = match_block_arg(match)
      use_cache = !block || match.def.block_arg

      if block && match.def.block_arg
        block_type = block.fun_literal.try(&.type) || block.body.type?
        use_cache = false unless block_type
      end

      lookup_self_type = self_type || match.context.owner
      if self_type
        lookup_arg_types = Array(Type).new(match.arg_types.length + 1)
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
        typed_def, typed_def_args = prepare_typed_def_with_args(match.def, match_owner, lookup_self_type, match.arg_types)
        def_instance_owner.add_def_instance(def_instance_key, typed_def) if use_cache
        if return_type = typed_def.return_type
          typed_def.type = TypeLookup.lookup(match.def.macro_owner.not_nil!, return_type, match_owner.instance_type)
          mod.push_def_macro typed_def
        else
          check_recursive_splat_call match.def, typed_def_args do
            bubbling_exception do
              visitor = TypeVisitor.new(mod, typed_def_args, typed_def)
              visitor.yield_vars = yield_vars
              visitor.free_vars = match.context.free_vars
              visitor.untyped_def = match.def
              visitor.call = self
              visitor.scope = lookup_self_type
              visitor.type_lookup = match.context.type_lookup
              typed_def.body.accept visitor

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

  def check_tuple_indexer(owner, def_name, args, arg_types)
    if owner.is_a?(TupleInstanceType) && def_name == "[]" && args.length == 1
      arg = args.first
      if arg.is_a?(NumberLiteral) && arg.kind == :i32
        index = arg.value.to_i
        if 0 <= index < owner.tuple_types.length
          indexer_def = owner.tuple_indexer(index)
          indexer_match = Match.new(indexer_def, arg_types, MatchContext.new(owner, owner))
          return Matches.new([indexer_match] of Match, true)
        else
          raise "index out of bounds for tuple #{owner}"
        end
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
          tuple_indexer = Call.new(arg.exp, "[]", NumberLiteral.new(index))
          tuple_indexer.accept parent_visitor
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
      block = Block.new(vars, Call.new(block_arg, "call", args))
      block.vars = self.before_vars
      self.block = block
    else
      block_arg.raise "expected a function type, not #{block_arg.type}"
    end
  end

  def find_owner_trace(node, owner)
    owner_trace = [] of ASTNode

    visited = Set(typeof(object_id)).new
    visited.add node.object_id
    while deps = node.dependencies?
      dependencies = deps.select { |dep| dep.type? && dep.type.includes_type?(owner) && !visited.includes?(dep.object_id) }
      if dependencies.length > 0
        node = dependencies.first
        owner_trace << node if node
        visited.add node.object_id
      else
        break
      end
    end

    MethodTraceException.new(owner, owner_trace)
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
      parents = lookup.base_type.parents
    when GenericType
      parents = parent_visitor.typed_def.owner.parents
    else
      parents = lookup.parents
    end

    if parents && parents.length > 0
      parents_length = parents.length
      parents.each_with_index do |parent, i|
        if i == parents_length - 1 || parent.lookup_first_def(enclosing_def.name, block)
          return lookup_matches_in(parent, arg_types, scope, enclosing_def.name)
        end
      end
    end

    nil
  end

  def lookup_previous_def_matches(arg_types)
    enclosing_def = enclosing_def()

    previous = enclosing_def.previous
    unless previous
      raise "there is no previous definition of '#{enclosing_def.name}'"
    end

    unless scope.is_a?(Program)
      parent_visitor.check_self_closured
    end

    match = Match.new(previous, arg_types, MatchContext.new(scope, scope))
    matches = Matches.new([match] of Match, true)
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
    in_macro_target &.lookup_macro(name, args.length, named_args)
  end

  def in_macro_target
    node_scope = scope
    node_scope = node_scope.metaclass unless node_scope.metaclass?

    macros = yield node_scope
    if !macros && node_scope.metaclass? && node_scope.instance_type.module?
      macros = yield mod.object.metaclass
    end
    macros ||= yield mod
    macros
  end

  def match_block_arg(match)
    block_arg = match.def.block_arg
    return unless block_arg
    return unless ((yields = match.def.yields) && yields > 0) || match.def.uses_block_arg

    yield_vars = nil

    block = @block.not_nil!
    ident_lookup = MatchTypeLookup.new(match.context)

    block_arg_fun = block_arg.fun
    if block_arg_fun.is_a?(Fun)
      if inputs = block_arg_fun.inputs
        yield_vars = inputs.map_with_index do |input, i|
          type = ident_lookup.lookup_node_type(input)
          type = type.virtual_type
          Var.new("var#{i}", type)
        end
        block.args.each_with_index do |arg, i|
          arg.bind_to(yield_vars[i]? || mod.nil_var)
        end
      else
        block.args.each &.bind_to(mod.nil_var)
      end
      block_arg_fun_output = block_arg_fun.output
    else
      block_arg_type = ident_lookup.lookup_node_type(block_arg_fun)
      unless block_arg_type.is_a?(FunInstanceType)
        block_arg_fun.raise "expected block type to be a function type, not #{block_arg_type}"
        return
      end

      yield_vars = block_arg_type.arg_types.map_with_index do |input, i|
        Var.new("var#{i}", input)
      end
      block.args.each_with_index do |arg, i|
        arg.bind_to(yield_vars[i]? || mod.nil_var)
      end
      block_arg_fun_output = block_arg_type.return_type
    end

    if match.def.uses_block_arg
      # Automatically convert block to function pointer
      if yield_vars
        fun_args = yield_vars.map_with_index do |var, i|
          arg_name = block.args[i]?.try(&.name) || mod.new_temp_var_name
          Arg.new(arg_name, type: var.type)
        end
      else
        fun_args = [] of Arg
      end

      # But first check if the call has a block_arg
      if call_block_arg = self.block_arg
        # Check input types
        call_block_arg_types = (call_block_arg.type as FunInstanceType).arg_types
        if yield_vars
          if yield_vars.length != call_block_arg_types.length
            raise "wrong number of block argument's arguments (#{call_block_arg_types.length} for #{yield_vars.length})"
          end

          i = 1
          yield_vars.zip(call_block_arg_types) do |yield_var, call_block_arg_type|
            if yield_var.type != call_block_arg_type
              raise "expected block argument's argument ##{i} to be #{yield_var.type}, not #{call_block_arg_type}"
            end
            i += 1
          end
        elsif call_block_arg_types.length != 0
          raise "wrong number of block argument's arguments (#{call_block_arg_types.length} for 0)"
        end

        fun_literal = call_block_arg
      else
        if block.args.length > fun_args.length
          raise "wrong number of block arguments (#{block.args.length} for #{fun_args.length})"
        end

        fun_def = Def.new("->", fun_args, block.body)
        fun_literal = FunLiteral.new(fun_def)

        unless block_arg_fun_output
          fun_literal.force_void = true
        end

        fun_literal.accept parent_visitor
      end

      block.fun_literal = fun_literal

      fun_literal_type = fun_literal.type?
      if fun_literal_type
        if output = block_arg_fun_output
          block_type = (fun_literal_type as FunInstanceType).return_type
          matched = MatchesLookup.match_arg(block_type, output, match.context)
          unless matched
            raise "expected block to return #{output}, not #{block_type}"
          end
        end
      else
        if block_arg_fun_output
          cant_infer_block_return_type
        else
          block.body.type = mod.void
        end
      end
    else
      block.accept parent_visitor

      if output = block_arg_fun_output
        unless block.body.type?
          cant_infer_block_return_type
        end

        block_type = block.body.type
        matched = MatchesLookup.match_arg(block_type, output, match.context)
        unless matched
          if output.is_a?(Self)
            raise "expected block to return #{match.context.owner}, not #{block_type}"
          else
            raise "expected block to return #{output}, not #{block_type}"
          end
        end
        block.body.freeze_type = block_type
      end
    end

    yield_vars
  end

  private def cant_infer_block_return_type
    raise "can't infer block return type, try to cast the block body with `as`. See: https://github.com/manastech/crystal/wiki/Compiler-error-messages#cant-infer-block-return-type"
  end

  class MatchTypeLookup < TypeLookup
    def initialize(@context)
      super(@context.type_lookup)
    end

    def visit(node : Path)
      if node.names.length == 1 && @context.free_vars
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
      node.accept self
      type
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

  def full_name(owner, def_name = name)
    owner.is_a?(Program) ? name : "#{owner}##{def_name}"
  end

  def prepare_typed_def_with_args(untyped_def, owner, self_type, arg_types)
    named_args = @named_args

    # If there's an argument count mismatch, or we have a splat, or there are
    # named arguments, we create another def that sets ups everything for the real call.
    if arg_types.length != untyped_def.args.length || untyped_def.splat_index || named_args
      named_args_names = named_args.try &.map &.name
      untyped_def = untyped_def.expand_default_arguments(arg_types.length, named_args_names)
    end

    args_start_index = 0

    typed_def = untyped_def.clone
    typed_def.owner = owner
    typed_def.original_owner = untyped_def.owner

    if body = typed_def.body
      typed_def.bind_to body
    end

    args = MetaVars.new

    if self_type#.is_a?(Type)
      args["self"] = MetaVar.new("self", self_type)
    end

    arg_types.each_index do |index|
      arg = typed_def.args[index]
      type = arg_types[args_start_index + index]
      var = MetaVar.new(arg.name, type).at(arg.location)
      var.bind_to(var)
      args[arg.name] = var
      arg.type = type
    end

    # Fill magic constants (__LINE__, __FILE__, __DIR__)
    named_args_length = named_args.try(&.length) || 0
    (arg_types.length + named_args_length).upto(typed_def.args.length - 1) do |index|
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
    if fun_literal
      block_arg = untyped_def.block_arg.not_nil!
      var = MetaVar.new(block_arg.name, fun_literal.type)
      args[block_arg.name] = var

      typed_def.block_arg.not_nil!.type = fun_literal.type
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
end
