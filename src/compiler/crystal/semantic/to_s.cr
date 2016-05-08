require "../syntax/to_s"

module Crystal
  class ToSVisitor
    def visit(node : Arg)
      if node.name
        @str << decorate_arg(node, node.name)
      else
        @str << "?"
      end
      if type = node.type?
        @str << " : "
        TypeNode.new(type).accept(self)
      elsif restriction = node.restriction
        @str << " : "
        restriction.accept self
      end
      if default_value = node.default_value
        @str << " = "
        default_value.accept self
      end
      false
    end

    def visit(node : Primitive)
      @str << "# primitive: "
      @str << node.name
    end

    def visit(node : MetaVar)
      @str << node.name
    end

    def visit(node : TypeFilteredNode)
      false
    end

    def visit(node : TypeNode)
      node.type.devirtualize.to_s(@str)
      false
    end
  end
end
