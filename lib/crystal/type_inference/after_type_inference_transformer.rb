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
      node.expressions.each do |exp|
        new_exp = exp.transform(self)
        if new_exp
          if new_exp.is_a?(Expressions)
            exps.concat new_exp.expressions
          else
            exps << new_exp
          end

          if new_exp.type && new_exp.type.no_return?
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
        node
      end
    end

    def transform_call(node)
      super

      if node.target_defs
        node.target_defs.each do |target_def|
          next if @transformed[target_def.object_id]

          @transformed[target_def.object_id] = true

          if target_def.body
            target_def.body = target_def.body.transform(self)

            # If the body was completely removed, rebind to nil
            unless target_def.body
              rebind_node target_def, @program.nil_var
            end
          end
        end
      end

      node
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
      exp_nodes << branch if branch

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

      filtered_type = node.obj.type.filter_by(node.const.type.instance_type)
      unless filtered_type
        return false_literal
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
  end
end
