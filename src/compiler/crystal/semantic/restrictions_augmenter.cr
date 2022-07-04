module Crystal
  class RestrictionsAugmenter < Visitor
    @args_hash : Hash(String, Arg)?
    @current_type : Type
    @def : Def?

    # If an assignment happens conditionally we can't add a type
    # restriction because... we can't be sure the assignment will happen!
    @conditional_nest = 0

    def initialize(@program : Program, @new_expansions : Hash(Def, Def))
      @current_type = @program
    end

    def visit(node : ExpandableNode)
      if expanded = node.expanded
        expanded.accept self
      end
      false
    end

    def visit(node : ClassDef)
      old_type = @current_type
      @current_type = node.resolved_type
      node.body.accept self
      @current_type = old_type
      false
    end

    def visit(node : Def)
      @def = node
      @args_hash = args_hash = {} of String => Arg
      node.args.each do |arg|
        next if arg.restriction
        args_hash[arg.name] = arg
      end
      node.body.accept self
      @args_hash = nil
      @def = nil
      false
    end

    def visit(node : If)
      node.cond.accept self
      @conditional_nest += 1
      node.then.accept self
      node.else.try &.accept self
      @conditional_nest -= 1
      false
    end

    def visit(node : While)
      node.cond.accept self
      @conditional_nest += 1
      node.body.accept self
      @conditional_nest -= 1
      false
    end

    def visit(node : Call)
      if expanded = node.expanded
        return expanded.accept self
      end

      node.obj.try &.accept self
      node.args.each &.accept self
      node.named_args.try &.each &.value.accept self
      node.block.try do |block|
        @conditional_nest += 1
        block.accept self
        @conditional_nest -= 1
      end
      node.block_arg.try &.accept self
      false
    end

    def visit(node : Assign)
      args_hash = @args_hash
      return false unless args_hash

      current_def = @def
      return false unless current_def

      target = node.target
      value = node.value
      current_type = @current_type

      if target.is_a?(Var)
        args_hash.delete(target.name)
        return false
      end

      return false unless @conditional_nest == 0
      return false unless value.is_a?(Var)

      arg = args_hash[value.name]?
      return false unless arg

      case target
      when InstanceVar
        return false unless current_type.is_a?(InstanceVarContainer)

        ivar = current_type.instance_vars[target.name]?
        return false unless ivar

        augment(target, value, current_type, current_def, arg, ivar.type)
      when ClassVar
        return false unless current_type.is_a?(ClassVarContainer)

        cvar = current_type.class_vars[target.name]?
        return false unless cvar

        augment(target, value, current_type, current_def, arg, cvar.type)
      end

      false
    end

    def visit(node : ASTNode)
      true
    end

    private def augment(target, value, current_type, current_def, arg, type)
      converter = TypeToRestriction.new(current_type)

      restriction = converter.convert(type)
      return unless restriction

      arg.restriction = restriction

      # If this is an initialize, we can also add a type restriction to the
      # auto-generated "new" so that it shows up in docs.
      return unless current_def.name == "initialize"

      expansion = @new_expansions[current_def]?
      return unless expansion

      expansion_arg = expansion.args.find do |expansion_arg|
        expansion_arg.name == arg.name
      end
      return unless expansion_arg

      expansion_arg.restriction = restriction.dup
    end
  end
end
