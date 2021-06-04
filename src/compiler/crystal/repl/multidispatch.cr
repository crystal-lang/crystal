require "./repl"

module Crystal::Repl::Multidispatch
  def self.create_def(context : Context, node : Call, target_defs : Array(Def))
    if node.block
      a_def = create_def_uncached(context, node, target_defs)

      # Store it so the GC doesn't collect it (it's in the instructions but it might not be aligned)
      context.multidispatchs_with_block << a_def

      return a_def
    end

    obj = node.obj
    obj_type = obj.try(&.type) || node.scope

    signature = CallSignature.new(
      name: node.name,
      arg_types: node.args.map(&.type),
      block: node.block,
      named_args: node.named_args.try &.map do |named_arg|
        NamedArgumentType.new(named_arg.name, named_arg.value.type)
      end,
    )

    cache_key = Context::MultidispatchKey.new(obj_type, signature)
    cached_def = context.multidispatchs[cache_key]?
    return cached_def if cached_def

    a_def = create_def_uncached(context, node, target_defs)

    context.multidispatchs[cache_key] = a_def

    a_def
  end

  private def self.create_def_uncached(context : Context, node : Call, target_defs : Array(Def))
    obj = node.obj
    obj_type = obj.try(&.type) || node.scope

    a_def = Def.new(node.name).at(node)

    unless obj_type.is_a?(Program)
      a_def.args << Arg.new("self").at(node)
    end

    i = 0

    node.args.each do
      a_def.args << Arg.new("arg#{i}").at(node)
      i += 1
    end

    node.named_args.try &.each do
      a_def.args << Arg.new("arg#{i}").at(node)
      i += 1
    end

    block = node.block
    if block
      a_def.block_arg = Arg.new("")
      a_def.yields = block.args.size
    end

    main_if = nil
    current_if = nil

    target_defs.each do |target_def|
      i = 0

      condition = nil

      unless obj_type.is_a?(Program)
        unless obj_type.implements?(target_def.owner)
          condition = IsA.new(Var.new("self"), TypeNode.new(target_def.owner))
        end
      end

      node.args.each do |arg|
        target_def_arg = target_def.args[i]
        condition = add_arg_condition(arg, target_def_arg, i, condition)

        i += 1
      end

      node.named_args.try &.each do |named_arg|
        arg = named_arg.value
        target_def_arg = target_def.args[i]
        condition = add_arg_condition(arg, target_def_arg, i, condition)

        i += 1
      end

      condition ||= BoolLiteral.new(true)

      call_args = [] of ASTNode

      i = 0
      node.args.each do
        call_args << Var.new("arg#{i}")
        i += 1
      end

      node.named_args.try &.each do
        call_args << Var.new("arg#{i}")
        i += 1
      end

      call_obj =
        if obj_type.is_a?(Program)
          nil
        else
          Var.new("self")
        end

      call = Call.new(call_obj, node.name, call_args)

      if block
        block_args = block.args.map_with_index { |arg, i| Var.new("barg#{i}") }
        yield_args = Array(ASTNode).new(block_args.size)
        block.args.each_index { |i| yield_args << Var.new("barg#{i}") }

        call.block = Block.new(block_args, body: Yield.new(yield_args))
      end

      target_def_if = If.new(condition, call)

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

    a_def = context.program.normalize(a_def)
    a_def.owner = obj_type

    def_args = MetaVars.new

    unless obj_type.is_a?(Program)
      def_args["self"] = MetaVar.new("self", obj_type)
    end

    i = 0

    node.args.each do |arg|
      def_args["arg#{i}"] = MetaVar.new("arg#{i}", arg.type)
      i += 1
    end

    node.named_args.try &.each do |named_arg|
      def_args["arg#{i}"] = MetaVar.new("arg#{i}", named_arg.value.type)
      i += 1
    end

    visitor = MainVisitor.new(context.program, def_args, a_def)
    visitor.untyped_def = a_def
    visitor.call = node

    # visitor.scope = obj_type
    # visitor.yield_vars = yield_vars
    # visitor.match_context = match.context
    # visitor.call = self
    # visitor.path_lookup = match.context.defining_type
    a_def.body.accept visitor

    a_def.bind_to(a_def.body)

    a_def.body = context.program.cleanup(a_def.body)

    # puts a_def

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
end
