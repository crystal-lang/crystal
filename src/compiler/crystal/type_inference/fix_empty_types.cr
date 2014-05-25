require "../ast"
require "../type_inference"

module Crystal
  class Program
    def fix_empty_types(node)
      visitor = FixEmptyTypesVisitor.new(self)
      node.accept visitor

      fix_empty_types_recursive types
    end

    def fix_empty_types_recursive(types)
      types.each do |name, type|
        type.fix_empty_types

        if type.is_a?(ContainedType) && !type.metaclass?
          fix_empty_types_recursive type.types
        end
      end
    end
  end

  class Type
    def fix_empty_types
      nil
    end
  end

  module InstanceVarContainer
    def fix_empty_types
      return unless allocated

      instance_vars.each do |name, var|
        unless var.type?
          var.bind_to(program.nil_var)
        end
      end

      nil
    end
  end

  class FixEmptyTypesVisitor < Visitor
    def initialize(mod)
      @mod = mod
      @fixed = Set(typeof(object_id)).new
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : Def)
      false
    end

    def visit(node : Macro)
      false
    end

    def end_visit(node : Call)
      node.target_defs.try &.each do |target_def|
        unless @fixed.includes?(target_def.object_id)
          @fixed.add(target_def.object_id)

          if !target_def.type? && target_def.owner.try &.allocated
            target_def.type = @mod.nil
          end

          target_def.accept_children self
        end
      end
    end
  end
end
