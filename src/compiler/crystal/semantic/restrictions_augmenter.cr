module Crystal
  class RestrictionsAugmenter < Visitor
    @args_hash : Hash(String, Arg)?
    @current_type : Type
    @def : Def?

    # If an assignment happens conditionally we can't add a type
    # restriction because... we can't be sure the assignment will happen!
    @conditional_nest = 0

    def initialize(@program : Program, @new_expansions : Array({original: Def, expanded: Def}))
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

    def visit(node : If | Unless)
      node.cond.accept self
      @conditional_nest += 1
      node.then.accept self
      node.else.try &.accept self
      @conditional_nest -= 1
      false
    end

    def visit(node : While | Until)
      node.cond.accept self
      @conditional_nest += 1
      node.body.accept self
      @conditional_nest -= 1
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

      case target
      when Var
        args_hash.delete(target.name)
      when InstanceVar
        if @conditional_nest == 0
          process_assign_instance_var(target, value, current_type, current_def, args_hash)
        end
      when ClassVar
        # TODO: apply same logic but for assignments to class vars
      end

      false
    end

    def visit(node : ASTNode)
      true
    end

    private def process_assign_instance_var(target, value, current_type, current_def, args_hash)
      return unless current_type.is_a?(InstanceVarContainer)
      return unless value.is_a?(Var)

      arg = args_hash[value.name]?
      return unless arg

      ivar = current_type.instance_vars[target.name]?
      return unless ivar

      converter = TypeToRestriction.new(current_type)

      restriction = converter.convert(ivar.type)
      return unless restriction

      arg.restriction = restriction

      # If this is an initialize, we can also add a type restriction to the
      # auto-generated "new" so that it shows up in docs.
      return unless current_def.name == "initialize"

      # TODO: we should probably store the expansions as a Hash from now on
      expansion = @new_expansions.find { |expansion| expansion[:original].same?(current_def) }
      return unless expansion

      expanded = expansion[:expanded]
      expansion_arg = expanded.args.find do |expansion_arg|
        expansion_arg.name == arg.name
      end
      return unless expansion_arg

      expansion_arg.restriction = restriction.dup
    end
  end
end
