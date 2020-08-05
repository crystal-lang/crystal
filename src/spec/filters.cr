require "./item"
require "./example"
require "./context"

module Spec
  module Item
    # :nodoc:
    def matches_pattern?(pattern : Regex) : Bool
      !!(@description =~ pattern)
    end

    # :nodoc:
    def matches_line?(line : Int32) : Bool
      @line == line || @line <= line <= @end_line
    end

    # :nodoc:
    def matches_locations?(locations : Hash(String, Array(Int32))) : Bool
      lines = locations[file]?
      !!(lines && lines.any? { |line| matches_line?(line) })
    end

    # :nodoc:
    def matches_tags?(tags : Set(String)) : Bool
      if t = @tags
        tags.intersects?(t)
      else
        false
      end
    end
  end

  class RootContext
    # :nodoc:
    def run_filters(pattern = nil, line = nil, locations = nil, split_filter = nil, focus = nil, tags = nil, anti_tags = nil)
      filter_by_pattern(pattern) if pattern
      filter_by_line(line) if line
      filter_by_locations(locations) if locations
      filter_by_split(split_filter) if split_filter
      filter_by_focus if focus
      filter_by_tags(tags) if tags
      filter_by_anti_tags(anti_tags) if anti_tags
    end

    # :nodoc:
    def filter_by_pattern(pattern : Regex)
      children.select!(&.filter_by_pattern(pattern))
    end

    # :nodoc:
    def filter_by_line(line : Int32)
      children.select!(&.filter_by_line(line))
    end

    # :nodoc:
    def filter_by_locations(locations : Hash(String, Array(Int32)))
      children.select!(&.filter_by_locations(locations))
    end

    # :nodoc:
    def filter_by_focus
      children.select!(&.filter_by_focus)
    end

    # :nodoc:
    def filter_by_tags(tags : Set(String))
      children.select!(&.filter_by_tags(tags))
    end

    # :nodoc:
    def filter_by_anti_tags(anti_tags : Set(String))
      children.select!(&.filter_by_anti_tags(anti_tags))
    end

    # :nodoc:
    def filter_by_split(split_filter : SplitFilter)
      children.select!(&.filter_by_split(split_filter))
    end
  end

  class ExampleGroup
    # :nodoc:
    #
    # Filters a context and its children by pattern.
    # Returns `true` if the context matches the pattern, `false` otherwise.
    def filter_by_pattern(pattern : Regex) : Bool
      return true if matches_pattern?(pattern)

      children.select!(&.filter_by_pattern(pattern))
      !children.empty?
    end

    # :nodoc:
    #
    # Filters a context and its children by line.
    # Returns `true` if the context matches the line, `false` otherwise.
    def filter_by_line(line : Int32) : Bool
      # If any children matches then we match too, but we filter children
      if children.any? &.matches_line?(line)
        children.select!(&.filter_by_line(line))
        return true
      end

      # Otherwise check if we match. If we do it means the line is inside
      # this context but outside a nested context or example, so then we
      # have to run all contexts and examples inside ourselves.
      if matches_line?(line)
        return true
      end

      false
    end

    # :nodoc:
    #
    # Filters a context and its children by the given locations.
    # Returns `true` if the context matches the locations, `false` otherwise.
    def filter_by_locations(locations : Hash(String, Array(Int32))) : Bool
      # If any children matches then we match too, but we filter children
      if children.any? &.matches_locations?(locations)
        children.select!(&.filter_by_locations(locations))
        return true
      end

      # Otherwise check if we match. If we do it means the line is inside
      # this context but outside a nested context or example, so then we
      # have to run all contexts and examples inside ourselves.
      if matches_locations?(locations)
        return true
      end

      false
    end

    # :nodoc:
    #
    # Filters a context and its children that are marked as focus.
    # Returns `true` if the context or any of its children have focus,
    # `false` otherwise.
    def filter_by_focus : Bool
      return true if focus?

      children.select!(&.filter_by_focus)
      !children.empty?
    end

    # :nodoc:
    #
    # Filters a context and its children by the given tags.
    # Returns `true` if the context matches the tags, `false` otherwise.
    def filter_by_tags(tags : Set(String)) : Bool
      return true if matches_tags?(tags)

      children.select!(&.filter_by_tags(tags))
      !children.empty?
    end

    # :nodoc:
    #
    # Filters a context and its children by the given anti-tags.
    # Returns `false` if the context matches the anti_tags, `true` otherwise.
    def filter_by_anti_tags(anti_tags : Set(String)) : Bool
      return false if matches_tags?(anti_tags)

      children.select!(&.filter_by_anti_tags(anti_tags))
      !children.empty?
    end

    # :nodoc:
    #
    # Filters a context and its children by the given split filter
    # Returns `true` if the context matches the filter, `false` otherwise.
    def filter_by_split(split_filter : SplitFilter) : Bool
      children.select!(&.filter_by_split(split_filter))
      !children.empty?
    end
  end

  class Example
    # :nodoc:
    #
    # Returns `true` if the example matches the pattern,
    # `false` otherwise.
    def filter_by_pattern(pattern : Regex) : Bool
      matches_pattern?(pattern)
    end

    # :nodoc:
    #
    # Returns `true` if the example is contained in the given line,
    # `false` otherwise.
    def filter_by_line(line : Int32) : Bool
      matches_line?(line)
    end

    # :nodoc:
    #
    # Returns `true` if the example is contained in any of the given locations,
    # `false` otherwise.
    def filter_by_locations(locations : Hash(String, Array(Int32))) : Bool
      matches_locations?(locations)
    end

    # :nodoc:
    #
    # Returns `true` if this example is marked as focus, `false` otherwise
    def filter_by_focus : Bool
      @focus
    end

    # :nodoc:
    #
    # Returns `true` if the example is tagged with any of the given tags,
    # `false` otherwise.
    def filter_by_tags(tags : Set(String)) : Bool
      matches_tags?(tags)
    end

    # :nodoc:
    #
    # Returns `false` if the example is tagged with any of the given anti_tags,
    # `true` otherwise.
    def filter_by_anti_tags(anti_tags : Set(String)) : Bool
      !matches_tags?(anti_tags)
    end

    @@example_counter = -1

    # :nodoc:
    #
    # Returns `true` if the example is matches the given split filter,
    # `false` otherwise.`
    def filter_by_split(split_filter : SplitFilter) : Bool
      @@example_counter += 1
      @@example_counter % split_filter.quotient == split_filter.remainder
    end
  end
end
