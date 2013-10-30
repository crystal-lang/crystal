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
      @fixed = Set(Def).new
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
      return unless node.target_defs

      node.target_defs.not_nil!.each do |target_def|
        unless @fixed.includes?(target_def)
          @fixed.add(target_def)

          if !target_def.type? #&& target_def.owner.allocated
            target_def.type = @mod.nil
          end
          target_def.accept_children self
        end
      end
    end
  end
end
