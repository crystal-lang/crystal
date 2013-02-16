require_relative 'type_inference.rb'

module Crystal
  def unify(node, visitor = UnifyVisitor.new)
    node.accept visitor
  end

  class Def
    attr_accessor :unified
  end

  class Dispatch
    attr_accessor :unified
  end

  class Var
    attr_accessor :unified
  end

  class UnifyVisitor < Visitor
    def initialize
      @types = {}
      @types_by_id = {}
      @unions = {}
      @unions_by_id = {}
      @pointers = {}
      @pointers_by_id = {}
      @stack = []
    end

    def visit_def(node)
      false
    end

    def visit_macro(node)
      false
    end

    def end_visit_call(node)
      node.scope = unify_type(node.scope) if node.scope.is_a?(Type)
      if node.target_def && !node.target_def.unified
        node.target_def.unified = true

        node.target_def.accept_children self
        if node.target_def.is_a?(Dispatch)
          node.set_type unify_type(node.type)
        else
          node.target_def.owner = unify_type(node.target_def.owner)
        end
        node.target_def.set_type unify_type(node.target_def.type)
      end
      node.simplify
    end

    def end_visit_range_literal(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_regexp_literal(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_hash_literal(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_array_literal(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_require(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_and(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_or(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_ident(node)
      node.target_const.value.accept self if node.target_const
    end

    def end_visit_var(node)
      node.unified = true
      unify_var_dependencies(node)
    end

    def visit_case(node)
      node.expanded.accept self
      false
    end

    def visit_any(node)
      node.set_type unify_type(node.type) if node.type && !node.type.is_a?(Metaclass)
      unify_var_dependencies(node) unless node.is_a?(Var)
    end

    def unify_var_dependencies(node)
      node.dependencies && node.dependencies.each do |dep|
        dep.accept self if dep.is_a?(Var) && !dep.unified
      end
    end

    def unify_type(type)
      case type
      when ObjectType
        unified_type = @types_by_id[type.object_id]
        return unified_type if unified_type

        unified_type = @types[type]

        unless unified_type
          if index = @stack.index(type)
            unified_type = @types[type] = @types_by_id[type.object_id] = @stack[index]
          else
            @stack.push type

            unified_type = type
            unified_type.instance_vars.each do |name, ivar|
              ivar.set_type unify_type(ivar.type)
            end

            existing_type = @types_by_id[type.object_id]
            if existing_type
              @stack.pop
              return existing_type
            end

            if existing_type = @types[type]
              unified_type = existing_type
            else
              @types[type] = unified_type
            end
            @types_by_id[unified_type.object_id] = unified_type

            @stack.pop
          end
        end

        unified_type
      when PointerType
        unified_type = @pointers_by_id[type.object_id]
        if unified_type
          return unified_type
        end

        unified_type = @pointers[type]

        unless unified_type
          if index = @stack.index(type)
            unified_type = @pointers[type] = @pointers_by_id[type.object_id] = @stack[index]
          else
            @stack.push type

            unified_type = type
            unified_type.var.set_type unify_type(type.var.type)

            if existing_type = @pointers[type]
              unified_type = existing_type
            else
              @pointers[type] = unified_type
            end
            @pointers_by_id[unified_type.object_id] = unified_type

            @stack.pop
          end
        end

        unified_type
      when UnionType
        unified_type = @unions_by_id[type.object_id]
        return unified_type if unified_type

        unified_type = @unions[type]

        unless unified_type
          unified_types = type.types.map { |subtype| unify_type(subtype) }.uniq
          unified_type = unified_types.length == 1 ? unified_types[0] : UnionType.new(*unified_types)

          if existing_type = @unions[type]
            unified_type = existing_type
          else
            @unions[type] = unified_type
            @unions[unified_type] = unified_type
          end

          @unions_by_id[unified_type.object_id] = unified_type
        end

        unified_type
      else
        type
      end
    end
  end
end
