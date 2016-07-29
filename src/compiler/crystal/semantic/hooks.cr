module Crystal
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
