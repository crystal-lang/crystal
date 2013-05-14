require_relative 'type_inference.rb'

module Crystal
  def fix_empty_types(node, mod)
    visitor = FixEmptyTypesVisitor.new(mod)
    node.accept visitor
    fix_empty_types_in_types mod.types, visitor, true
    fix_empty_types_in_types mod.generic_types, visitor, false
  end

  def fix_empty_types_in_types(types, visitor, skip_generics)
    types.each do |name, type|
      unless type.generic && skip_generics
        visitor.fix_type type
      end
      if type.is_a?(ModuleType) && type.types
        fix_empty_types_in_types type.types, visitor, skip_generics
      end
    end
  end

  class FixEmptyTypesVisitor < Visitor
    def initialize(mod)
      @mod = mod
      @fixed = {}
    end

    def visit_def(node)
      false
    end

    def visit_macro(node)
      false
    end

    def end_visit_call(node)
      return unless node.target_defs

      node.target_defs.each do |target_def|
        next if @fixed[target_def]
        @fixed[target_def] = true

        if target_def
          target_def.type = @mod.nil unless target_def.type
          target_def.accept_children self
        end
      end
    end

    def visit_array_literal(node)
      node.expanded.accept self if node.expanded
      false
    end

    def visit_range_literal(node)
      node.expanded.accept self if node.expanded
      false
    end

    def visit_regexp_literal(node)
      node.expanded.accept self if node.expanded
      false
    end

    def visit_hash_literal(node)
      node.expanded.accept self if node.expanded
      false
    end

    def visit_require(node)
      node.expanded.accept self if node.expanded
      false
    end

    def visit_and(node)
      node.expanded.accept self if node.expanded
      false
    end

    def visit_or(node)
      node.expanded.accept self if node.expanded
      false
    end

    def end_visit_ident(node)
      node.target_const.value.accept self if node.target_const
    end

    def visit_case(node)
      node.expanded.accept self
      false
    end

    def fix_type(type)
      return if @fixed[type.object_id]
      @fixed[type.object_id] = true

      case type
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