require "../ast"
require "../types"
require "../transformer"

module Crystal
  class Program
    def after_type_inference(node)
      transformer = AfterTypeInferenceTransformer.new(self)
      node = node.transform(transformer)
      puts node if ENV["AFTER"]? == "1"

      # Make sure to transform regexes constants (see Normalizer#trnasform(Regex))
      regexes.each do |const|
        const.value = const.value.transform(transformer)
      end

      node
    end
  end

  class ASTNode
    def false_literal?
      false
    end

    def true_literal?
      false
    end
  end

  class BoolLiteral
    def false_literal?
      !value
    end

    def true_literal?
      value
    end
  end

  class AfterTypeInferenceTransformer < Transformer
    def initialize(@program)
      @transformed = Set(typeof(object_id)).new
    end

    def transform(node : Def)
      node
    end

    def transform(node : Include)
      node
    end

    def transform(node : Extend)
      node
    end

    def transform(node : Expressions)
      exps = [] of ASTNode

      length = node.expressions.length
      node.expressions.each_with_index do |exp, i|
        new_exp = exp.transform(self)
        if new_exp
          if new_exp.is_a?(Expressions)
            exps.concat new_exp.expressions
          else
            exps << new_exp
          end

          if new_exp.no_returns?
            break
          end
        end
      end

      if exps.empty?
        nop = Nop.new
        nop.set_type(@program.nil)
        exps << nop
      end

      node.expressions = exps
      rebind_node node, exps.last
      node
    end

    def transform(node : ExpandableNode)
      if expanded = node.expanded
        node.expanded = expanded.transform(self)
      end
      node
    end

    def transform(node : Assign)
      node = super

      # We don't want to transform constant assignments into no return
      unless node.target.is_a?(Path)
        if node.value.type?.try &.no_return?
          rebind_node node, node.value
          return node.value
        end
      end

      node
    end

    def transform(node : Call)
      if expanded = node.expanded
        node.expanded = expanded.transform self
        return node
      end

      # Check if we have an untyped expression in this call, or an expression
      # whose type was never allocated. Replace it with raise.
      obj = node.obj
      obj_type = obj.try &.type?
      if (obj && !obj_type)
        return untyped_expression(node, "`#{obj}` has no type")
      end

      if obj && !obj.type.allocated
        return untyped_expression(node, "#{obj.type} in `#{obj}` was never instantiated")
      end

      node.args.each do |arg|
        unless arg.type?
          return untyped_expression(node, "`#{arg}` has no type")
        end

        unless arg.type.allocated
          return untyped_expression(node, "#{arg.type} in `#{arg}` was never instantiated")
        end
      end

      super

      # If the block doesn't have a type, it's a no-return.
      if (block = node.block) && !block.type?
        block.type = @program.no_return
      end

      # If any expression is no-return, replace the call with its expressions up to
      # the one that no returns.
      if (obj.try &.type?.try &.no_return?) || node.args.any? &.type?.try &.no_return?
        call_exps = [] of ASTNode
        call_exps << obj if obj
        unless obj.try &.type?.try &.no_return?
          node.args.each do |arg|
            call_exps << arg
            break if arg.type?.try &.no_return?
          end
        end
        exps = Expressions.new(call_exps)
        exps.set_type(call_exps.last.type?) unless call_exps.empty?
        return exps
      end

      if target_defs = node.target_defs
        changed = false
        allocated_defs = [] of Def

        if target_defs.length == 1
          if target_defs[0].is_a?(External)
            check_args_are_not_closure node, "can't send closure to C function"
          elsif obj_type.is_a?(CStructType) && node.name.ends_with?('=')
            check_args_are_not_closure node, "can't set closure as C struct member"
          elsif obj_type.is_a?(CUnionType) && node.name.ends_with?('=')
            check_args_are_not_closure node, "can't set closure as C union member"
          end
        end

        target_defs.each do |target_def|
          allocated = target_def.owner.try(&.allocated) && target_def.args.all? &.type.allocated
          if allocated
            allocated_defs << target_def

            unless @transformed.includes?(target_def.object_id)
              @transformed.add(target_def.object_id)

              node.bubbling_exception do
                target_def.body = target_def.body.transform(self)
              end
            end
          else
            changed = true
          end
        end

        if changed
          node.unbind_from node.target_defs
          node.target_defs = allocated_defs
          node.bind_to allocated_defs
        end

        if node.target_defs.not_nil!.empty?
          exps = [] of ASTNode
          if obj = node.obj
            exps.push obj
          end
          node.args.each { |arg| exps.push arg }
          call_exps = Expressions.from exps
          call_exps.set_type(exps.last.type?) unless exps.empty?
          return call_exps
        end
      end

      # check_comparison_of_unsigned_integer_with_zero_or_negative_literal(node)

      node
    end

    def number_lines(source)
      source.lines.to_s_with_line_numbers
    end

    def check_args_are_not_closure(node, message)
      node.args.each do |arg|
        case arg
        when FunLiteral
          if arg.def.closure
            arg.raise message
          end
        when FunPointer
          if arg.obj.try &.type?.try &.passed_as_self?
            arg.raise message
          end

          owner = arg.call.target_def.owner.not_nil!
          if owner.passed_as_self?
            arg.raise message
          end
        end
      end
    end

    def transform(node : FunPointer)
      super
      node.call?.try &.transform(self)
      node
    end

    def transform(node : FunLiteral)
      super

      node.def.body = node.def.body.transform(self)

      body = node.def.body
      if !body.type? && !body.is_a?(Return)
        node.def.body = untyped_expression(body)
        rebind_node node.def, node.def.body
        node.update
      end

      node
    end

    def untyped_expression(node, msg = nil)
      ex_msg = String.build do |str|
        str << "can't execute `"
        str << node
        str << "`"
        str << " at "
        str << node.location
        if msg
          str << ": "
          str << msg
        end
      end

      call = Call.new(nil, "raise", [StringLiteral.new(ex_msg)] of ASTNode, nil, nil, true)
      call.accept TypeVisitor.new(@program)
      call
    end

    def transform(node : Yield)
      super

      # If the yield has a no-return expression, the yield never happens:
      # replace it with a series of expressions up to the one that no-returns.
      no_return_index = node.exps.index &.no_returns?
      if no_return_index
        exps = Expressions.new(node.exps[0, no_return_index + 1])
        exps.bind_to(exps.expressions.last)
        return exps
      end

      node
    end

    # def check_comparison_of_unsigned_integer_with_zero_or_negative_literal(node)
    #   if (node.name == :< || node.name == :<=) && node.obj && node.obj.type && node.obj.type.integer? && node.obj.type.unsigned?
    #     arg = node.args[0]
    #     if arg.is_a?(NumberLiteral) && arg.integer? && arg.value.to_i <= 0
    #       node.raise "'#{node.name}' comparison of unsigned integer with zero or negative literal will always be false"
    #     end
    #   end

    #   if (node.name == :> || node.name == :>=) && node.obj && node.obj.type && node.obj.is_a?(NumberLiteral) && node.obj.integer? && node.obj.value.to_i <= 0
    #     arg = node.args[0]
    #     if arg.type.integer? && arg.type.unsigned?
    #       node.raise "'#{node.name}' comparison of unsigned integer with zero or negative literal will always be false"
    #     end
    #   end
    # end

    def transform(node : If)
      node.cond = node.cond.transform(self)

      node_cond = node.cond

      if node_cond.no_returns?
        return node_cond
      end

      if node_cond.true_literal?
        node.then = node.then.transform(self)
        rebind_node node, node.then
        return node.then
      end

      if node_cond.false_literal?
        node.else = node.else.transform(self)
        rebind_node node, node.else
        return node.else
      end

      if (cond_type = node_cond.type?) && cond_type.nil_type?
        node.else = node.else.transform(self)
        return replace_if_with_branch(node, node.else)
      end

      node.then = node.then.transform(self)
      node.else = node.else.transform(self)

      if node_cond.is_a?(Assign)
        if node_cond.value.true_literal?
          return replace_if_with_branch(node, node.then)
        end

        if node_cond.value.false_literal?
          return replace_if_with_branch(node, node.else)
        end
      end

      node
    end

    def replace_if_with_branch(node, branch)
      exp_nodes = [node.cond] of ASTNode
      exp_nodes << branch unless branch.nop?

      exp = Expressions.new(exp_nodes)
      if branch
        exp.bind_to branch
        rebind_node node, branch
      else
        exp.bind_to @program.nil_var
      end
      exp
    end

    def transform(node : IsA)
      super

      if replacement = node.syntax_replacement
        replacement
      else
        transform_is_a_or_responds_to node, &.filter_by(node.const.type)
      end
    end

    def transform(node : RespondsTo)
      super
      transform_is_a_or_responds_to node, &.filter_by_responds_to(node.name.value)
    end

    def transform_is_a_or_responds_to(node)
      obj = node.obj

      if obj_type = obj.type?
        filtered_type = yield obj_type

        if obj_type == filtered_type
          return true_literal
        end

        unless filtered_type
          return false_literal
        end
      end

      node
    end

    def transform(node : Cast)
      node = super

      obj_type = node.obj.type?
      return node unless obj_type

      to_type = node.to.type.instance_type

      if to_type.pointer?
        if obj_type.pointer? || obj_type.reference_like?
          return node
        else
          node.raise "can't cast #{obj_type} to #{to_type}"
        end
      end

      if obj_type.pointer?
        unless to_type.pointer? || to_type.reference_like?
          node.raise "can't cast #{obj_type} to #{to_type}"
        end
      else
        unless to_type.allocated
          node.to.raise "can't cast to #{to_type} because it was never instantiated"
        end

        resulting_type = obj_type.filter_by(to_type)
        unless resulting_type
          node.raise "can't cast #{obj_type} to #{to_type}"
        end
      end

      node
    end

    def transform(node : FunDef)
      node_body = node.body
      return node unless node_body

      node.body = node_body.transform(self)

      if node_external = node.external
        node_external.body = node_external.body.transform(self)
      end
      node
    end

    def transform(node : ExceptionHandler)
      node = super

      if node.body.no_returns?
        node.else = nil
      end

      if node_rescues = node.rescues
        new_rescues = [] of Rescue

        node_rescues.each do |a_rescue|
          if !a_rescue.type? || a_rescue.type.allocated
            new_rescues << a_rescue
          end
        end

        if new_rescues.empty?
          if node.ensure
            node.rescues = nil
          else
            rebind_node node, node.body
            return node.body
          end
        else
          node.rescues = new_rescues
        end
      end

      node
    end

    def transform(node : InstanceSizeOf)
      exp_type = node.exp.type?

      if exp_type
        instance_type = exp_type.instance_type
        unless instance_type.class?
          node.exp.raise "#{instance_type} is not a class, it's a #{instance_type.type_desc}"
        end
      end

      node
    end

    def transform(node : TupleLiteral)
      super
      node.update
      node
    end

    def rebind_node(node, dependency)
      node.unbind_from node.dependencies?
      if dependency
        node.bind_to dependency
      else
        node.bind_to @program.nil_var
      end
    end

    def false_literal
      @false_literal ||= begin
        false_literal = BoolLiteral.new(false)
        false_literal.set_type(@program.bool)
        false_literal
      end
    end

    def true_literal
      @true_literal ||= begin
        true_literal = BoolLiteral.new(true)
        true_literal.set_type(@program.bool)
        true_literal
      end
    end
  end
end
