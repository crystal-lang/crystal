module Crystal
  def unify(node)
    node.accept UnifyVisitor.new
  end

  class ASTNode
    def set_type(type)
      @type = type
    end
  end

  class Def
    attr_accessor :unified
  end

  class Dispatch
    attr_accessor :unified
  end

  class UnifyVisitor < Visitor
    def initialize
      @types = {}
      @unions = {}
      @arrays = {}
      @static_arrays = {}
    end

    def end_visit_dispatch(node)
      node.obj = unify_type(node.obj) if node.obj
      node.args = node.args.map { |arg| unify_type(arg) }
    end

    def end_visit_call(node)
      if node.target_def && !node.target_def.unified
        node.target_def.unified = true
        node.target_def.accept self
        node.simplify
      end
    end

    def visit_any(node)
      node.set_type unify_type(node.type)
    end

    def unify_type(type)
      case type
      when ObjectType
        unified_type = @types[type]

        unless unified_type
          unified_type = @types[type] = type
          unified_type.instance_vars.each do |name, ivar|
            ivar.set_type unify_type(ivar.type) unless @types[ivar.type].equal?(ivar.type)
          end
        end

        unified_type
      when UnionType
        unified_types = type.types.map { |type| unify_type(type) }.uniq
        union_key = unified_types.map(&:object_id).sort
        unified_type = @unions[union_key]

        if unified_type
          unified_type
        else
          if unified_types.length == 1
            @unions[union_key] = unified_types.first
          else
            @unions[union_key] = UnionType.new(*unified_types)
          end
        end
      when ArrayType
        unified_element_type = unify_type(type.element_type)
        unified_element_type_key = unified_element_type.object_id
        unified_type = @arrays[unified_element_type_key]
        unless unified_type
          unified_type = @arrays[unified_element_type_key] = type
          unified_type.element_type_var.set_type unified_element_type
        end
        unified_type
      when StaticArrayType
        unified_element_type = unify_type(type.element_type)
        unified_element_type_key = unified_element_type.object_id
        unified_type = @static_arrays[unified_element_type_key]
        unless unified_type
          unified_type = @static_arrays[unified_element_type_key] = type
          unified_type.element_type_var.set_type unified_element_type
        end
        unified_type
      else
        type
      end
    end
  end
end