module Crystal
  class Program
    record FinishedHook, scope : ModuleType, macro : Macro, node : ASTNode
    getter finished_hooks = [] of FinishedHook

    def add_finished_hook(scope, a_macro, node)
      @finished_hooks << FinishedHook.new(scope, a_macro, node)
    end

    # Visit all finished hooks with the given visitor
    def process_finished_hooks(visitor)
      @finished_hooks.each do |hook|
        if visitor.is_a?(SemanticVisitor)
          old_type = visitor.current_type.as(ModuleType)
          visitor.current_type = hook.scope
          hook.node.accept(visitor)
          visitor.current_type = old_type
        else
          hook.node.accept(visitor)
        end
      end
    end

    def visit_with_finished_hooks(node, visitor)
      node.accept visitor
      process_finished_hooks visitor
    end
  end

  # Holds hook expansions.
  #
  # For example, a `ClassDef` node will include macro exapnsions
  # that result from the `inherited` hook. So in this code:
  #
  # ```
  # class Foo
  #   macro inherited
  #     puts 1
  #   end
  # end
  #
  # class Bar < Foo
  # end
  # ```
  #
  # The AST node for the Bar class declaration (a `ClassDef`)
  # will include a hook expansion consisting of `puts 1`, that
  # is typed and executed before Bar's body.
  module HookExpansionsContainer
    getter hook_expansions : Array(ASTNode)?

    def add_hook_expansion(node)
      expansions = @hook_expansions ||= [] of ASTNode
      expansions << node
    end
  end

  class ClassDef
    # Hook expansions correspond to the `inherited` hook
    #
    # ```
    # class Foo
    #   macro inherited
    #     puts 1
    #   end
    # end
    #
    # # At this point the `inherited` hook is triggered
    # class Bar < Foo
    # end
    # ```
    include HookExpansionsContainer
  end

  class Include
    # Hook expansions correspond to the `included` hook
    #
    # ```
    # module Moo
    #   macro extended
    #     puts 1
    #   end
    # end
    #
    # class Foo
    #   # At this point the `included` hook is triggered
    #   include Moo
    # end
    # ```
    include HookExpansionsContainer
  end

  class Extend
    # Hook expansions correspond to the `extended` hook
    #
    # ```
    # module Moo
    #   macro extended
    #     puts 1
    #   end
    # end
    #
    # class Foo
    #   # At this point the `extended` hook is triggered
    #   extend Moo
    # end
    # ```
    include HookExpansionsContainer
  end

  class Def
    # Hook expansions correspond to the `method_added` hook
    #
    # ```
    # class Foo
    #   macro method_added(method)
    #     # ...
    #   end
    #
    #   # At this point the `method_added` hook is triggered
    #   def foo
    #   end
    # end
    # ```
    include HookExpansionsContainer
  end
end
