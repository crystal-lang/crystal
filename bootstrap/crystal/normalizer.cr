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
    class Index
      getter :read
      getter :write
      getter :frozen

      def initialize(@read = 0, @write = 1, @frozen = false)
      end

      def increment
        Index.new(@write, @write + 1, @frozen)
      end
    end

    getter :program

    def initialize(@program)
      @vars = {} of String => Index
      @exception_handler_count = 0
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

    def transform(node : Or)
      left = node.left
      new_node = if left.is_a?(Var)
                   If.new(left, left.clone, node.right)
                 else
                   temp_var = new_temp_var
                   If.new(Assign.new(temp_var, left), temp_var, node.right)
                 end
      new_node.binary = :or
      new_node.transform(self)
    end

    def transform(node : RangeLiteral)
      super

      Call.new(Ident.new(["Range"], true), "new", [node.from, node.to, BoolLiteral.new(node.exclusive)])
    end

    def transform(node : Assign)
      target = node.target
      case target
      when Var
        node.value = node.value.transform(self)
        transform_assign_var(target)
      # when Ident
      #   pushing_vars do
      #     node.value = node.value.transform(self)
      #   end
      # when InstanceVar
      #   node.value = node.value.transform(self)
      #   transform_assign_ivar(node)
      # else
      #   node.value = node.value.transform(self)
      end

      node
    end

    def transform_assign_var(node)
      indices = @vars[node.name]?
      if indices
        if indices.frozen || @exception_handler_count > 0
          node.name = var_name_with_index(node.name, indices.read)
        else
          increment_var node.name, indices
          node.name = var_name_with_index(node.name, indices.write)
        end
      else
        @vars[node.name] = Index.new
      end
    end

    def transform(node : Var)
      return node if node.name == "self" || node.name.starts_with?('#')

      if node.out
        @vars[node.name] = Index.new
        return node
      end

      indices = @vars[node.name]?
      node.name = var_name_with_index(node.name, indices ? indices.read : nil)
      node
    end

    def increment_var(name, indices)
      @vars[name] = indices.increment
    end

    def var_name_with_index(name, index)
      if index && index > 0
        "#{name}:#{index}"
      else
        name
      end
    end

    def new_temp_var
      program.new_temp_var
    end
  end
end
