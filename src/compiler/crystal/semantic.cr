require "./program"
require "./syntax/ast"
require "./syntax/visitor"
require "./semantic/*"

# The overall algorithm for semantic analysis of a program is:
# - top level: declare clases, modules, macros, defs and other top-level stuff
# - new methods: create `new` methods for every `initialize` method
# - type declarations: process type declarations like `@x : Int32`
# - check abstract defs: check that abstract defs are implemented
# - class_vars_initializers (ClassVarsInitializerVisitor): process initializers like `@@x = 1`
# - instance_vars_initializers (InstanceVarsInitializerVisitor): process initializers like `@x = 1`
# - main: process "main" code, calls and method bodies (the whole program).
# - cleanup: remove dead code and other simplifications
# - check recursive structs (RecursiveStructChecker): check that structs are not recursive (impossible to codegen)

class Crystal::Program
  # Runs semantic analysis on the given node, returning a node
  # that's typed. In the process types and methods are defined in
  # this program.
  def semantic(node : ASTNode, cleanup = true) : ASTNode
    node, processor = top_level_semantic(node)

    @progress_tracker.stage("Semantic (ivars initializers)") do
      visitor = InstanceVarsInitializerVisitor.new(self)
      visit_with_finished_hooks(node, visitor)
      visitor.finish
    end

    @progress_tracker.stage("Semantic (cvars initializers)") do
      visit_class_vars_initializers(node)
    end

    # Check that class vars without an initializer are nilable,
    # give an error otherwise
    processor.check_non_nilable_class_vars_without_initializers

    result = @progress_tracker.stage("Semantic (main)") do
      visit_main(node, process_finished_hooks: true, cleanup: cleanup)
    end

    @progress_tracker.stage("Semantic (cleanup)") do
      cleanup_types
      cleanup_files
    end

    @progress_tracker.stage("Semantic (recursive struct check)") do
      RecursiveStructChecker.new(self).run
    end

    result
  end

  # Processes type declarations and instance/class/global vars
  # types are guessed or followed according to type annotations.
  #
  # This alone is useful for some tools like doc or hierarchy
  # where a full semantic of the program is not needed.
  def top_level_semantic(node)
    new_expansions = @progress_tracker.stage("Semantic (top level)") do
      visitor = TopLevelVisitor.new(self)
      node.accept visitor
      visitor.process_finished_hooks
      visitor.new_expansions
    end
    @progress_tracker.stage("Semantic (new)") do
      define_new_methods(new_expansions)
    end
    node, processor = @progress_tracker.stage("Semantic (type declarations)") do
      TypeDeclarationProcessor.new(self).process(node)
    end
    @progress_tracker.stage("Semantic (abstract def check)") do
      AbstractDefChecker.new(self).run
    end
    {node, processor}
  end
end
