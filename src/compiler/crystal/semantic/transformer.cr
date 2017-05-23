require "../syntax/transformer"

module Crystal
  class Transformer
    def transform(node : MetaVar | Primitive | TypeFilteredNode | TupleIndexer | TypeNode | TypeRestriction | YieldBlockBinder | MacroId)
      node
    end

    def transform(node : FileNode)
      node.node = node.node.transform self
      node
    end
  end
end
