require "../ast"
require "../type_inference"

module Crystal
  class Program
    def fix_empty_types(node)
      visitor = FixEmptyTypesVisitor.new(self)
      node.accept visitor
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

    def visit(node : FunLiteral)
      node.def.body.accept self
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
