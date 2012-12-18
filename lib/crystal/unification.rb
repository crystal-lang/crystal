require_relative 'type_inference.rb'

module Crystal
  def unify(node)
    visitor = UnifyVisitor.new
    while true
      visitor.start
      node.accept visitor
      break unless visitor.more?
    end
  end

  class Def
    attr_accessor :unified
  end

  class Dispatch
    attr_accessor :unified
  end

  class UnifyVisitor < Visitor
    def start
      @types = {}
      @unions = {}
      @pointers = {}
      @stack = []
      @pending_unions = []
    end

    def more?
      @pending_unions.each do |union|
        if unify_type(union).object_id != union.object_id
          return true
        end
      end
      false
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
          node.target_def.set_type unify_type(node.target_def.type)
        else
          node.target_def.owner = unify_type(node.target_def.owner)
        end
      end
      node.simplify
    end

    def end_visit_range_literal(node)
      node.expanded.accept self
    end

    def end_visit_regexp_literal(node)
      node.expanded.accept self
    end

    def end_visit_hash_literal(node)
      node.expanded.accept self
    end

    def end_visit_require(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_ident(node)
      node.target_const.value.accept self if node.target_const
    end

    def visit_case(node)
      node.expanded.accept self
      false
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
      when PointerType
        unified_type = @pointers[type]

        unless unified_type
          if index = @stack.index(type)
            unified_type = @pointers[type] = @stack[index]
          else
            @stack.push type

            unified_type = type
            unified_type.var.set_type unify_type(type.var.type)

            if existing_type = @pointers[type]
              unified_type = existing_type
            else
              @pointers[type] = unified_type
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
            @pending_unions << unified_type
          else
            @stack.push type

            unified_types = type.types.map { |subtype| unify_type(subtype) }.uniq
            unified_types = unified_types.length == 1 ? unified_types[0] : unify_type(UnionType.new(*unified_types))

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
