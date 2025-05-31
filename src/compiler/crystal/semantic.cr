require "./program"
require "./syntax/ast"
require "./syntax/visitor"
require "./semantic/*"

# The overall algorithm for semantic analysis of a program is:
# - top level: declare classes, modules, macros, defs and other top-level stuff
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
  def semantic(node : ASTNode, cleanup = true, main_visitor : MainVisitor = MainVisitor.new(self)) : ASTNode
    node, processor = top_level_semantic(node, main_visitor)

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
      visit_main(node, process_finished_hooks: true, cleanup: cleanup, visitor: main_visitor)
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
  def top_level_semantic(node, main_visitor : MainVisitor = MainVisitor.new(self))
    new_expansions = @progress_tracker.stage("Semantic (top level)") do
      visitor = TopLevelVisitor.new(self)

      # This is mainly for the interpreter so that vars are populated
      # for macro calls.
      # For compiled Crystal this should have no effect because we always
      # use a new MainVisitor which will have no vars.
      visitor.vars = main_visitor.vars.dup unless main_visitor.vars.empty?

      node.accept visitor
      begin
        visitor.process_finished_hooks
      rescue ex : SkipMacroCodeCoverageException
        self.coverage_interrupt_exception = ex.cause
      end
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

    unless @program.has_flag?("no_restrictions_augmenter")
      @progress_tracker.stage("Semantic (restrictions augmenter)") do
        node.accept RestrictionsAugmenter.new(self, new_expansions)
      end
    end

    self.top_level_semantic_complete = true

    {node, processor}
  end

  # This property indicates that the compiler has finished the top-level semantic
  # stage.
  # At this point, instance variables are declared and macros `#instance_vars`
  # and `#has_internal_pointers?` provide meaningful information.
  #
  # FIXME: Introduce a more generic method to track progress of compiler stages
  # (potential synergy with `ProcessTracker`?).
  property? top_level_semantic_complete = false
end
