require "./item"
require "./example"
require "./context"

module Spec
  module Item
    def matches_pattern?(pattern : Regex) : Bool
      !!(@description =~ pattern)
    end

    def matches_line?(line : Int32) : Bool
      @line == line || @line <= line <= @end_line
    end

    def matches_locations?(locations : Hash(String, Array(Int32))) : Bool
      lines = locations[file]?
      !!(lines && lines.any? { |line| matches_line?(line) })
    end
  end

  class RootContext
    def filter_by_pattern(pattern : Regex)
      children.select!(&.filter_by_pattern(pattern))
    end

    def filter_by_line(line : Int32)
      children.select!(&.filter_by_line(line))
    end

    def filter_by_locations(locations : Hash(String, Array(Int32)))
      children.select!(&.filter_by_locations(locations))
    end

    def filter_by_focus
      children.select!(&.filter_by_focus)
    end

    def filter_by_split(split_filter : SplitFilter)
      children.select!(&.filter_by_split(split_filter))
    end
  end

  class NestedContext
    # Filters a context and its children by pattern.
    # Returns `true` if the context matches the pattern, `false` otherwise.
    def filter_by_pattern(pattern : Regex) : Bool
      return true if matches_pattern?(pattern)

      children.select!(&.filter_by_pattern(pattern))
      !children.empty?
    end

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

    # Filters a context and its children that are marked as focus.
    # Returns `true` if the context or any of its children have focus,
    # `false` otherwise.
    def filter_by_focus : Bool
      return true if focus?

      children.select!(&.filter_by_focus)
      !children.empty?
    end

    # Filters a context and its children by the given split filter
    # Returns `true` if the context matches the filter, `false` otherwise.
    def filter_by_split(split_filter : SplitFilter) : Bool
      children.select!(&.filter_by_split(split_filter))
      !children.empty?
    end
  end

  class Example
    # Returns `true` if the example matches the pattern,
    # `false` otherwise.
    def filter_by_pattern(pattern : Regex) : Bool
      matches_pattern?(pattern)
    end

    # Returns `true` if the example is contained in the given line,
    # `false` otherwise.
    def filter_by_line(line : Int32) : Bool
      matches_line?(line)
    end

    # Returns `true` if the example is contained in the any of the given locations,
    # `false` otherwise.
    def filter_by_locations(locations : Hash(String, Array(Int32))) : Bool
      matches_locations?(locations)
    end

    # Returns `true` if this example is marked as focus, `false` otherwise
    def filter_by_focus : Bool
      @focus
    end

    @@example_counter = -1

    # Returns `true` if the example is matches the given split filter,
    # `false` otherwise.`
    def filter_by_split(split_filter : SplitFilter) : Bool
      @@example_counter += 1
      @@example_counter % split_filter.quotient == split_filter.remainder
    end
  end
end
