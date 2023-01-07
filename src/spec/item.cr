module Spec
  # Info that `describe`, `context` and `it` all have in common.
  module Item
    # The `describe`/`context` that wraps this example or example group.
    getter parent : Context

    # The example or example group's description.
    getter description : String

    # The file where the example or example group is defined.
    getter file : String

    # The line where the example or example group starts.
    getter line : Int32

    # The line where the example or example group ends.
    getter end_line : Int32

    # Does this example or example group have `focus: true` on it?
    getter? focus : Bool

    # The tags defined on this example or example group
    getter tags : Set(String)?

    private def initialize_tags(tags)
      @tags = tags.is_a?(String) ? Set{tags} : tags.try(&.to_set)
    end

    # All tags, including tags inherited from ancestor example groups
    def all_tags : Set(String)
      result = tags.nil? ? Set(String).new : tags.not_nil!.dup
      return result if parent.is_a?(RootContext)

      ancestor = parent.as(ExampleGroup)
      loop do
        result.concat(ancestor.tags.not_nil!) unless ancestor.tags.nil?

        return result if ancestor.parent.is_a?(RootContext)
        ancestor = ancestor.parent.as(ExampleGroup)
      end
      result
    end
  end
end
