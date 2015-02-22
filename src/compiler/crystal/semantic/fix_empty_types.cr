require "../semantic/ast"
require "../semantic/type_inference"

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
      unless node.def.body.type?
        node.def.body.type = @mod.no_return
      end
      false
    end

    def visit(node : FunPointer)
      node.call.try &.accept self
      false
    end

    def end_visit(node : FunPointer)
      unless node.type?
        arg_types = node.call.args.map &.type
        arg_types.push @mod.no_return
        node.type = node.call.type = @mod.fun_of(arg_types)
      end
    end

    def visit(node : ExpandableNode)
      node.expanded.try &.accept self
      false
    end

    def end_visit(node : Call)
      node.target_defs.try &.each do |target_def|
        unless @fixed.includes?(target_def.object_id)
          @fixed.add(target_def.object_id)

          if !target_def.type? && target_def.owner.allocated
            target_def.type = @mod.no_return
          end

          target_def.accept_children self
        end
      end
    end
  end
end
