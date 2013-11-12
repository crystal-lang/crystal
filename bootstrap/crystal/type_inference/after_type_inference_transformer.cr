require "../ast"
require "../types"
require "../transformer"

module Crystal
  class Program
    def after_type_inference(node)
      node = node.transform(AfterTypeInferenceTransformer.new(self))
      puts node if ENV["AFTER"] == "1"
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
      @transformed = Set(UInt64).new
    end

    def transform(node : Def)
      node
    end

    def transform(node : ClassDef)
      node
    end

    def transform(node : ModuleDef)
      node
    end

    def transform(node : Expressions)
      exps = [] of ASTNode

      found_no_return = false
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
            found_no_return = true
            break
          end
        end
      end

      case exps.length
      when 0
        Nop.new
      when 1
        exps[0]
      else
        node.expressions = exps
        rebind_node node, exps.last
        node
      end
    end

    def transform(node : Assign)
      super

      if node.value.type?.try &.no_return?
        rebind_node node, node.value
        return node.value
      end

      node
    end

    def transform(node : Call)
      super

      if target_defs = node.target_defs
        changed = false
        allocated_defs = [] of Def

        target_defs.each do |target_def|
          allocated = target_def.owner.try(&.allocated) && target_def.args.all? &.type.allocated
          if allocated
            allocated_defs << target_def

            unless @transformed.includes?(target_def.object_id)
              @transformed.add(target_def.object_id)

              if body = target_def.body
                node.bubbling_exception do
                  target_def.body = body.transform(self)
                end

                # If the body was completely removed, rebind to nil
                unless target_def.body
                  rebind_node target_def, @program.nil_var
                end
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
          return Expressions.from exps
        end
      end

      # check_comparison_of_unsigned_integer_with_zero_or_negative_literal(node)

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
      super

      if node.cond.true_literal?
        rebind_node node, node.then
        return node.then
      end

      if node.cond.false_literal?
        rebind_node node, node.else
        return node.else
      end

      node_cond = node.cond

      if (cond_type = node_cond.type?) && cond_type.nil_type?
        return replace_if_with_branch(node, node.else)
      end

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

      obj = node.obj

      if obj.is_a?(Var) && obj.type?
        filtered_type = obj.type.filter_by(node.const.type.instance_type)

        if obj.type == filtered_type
          return true_literal
        end

        unless filtered_type
          return false_literal
        end
      end

      node
    end

    # def transform(node : RespondsTo)
    #   super

    #   if node.obj.type
    #     filtered_type = node.obj.type.filter_by_responds_to(node.name.value)

    #     if node.obj.type.equal?(filtered_type)
    #       return true_literal
    #     end

    #     unless filtered_type
    #       return false_literal
    #     end
    #   end

    #   node
    # end

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
      super

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
