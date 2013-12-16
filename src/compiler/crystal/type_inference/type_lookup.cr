module Crystal
  class TypeLookup < Visitor
    getter! type

    def initialize(@root)
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : Ident)
      the_type = @root.lookup_type(node)
      if the_type && the_type.is_a?(Type)
        @type = the_type.remove_alias_if_simple
      else
        node.raise("uninitialized constant #{node.to_s_node}")
      end
    end

    def visit(node : IdentUnion)
      types = node.idents.map do |ident|
        ident.accept self
        type
      end
      @type = @root.program.type_merge(types)
      false
    end

    def end_visit(node : Hierarchy)
      @type = type.instance_type.hierarchy_type
    end

    def visit(node : NewGenericClass)
      node.name.accept self

      instance_type = @type.not_nil!
      unless instance_type.is_a?(GenericClassType)
        node.raise "#{instance_type} is not a generic class, it's a #{instance_type.type_desc}"
      end

      if instance_type.type_vars.length != node.type_vars.length
        node.raise "wrong number of type vars for #{instance_type} (#{node.type_vars.length} for #{instance_type.type_vars.length})"
      end

      type_vars = [] of Type | ASTNode
      node.type_vars.each do |type_var|
        type_var.accept self
        type_vars.push @type.not_nil!
      end

      @type = instance_type.instantiate(type_vars)
      false
    end

    def visit(node : FunTypeSpec)
      types = [] of Type
      if inputs = node.inputs
        inputs.each do |input|
          input.accept self
          types << type
        end
      end

      if output = node.output
        output.accept self
        types << type
      else
        types << @root.program.void
      end

      @type = @root.program.fun_of(types)
      false
    end

    def visit(node : SelfType)
      @type = @root
      false
    end
  end
end
