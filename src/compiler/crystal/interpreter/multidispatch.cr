require "./repl"
require "../semantic/main_visitor"

# Non-interpreted Crystal does multidispatch by essentially
# inlining `is_a?` calls and performing the appropriate casting
# and calling.
#
# For the interpreter this is a bit hard to do because it's a stack-based VM,
# so it's hard to get access to stack values that are not at the top
# of the stack.
#
# So, for interpreted mode, when there's a dispatch, we actually create
# a method that will do the dispatch, and we call that method.
# For example, if we have this code:
#
# ```
# def foo(x : Int32)
# end
#
# def foo(x : Char)
# end
#
# a = 1 || 'a'
# foo(a)
# ```
#
# The call to `foo` is actually delegated to another `foo` method
# that will do the dispatch, created in this file:
#
# ```
# def foo(x)
#   if x.is_a?(Int32)
#     foo(x)
#   elsif x.is_a?(Char)
#     foo(x)
#   else
#     unreachable
#   end
# end
# ```
module Crystal::Repl::Multidispatch
  def self.create_def(context : Context, node : Call, target_defs : Array(Def))
    if node.block
      a_def = create_def_uncached(context, node, target_defs)

      # Store it so the GC doesn't collect it (it's in the instructions but it might not be aligned)
      context.add_gc_reference(a_def)

      return a_def
    end

    obj = node.obj
    obj_type = obj.try(&.type) || node.scope

    signature = CallSignature.new(
      name: node.name,
      arg_types: node.args.map(&.type),
      named_args: nil,
      block: node.block,
    )

    cache_key = Context::MultidispatchKey.new(obj_type, signature)
    cached_def = context.multidispatchs[cache_key]?
    return cached_def if cached_def

    a_def = create_def_uncached(context, node, target_defs)

    context.multidispatchs[cache_key] = a_def

    a_def
  end

  private def self.create_def_uncached(context : Context, node : Call, target_defs : Array(Def))
    autocast_types = nil

    # The generated multidispatch method should handle autocasted
    # values. For example if an argument is a symbol but the target
    # type is an enum, the multidispatch should handle enum values,
    # not symbols. Autocasting will naturally happen right before
    # the multidispatch is called.

    # Here we track which args perform autocasting.
    node.args.each_with_index do |arg, i|
      # Autocasting only happens from SymbolLiteral or NumberLiteral
      next unless arg.is_a?(SymbolLiteral) || arg.is_a?(NumberLiteral)

      non_matching_type = nil

      # Check if the call arg type is passed to a method arg type
      # where the types don't match. That's when autocasting happens.
      target_defs.each do |target_def|
        arg_type = target_def.args[i].type
        if arg_type != arg.type
          non_matching_type = arg_type
          break
        end
      end

      if non_matching_type
        autocast_types ||= {} of Int32 => Type
        autocast_types[i] = non_matching_type
      end
    end

    obj = node.obj
    obj_type = obj.try(&.type) || node.scope

    a_def = Def.new(node.name).at(node)

    unless obj_type.is_a?(Program)
      self_arg = Arg.new("self").at(node)
      self_arg.type = obj_type
      a_def.args << self_arg
    end

    all_special_vars = nil

    i = 0

    node.args.each_with_index do |arg, arg_index|
      def_arg = Arg.new("arg#{i}").at(node)
      def_arg.type = autocast_types.try &.[arg_index]? || arg.type
      a_def.args << def_arg
      i += 1
    end

    block = node.block
    block_fun_literal = block.try(&.fun_literal)

    if block
      if block_fun_literal
        a_def.block_arg = Arg.new("block_arg")
        a_def.uses_block_arg = true
      else
        a_def.block_arg = Arg.new("")
        a_def.block_arity = block.args.size
      end
    end

    main_if = nil
    current_if = nil

    blocks = [] of Block

    target_defs.each_with_index do |target_def, target_def_index|
      i = 0

      condition = nil

      unless obj_type.is_a?(Program)
        unless obj_type.implements?(target_def.owner)
          condition = IsA.new(Var.new("self"), TypeNode.new(target_def.owner))
        end
      end

      node.args.each_with_index do |arg, arg_index|
        # If the argument was autocasted it will always match in a multidispatch
        next if autocast_types.try &.[arg_index]?

        target_def_arg = target_def.args[i]
        condition = add_arg_condition(arg, target_def_arg, i, condition)

        i += 1
      end

      condition ||= BoolLiteral.new(true)

      call_args = [] of ASTNode

      i = 0
      node.args.each_with_index do |arg, arg_index|
        var = Var.new("arg#{i}")

        # If the argument was autocasted it will always match in a multidispatch
        if autocast_types.try &.[arg_index]?
          call_args << var
          i += 1
          next
        end

        # Make sure to cast the argument to the target def arg's type
        # in the last case, where the argument's type is not restricted by an if is_a?
        if target_def_index == target_defs.size - 1
          target_def_arg = target_def.args[i]

          cast = Cast.new(var, TypeNode.new(target_def_arg.type))
          call_args << cast
        else
          call_args << var
        end

        i += 1
      end

      call_obj =
        if obj_type.is_a?(Program)
          nil
        else
          Var.new("self")
        end

      call = Call.new(call_obj, node.name, call_args)
      call.target_defs = [target_def]
      call.type = target_def.type

      if block
        if block_fun_literal
          # We aren't going to recaluclate calls, so we prepare the call
          # in a way that the interpreter is going to call it by passing
          # the block_arg as an extra argument.
          inner_block = Block.new
          inner_block_fun_literal = Var.new("block_arg")
          inner_block_fun_literal.type = block_fun_literal.type
          inner_block.fun_literal = inner_block_fun_literal
          call.block = inner_block
        else
          block_args = block.args.map_with_index { |arg, i| Var.new("barg#{i}", arg.type) }
          yield_args = Array(ASTNode).new(block_args.size)
          block.args.each_index { |i| yield_args << Var.new("barg#{i}", block.args[i].type) }

          inner_block = Block.new(block_args, body: Yield.new(yield_args))
          blocks << inner_block

          call.block = inner_block
        end
      end

      exps = call

      special_vars = target_def.special_vars
      if special_vars
        # What we do is something like this:
        #
        # ```
        # .value = call(...)
        # $~ = $~
        # .value
        # ```
        all_special_vars ||= Set(String).new
        all_special_vars.concat(special_vars)

        assign = Assign.new(Var.new(".value"), call)
        expressions = [assign] of ASTNode
        special_vars.each do |special_var|
          expressions << Assign.new(Var.new(special_var), Var.new(special_var))
        end
        expressions << Var.new(".value")
        exps = Expressions.new(expressions)
      end

      target_def_if = If.new(condition, exps)

      if current_if
        current_if.else = target_def_if
        current_if = target_def_if
      else
        main_if = target_def_if
        current_if = target_def_if
      end
    end

    current_if = current_if.not_nil!
    current_if.else = Unreachable.new

    main_if = main_if.not_nil!
    a_def.body = main_if
    a_def.special_vars = all_special_vars

    a_def = context.program.normalize(a_def)
    a_def.owner = obj_type

    def_args = MetaVars.new

    unless obj_type.is_a?(Program)
      def_args["self"] = MetaVar.new("self", obj_type)
    end

    i = 0

    node.args.each_with_index do |arg, arg_index|
      def_args["arg#{i}"] = MetaVar.new(
        "arg#{i}",
        autocast_types.try &.[arg_index]? || arg.type
      )
      i += 1
    end

    if block_fun_literal
      def_args["block_arg"] = MetaVar.new("block_arg", block_fun_literal.type)
    end

    visitor = MultidispatchMainVisitor.new(context.program, def_args, a_def)
    visitor.untyped_def = a_def
    visitor.call = node

    # puts a_def

    # visitor.scope = obj_type
    # visitor.yield_vars = yield_vars
    # visitor.match_context = match.context
    # visitor.call = self
    # visitor.path_lookup = match.context.defining_type
    a_def.body.accept visitor

    # Because we skipped recalculating calls, the blocks weren't visited.
    # We do this now.
    blocks.each &.accept visitor

    a_def.bind_to(a_def.body)

    a_def.body = context.program.cleanup(a_def.body, inside_def: true)

    a_def
  end

  private def self.add_arg_condition(arg, target_def_arg, i, condition)
    unless arg.type.implements?(target_def_arg.type)
      is_a = IsA.new(Var.new("arg#{i}"), TypeNode.new(target_def_arg.type))
      if condition
        condition = And.new(condition, is_a)
      else
        condition = is_a
      end
    end
    condition
  end

  # We use a special version of MainVisitor that doesn't resolve calls
  # nor do some checks. This is because in a multidispatch we already know
  # what the calls resolve to.
  class MultidispatchMainVisitor < MainVisitor
    def recalculate_call(node : Call)
      # Define special vars (this is copied from the last bits of Call#recalculate)
      target_def = node.target_def
      target_def.special_vars.try &.each do |special_var_name|
        special_var = target_def.vars.not_nil![special_var_name]
        define_special_var(special_var_name, special_var)
      end
    end

    def check_super_or_previous_def_in_initialize(node)
      # Nothing
    end

    def check_call_in_initialize(node)
      # Nothing
    end
  end
end
