module Crystal
  class Program
    def after_type_inference(node)
      node = node.transform(AfterTypeInferenceTransformer.new(self))
      puts node if ENV['AFTER'] == '1'
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
    def initialize(program)
      @program = program
      @transformed = {}
    end

    def transform_def(node)
      node
    end

    def transform_class_def(node)
      node
    end

    def transform_module_def(node)
      node
    end

    def transform_expressions(node)
      exps = []

      found_no_return = false
      node.expressions.each do |exp|
        new_exp = exp.transform(self)
        if new_exp
          if new_exp.is_a?(Expressions)
            exps.concat new_exp.expressions
          else
            exps << new_exp
          end

          if new_exp.type && new_exp.type.no_return?
            found_no_return = true
            break
          end
        end
      end

      case exps.length
      when 0
        nil
      when 1
        exps[0]
      else
        node.expressions = exps
        rebind_node node, exps.last
        node
      end
    end

    def transform_assign(node)
      super

      if node.value.type && node.value.type.no_return?
        rebind_node node, node.value
        return node.value
      end

      node
    end

    def transform_call(node)
      super

      if node.target_defs
        changed = false
        allocated_defs = []

        node.target_defs.each do |target_def|
          allocated = target_def.owner.allocated && target_def.args.all? { |arg| arg.type.allocated }
          unless allocated
            changed = true
            next
          end

          allocated_defs << target_def

          next if @transformed[target_def.object_id]

          @transformed[target_def.object_id] = true

          if target_def.body
            node.bubbling_exception do
              target_def.body = target_def.body.transform(self)
            end

            # If the body was completely removed, rebind to nil
            unless target_def.body
              rebind_node target_def, @program.nil_var
            end
          end
        end

        if changed
          node.unbind_from *node.target_defs
          node.target_defs = allocated_defs
          node.bind_to *allocated_defs
        end

        if node.target_defs.empty?
          exps = []
          exps.push node.obj if node.obj
          node.args.each { |arg| exps.push arg }
          return Expressions.from exps
        end
      end

      check_comparison_of_unsigned_integer_with_zero_or_negative_literal(node)

      node
    end

    def check_comparison_of_unsigned_integer_with_zero_or_negative_literal(node)
      if (node.name == :< || node.name == :<=) && node.obj.type.integer? && node.obj.type.unsigned?
        arg = node.args[0]
        if arg.is_a?(NumberLiteral) && arg.integer? && arg.value.to_i <= 0
          node.raise "'#{node.name}' comparison of unsigned integer with zero or negative literal will always be false"
        end
      end

      if (node.name == :> || node.name == :>=) && node.obj.is_a?(NumberLiteral) && node.obj.integer? && node.obj.value.to_i <= 0
        arg = node.args[0]
        if arg.type.integer? && arg.type.unsigned?
          node.raise "'#{node.name}' comparison of unsigned integer with zero or negative literal will always be false"
        end
      end
    end

    def transform_if(node)
      super

      if node.cond.true_literal?
        rebind_node node, node.then
        return node.then
      end

      if node.cond.false_literal?
        rebind_node node, node.else
        return node.else
      end

      if node.cond.type && node.cond.type.nil_type?
        return replace_if_with_branch(node, node.else)
      end

      if node.cond.is_a?(Assign) && node.cond.value.true_literal?
        return replace_if_with_branch(node, node.then)
      end

      if node.cond.is_a?(Assign) && node.cond.value.false_literal?
        return replace_if_with_branch(node, node.else)
      end

      node
    end

    def replace_if_with_branch(node, branch)
      exp_nodes = [node.cond]
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

    def transform_is_a(node)
      super

      if node.obj.is_a?(Var) && node.obj.type
        filtered_type = node.obj.type.filter_by(node.const.type.instance_type)

        if node.obj.type.equal?(filtered_type)
          return true_literal
        end

        unless filtered_type
          return false_literal
        end
      end

      node
    end

    def transform_responds_to(node)
      super

      if node.obj.type
        filtered_type = node.obj.type.filter_by_responds_to(node.name.value)

        if node.obj.type.equal?(filtered_type)
          return true_literal
        end

        unless filtered_type
          return false_literal
        end
      end

      node
    end

    def transform_fun_def(node)
      return node unless node.body

      node.body = node.body.transform(self)
      node.external.body = node.external.body.transform(self) if node.external
      node
    end

    def transform_exception_handler(node)
      super

      if node.body.no_returns?
        node.else = nil
      end

      if node.rescues
        new_rescues = []

        node.rescues.each do |a_rescue|
          if !a_rescue.type || a_rescue.type.allocated
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
      node.unbind_from *node.dependencies
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
