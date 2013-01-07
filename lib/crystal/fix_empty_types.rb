require_relative 'type_inference.rb'

module Crystal
  def fix_empty_types(node, mod)
    node.accept FixEmptyTypesVisitor.new(mod)
  end

  class FixEmptyTypesVisitor < Visitor
    def initialize(mod)
      @mod = mod
      @fixed = {}
    end

    def visit_any(node)
      fix_node(node)
    end

    def visit_def(node)
      false
    end

    def visit_macro(node)
      false
    end

    def end_visit_call(node)
      return if @fixed[node.target_def]
      @fixed[node.target_def] = true

      if node.target_def
        node.target_def.type = @mod.nil unless node.target_def.type
        node.target_def.accept_children self
      end
    end

    def end_visit_array_literal(node)
      node.expanded.accept self if node.expanded
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

    def visit_case(node)
      node.expanded.accept self
      false
    end

    def fix_node(node)
      fix_type(node.type) if node.type
    end

    def fix_type(type)
      return if @fixed[type.object_id]
      @fixed[type.object_id] = true

      case type
      when ObjectType
        type.instance_vars.each do |name, ivar|
          fix_node(ivar)
        end
      when PointerType
        type.var.type = @mod.nil unless type.var.type
      when UnionType
        type.types.each do |type|
          fix_type(type)
        end
      end
    end
  end
end