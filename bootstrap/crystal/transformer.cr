module Crystal
  class ASTNode
    def transform(transformer)
      transformer.before_transform self
      node = transformer.transform self
      transformer.after_transform self
      node
    end
  end

  class Transformer
    def before_transform(node)
    end

    def after_transform(node)
    end

    def transform(node)
      node
    end

    def transform(node : Expressions)
      exps = [] of ASTNode
      node.expressions.each do |exp|
        new_exp = exp.transform(self)
        if new_exp
          if new_exp.is_a?(Expressions)
            exps.concat new_exp.expressions
          else
            exps << new_exp
          end
        end
      end

      if exps.length == 1
        exps[0]
      else
        node.expressions = exps
        node
      end
    end

    def transform(node : Call)
      if node_obj = node.obj
        node.obj = node_obj.transform(self)
      end
      transform_many node.args

      if node_block = node.block
        node.block = node_block.transform(self)
      end
      # node.block_arg = node.block_arg.transform(self) if node.block_arg
      node
    end

    def transform_many(exps)
      exps.map! { |exp| exp.transform(self) } if exps
    end
  end
end
