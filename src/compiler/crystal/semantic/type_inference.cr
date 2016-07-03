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
  ValidDefAttributes         = %w(AlwaysInline Naked NoInline Raises ReturnsTwice Primitive)
  ValidFunDefAttributes      = %w(AlwaysInline Naked NoInline Raises ReturnsTwice CallConvention)
  ValidEnumDefAttributes     = %w(Flags)

  class Program
    # The overall algorithm for inferring a program's type is:
    # - top level (TopLevelVisitor): declare clases, modules, macros, defs and other top-level stuff
    # - check abstract defs (AbstractDefChecker): check that abstract defs are implemented
    # - type declarations (TypeDeclarationVisitor): process type declarations like `@x : Int32`
    # - instance_vars_initializers (InstanceVarsInitializerVisitor): process initializers like `@x = 1`
    # - class_vars_initializers (ClassVarsInitializerVisitor): process initializers like `@@x = 1`
    # - main: process "main" code, calls and method bodies (the whole program).
    # - check recursive structs (RecursiveStructChecker): check that structs are not recursive (impossible to codegen)
    def infer_type(node, stats = false)
      node, processor = infer_type_top_level(node, stats: stats)

      Crystal.timing("Semantic (cvars initializers)", stats) do
        visit_class_vars_initializers(node)
      end

      # Check that class vars without an initializer are nilable,
      # give an error otherwise
      processor.check_non_nilable_class_vars_without_initializers

      Crystal.timing("Semantic (ivars initializers)", stats) do
        visit_instance_vars_initializers(node)
      end
      result = Crystal.timing("Semantic (main)", stats) do
        visit_main(node)
      end
      Crystal.timing("Semantic (cleanup)", stats) do
        cleanup_types
        cleanup_files
      end
      Crystal.timing("Semantic (recursive struct check)", stats) do
        check_recursive_structs
      end
      result
    end

    # Processes type declarations and instance/class/global vars
    # types are guessed or followed according to type annotations.
    #
    # This alone is useful for some tools like doc or hierarchy
    # where a full semantic of the program is not needed.
    def infer_type_top_level(node, stats = false)
      Crystal.timing("Semantic (top level)", stats) do
        visit_top_level(node)
      end
      Crystal.timing("Semantic (new)", stats) do
        define_new_methods
      end
      Crystal.timing("Semantic (abstract def check)", stats) do
        check_abstract_defs
      end
      Crystal.timing("Semantic (type declarations)", stats) do
        visit_type_declarations(node)
      end
    end
  end

  class PropagateDocVisitor < Visitor
    @doc : String

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
