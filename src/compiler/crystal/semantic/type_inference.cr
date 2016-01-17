require "../program"
require "../syntax/ast"
require "../syntax/visitor"
require "./*"

module Crystal
  ThreadLocalAttributes      = %w(ThreadLocal)
  ValidGlobalAttributes      = ThreadLocalAttributes
  ValidExternalVarAttributes = ThreadLocalAttributes
  ValidClassVarAttributes    = ThreadLocalAttributes
  ValidStructDefAttributes   = %w(Packed)
  ValidDefAttributes         = %w(AlwaysInline Naked NoInline Raises ReturnsTwice)
  ValidFunDefAttributes      = %w(AlwaysInline Naked NoInline Raises ReturnsTwice CallConvention)
  ValidEnumDefAttributes     = %w(Flags)

  class Program
    def infer_type(node)
      result = first_pass(node)
      result = infer_type_intermediate(node)
      finish_types
      check_hierarchy_errors
      result
    end

    def infer_type_intermediate(node)
      node.accept TypeVisitor.new(self)

      loop do
        expand_macro_defs
        fix_empty_types node
        node = after_type_inference node

        # The above might have produced more macro def expansions,
        # so we need to take care of these too
        break if @def_macros.empty?
      end

      node
    end
  end

  class PropagateDocVisitor < Visitor
    def initialize(@doc)
    end

    def visit(node : Expressions)
      true
    end

    def visit(node : ClassDef | ModuleDef | EnumDef | Def | FunDef | Alias | Assign)
      node.doc ||= @doc
      false
    end

    def visit(node : ASTNode)
      true
    end
  end
end
