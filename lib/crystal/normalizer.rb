module Crystal
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
      Expressions.from(exps)
    end

    def transform_and(node)
      if node.left.is_a?(Var)
        If.new(node.left, node.right, node.left)
      else
        temp_var = program.new_temp_var
        If.new(Assign.new(temp_var, node.left), node.right, temp_var)
      end
    end

    def transform_or(node)
      if node.left.is_a?(Var)
        If.new(node.left, node.left, node.right)
      else
        temp_var = program.new_temp_var
        If.new(Assign.new(temp_var, node.left), temp_var, node.right)
      end
    end
  end
end