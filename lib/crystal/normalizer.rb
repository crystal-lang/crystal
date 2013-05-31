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
  end
end