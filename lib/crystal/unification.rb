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

  class UnifyVisitor
    def initialize
      @types = {}
    end

    def end_visit_call(node)
      if node.target_def && !node.target_def.unified
        node.target_def.unified = true
        node.target_def.accept self
      end
    end

    def method_missing(name, *args)
      if name.to_s.start_with? 'visit_'
        node = args[0]
        node.set_type unify_type(node.type)
      end
      true
    end

    def unify_type(type)
      return type unless type.is_a?(ObjectType)
      unified_type = @types[type]

      unless unified_type
        unified_type = @types[type] = type
        unified_type.instance_vars.each do |name, ivar|
          ivar.set_type unify_type(ivar.type) unless @types[ivar.type].equal?(ivar.type)
        end
      end

      unified_type
    end
  end
end