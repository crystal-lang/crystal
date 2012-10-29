module Crystal
  def unify(node)
    node.accept UnifyVisitor.new
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
      @stack = []
    end

    def end_visit_call(node)
      if node.target_def && !node.target_def.unified
        node.target_def.unified = true
        node.scope = unify_type(node.scope) if node.scope.is_a?(Type)
        node.target_def.accept self
        node.simplify
      end
    end

    def visit_any(node)
      node.set_type unify_type(node.type) if node.type && !node.type.is_a?(Metaclass)
    end

    def unify_type(type)
      case type
      when ObjectType
        unified_type = @types[type]

        unless unified_type
          if index = @stack.index(type)
            unified_type = @types[type] = @stack[index]
          else
            @stack.push type

            unified_type = type
            unified_type.instance_vars.each do |name, ivar|
              ivar.set_type unify_type(ivar.type)
            end

            if existing_type = @types[type]
              unified_type = existing_type
            else
              @types[type] = unified_type
            end

            @stack.pop
          end
        end

        unified_type
      when ArrayType
        unified_type = @arrays[type]

        unless unified_type
          if index = @stack.index(type)
            unified_type = @types[type] = @stack[index]
          else
            @stack.push type

            unified_type = type
            array_type_var = type.element_type_var
            array_type_var.set_type unify_type(array_type_var.type)

            if existing_type = @arrays[type]
              unified_type = existing_type
            else
              @arrays[type] = unified_type
            end

            @stack.pop
          end
        end

        unified_type
      when UnionType
        unified_type = @unions[type]

        unless unified_type
          if index = @stack.index(type)
            unified_type = @unions[type] = @stack[index]
          else
            @stack.push type

            unified_types = type.types.map { |subtype| unify_type(subtype) }.uniq
            unified_types = unified_types.length == 1 ? unified_types[0] : UnionType.new(*unified_types)

            unified_type = @unions[type] = unified_types

            @stack.pop
          end
        end

        unified_type
      else
        type
      end
    end
  end
end