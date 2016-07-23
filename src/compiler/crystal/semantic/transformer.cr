require "../syntax/transformer"

module Crystal
  class Transformer
    def transform(node : MetaVar)
      node
    end

    def transform(node : Primitive)
      node
    end

    def transform(node : TypeFilteredNode)
      node
    end

    def transform(node : TupleIndexer)
      node
    end

    def transform(node : TypeNode)
      node
    end

    def transform(node : YieldBlockBinder)
      node
    end

    def transform(node : FileNode)
      node.node = node.node.transform self
      node
    end
  end
end
