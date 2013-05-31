require_relative "program"

module Crystal
  class Program
    def normalize(node)
      return nil unless node
      normalizer = Normalizer.new(self)
      node = normalizer.normalize(node)
      node
    end
  end

  class Normalizer < Transformer
    attr_reader :program

    def initialize(program)
      @program = program
    end

    def normalize(node)
      node.transform(self)
    end

    def transform_expressions(node)
      exps = []
      node.expressions.each do |exp|
        new_exp = exp.transform(self)
        exps << new_exp if new_exp
        if exp.is_a?(Return) || exp.is_a?(Next) || exp.is_a?(Break)
          break
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

    def transform_and(node)
      node.left = node.left.transform(self)
      node.right = node.right.transform(self)

      if node.left.is_a?(Var) || node.left.is_a?(IsA)
        If.new(node.left, node.right, node.left)
      else
        temp_var = program.new_temp_var
        If.new(Assign.new(temp_var, node.left), node.right, temp_var)
      end
    end

    def transform_or(node)
      node.left = node.left.transform(self)
      node.right = node.right.transform(self)

      if node.left.is_a?(Var)
        If.new(node.left, node.left, node.right)
      else
        temp_var = program.new_temp_var
        If.new(Assign.new(temp_var, node.left), temp_var, node.right)
      end
    end

    def transform_require(node)
      required = program.require(node.string.value, node.filename)
      required ? required.transform(self) : nil
    end

    def transform_call(node)
      node.obj = node.obj.transform(self) if node.obj
      node.args.map! { |arg| arg.transform(self) }
      node.block.transform(self) if node.block
      node
    end

    def transform_assign(node)
      node.value = node.value.transform(self)
      node
    end

    def transform_multi_assign(node)
      node.values.map! { |v| v.transform(self) }
      node
    end

    def transform_class_def(node)
      node.body = node.body.transform(self) if node.body
      node
    end

    def transform_module_def(node)
      node.body = node.body.transform(self) if node.body
      node
    end

    def transform_def(node)
      if node.has_default_arguments?
        exps = node.expand_default_arguments.map! { |a_def| a_def.transform(self) }
        Expressions.new(exps)
      else
        node.body = node.body.transform(self) if node.body
        node
      end
    end

    def transform_if(node)
      node.cond = node.cond.transform(self)
      node.then = node.then.transform(self) if node.then
      node.else = node.else.transform(self) if node.else
      node
    end

    def transform_while(node)
      node.cond = node.cond.transform(self)
      node.body = node.body.transform(self) if node.body
      node
    end

    def transform_block(node)
      node.body = node.body.transform(self) if node.body
      node
    end

    def transform_case(node)
      node.cond = node.cond.transform(self)
      node.whens.map! { |w| w.transform(self) }
      node.else = node.else.transform(self) if node.else
      node
    end

    def transform_when(node)
      node.conds.map! { |w| w.transform(self) }
      node.body = node.body.transform(self) if node.body
      node
    end

    def transform_array_literal(node)
      node.elements.map! { |e| e.transform(self) }
      node
    end

    def transform_hash_literal(node)
      node.keys.map! { |k| k.transform(self) }
      node.values.map! { |v| v.transform(self) }
      node
    end

    def transform_range_literal(node)
      node.from = node.from.transform(self)
      node.to = node.to.transform(self)
      node
    end

    def transform_simple_or(node)
      node.left = node.left.transform(self)
      node.right = node.right.transform(self)
      node
    end

    def transform_return(node)
      node.exps.map! { |e| e.transform(self) }
      node
    end

    def transform_break(node)
      node.exps.map! { |e| e.transform(self) }
      node
    end

    def transform_next(node)
      node.exps.map! { |e| e.transform(self) }
      node
    end

    def transform_yield(node)
      node.exps.map! { |e| e.transform(self) }
      node
    end

    def transform_is_a(node)
      node.obj = node.obj.transform(self)
      node
    end
  end
end