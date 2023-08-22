require "../syntax/transformer"

module Crystal
  class Transformer
    def transform(node : MetaVar | MetaMacroVar | Primitive | TypeFilteredNode | TupleIndexer | TypeNode | AssignWithRestriction | YieldBlockBinder | MacroId | Unreachable)
      node
    end

    def transform(node : FileNode)
      node.node = node.node.transform self
      node
    end
  end
end
