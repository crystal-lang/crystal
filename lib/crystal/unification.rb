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
    end

    def end_visit_call(node)
      if node.target_def && !node.target_def.unified
        node.target_def.unified = true
        node.target_def.accept self
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
        unified_type = @types[type]

        if unified_type
          unified_type
        else
          unified_types = type.types.map { |type| unify_type(type) }.uniq
          if unified_types.length == 1
            @types[type] = unified_types.first
          else
            @types[type] = UnionType.new(*unified_types)
          end
        end
      else
        type
      end
    end
  end
end