require "program"
require "transformer"
require "set"

module Crystal
  class Program
    def normalize(node)
      normalizer = Normalizer.new(self)
      node = normalizer.normalize(node)
      puts node if ENV["SSA"] == "1"
      node
    end
  end

  class Normalizer < Transformer
    getter :program

    def initialize(@program)
    end

    def normalize(node)
      node.transform(self)
    end

    def transform(node : And)
      left = node.left
      new_node = if left.is_a?(Var) || (left.is_a?(IsA) && left.obj.is_a?(Var))
               If.new(left, node.right, left.clone)
             else
               temp_var = new_temp_var
               If.new(Assign.new(temp_var, left), node.right, temp_var)
             end
      new_node.binary = :and
      new_node.transform(self)
    end

    def new_temp_var
      program.new_temp_var
    end
  end
end
