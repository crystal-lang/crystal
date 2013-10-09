module Crystal
  abstract class Type
    def restrict(restriction : Nil, type_lookup)
      self
    end

    def restrict(restriction : Type, type_lookup)
      self == restriction ? self : nil
    end

    def restrict(restriction : Ident, type_lookup)
      ident_type = type_lookup.lookup_type restriction.names
      self.restrict ident_type, type_lookup
    end

    def restrict(restriction : ASTNode, type_lookup)
      raise "Bug: unsupported restriction: #{restriction}"
    end
  end
end
