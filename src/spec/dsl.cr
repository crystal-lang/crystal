require "colorize"
require "option_parser"

module Spec
  private COLORS = {
    success: :green,
    fail:    :red,
    error:   :red,
    pending: :yellow,
    comment: :cyan,
    focus:   :cyan,
  }

  private LETTERS = {
    success: '.',
    fail:    'F',
    error:   'E',
    pending: '*',
  }

  @@use_colors = true

  # :nodoc:
  def self.color(str, status)
    if use_colors?
      str.colorize(COLORS[status])
    else
      str
    end
  end

  # :nodoc:
  def self.use_colors?
    @@use_colors
  end

  # :nodoc:
  def self.use_colors=(@@use_colors)
  end

  # :nodoc:
  class SpecError < Exception
    getter file : String
    getter line : Int32

    def initialize(message, @file, @line)
      super(message)
    end
  end

  # :nodoc:
  class AssertionFailed < SpecError
  end

  # :nodoc:
  class NestingSpecError < SpecError
  end

  @@aborted = false

  # :nodoc:
  def self.abort!
    @@aborted = true
    exit
  end

  # :nodoc:
  def self.pattern=(pattern)
    @@pattern = Regex.new(Regex.escape(pattern))
  end

  # :nodoc:
  def self.line=(@@line : Int32)
  end

  # :nodoc:
  def self.slowest=(@@slowest : Int32)
  end

  # :nodoc:
  def self.slowest
    @@slowest
  end

  # :nodoc:
  def self.to_human(span : Time::Span)
    total_milliseconds = span.total_milliseconds
    if total_milliseconds < 1
      return "#{(span.total_milliseconds * 1000).round.to_i} microseconds"
    end

    total_seconds = span.total_seconds
    if total_seconds < 1
      return "#{span.total_milliseconds.round(2)} milliseconds"
    end

    if total_seconds < 60
      return "#{total_seconds.round(2)} seconds"
    end

    minutes = span.minutes
    seconds = span.seconds
    "#{minutes}:#{seconds < 10 ? "0" : ""}#{seconds} minutes"
  end

  # :nodoc:
  def self.add_location(file, line)
    locations = @@locations ||= {} of String => Array(Int32)
    lines = locations[File.expand_path(file)] ||= [] of Int32
    lines << line
  end

  record SplitFilter, remainder : Int32, quotient : Int32

  @@split_filter : SplitFilter? = nil

  def self.add_split_filter(filter)
    if filter
      r, m = filter.split('%').map &.to_i
      @@split_filter = SplitFilter.new(remainder: r, quotient: m)
    else
      @@split_filter = nil
    end
  end

  # :nodoc:
  class_property? fail_fast = false

  # :nodoc:
  class_property? focus = false

  # Instructs the spec runner to execute the given block
  # before each spec, regardless of where this method is invoked.
  #
  # If multiple blocks are registered they run in the order
  # that they are given.
  #
  # For example:
  #
  # ```
  # Spec.before_each { puts 1 }
  # Spec.before_each { puts 2 }
  # ```
  #
  # will print, just before each spec, 1 and then 2.
  def self.before_each(&block)
    before_each = @@before_each ||= [] of ->
    before_each << block
  end

  # Instructs the spec runner to execute the given block
  # after each spec, regardless of where this method is invoked.
  #
  # If multiple blocks are registered they run in the reversed
  # order that they are given.
  #
  # For example:
  #
  # ```
  # Spec.after_each { puts 1 }
  # Spec.after_each { puts 2 }
  # ```
  #
  # will print, just after each spec, 2 and then 1.
  def self.after_each(&block)
    after_each = @@after_each ||= [] of ->
    after_each << block
  end

  # Instructs the spec runner to execute the given block
  # before the entire spec suite.
  #
  # If multiple blocks are registered they run in the order
  # that they are given.
  #
  # For example:
  #
  # ```
  # Spec.before_suite { puts 1 }
  # Spec.before_suite { puts 2 }
  # ```
  #
  # will print, just before the spec suite starts, 1 and then 2.
  def self.before_suite(&block)
    before_suite = @@before_suite ||= [] of ->
    before_suite << block
  end

  # Instructs the spec runner to execute the given block
  # after the entire spec suite.
  #
  # If multiple blocks are registered they run in the reversed
  # order that they are given.
  #
  # For example:
  #
  # ```
  # Spec.after_suite { puts 1 }
  # Spec.after_suite { puts 2 }
  # ```
  #
  # will print, just after the spec suite ends, 2 and then 1.
  def self.after_suite(&block)
    after_suite = @@after_suite ||= [] of ->
    after_suite << block
  end

  # :nodoc:
  def self.run_before_each_hooks
    @@before_each.try &.each &.call
  end

  # :nodoc:
  def self.run_after_each_hooks
    @@after_each.try &.reverse_each &.call
  end

  # :nodoc:
  def self.run_before_suite_hooks
    @@before_suite.try &.each &.call
  end

  # :nodoc:
  def self.run_after_suite_hooks
    @@after_suite.try &.reverse_each &.call
  end

  # :nodoc:
  def self.run
    start_time = Time.monotonic

    at_exit do
      run_filters
      run_before_suite_hooks
      root_context.run
      run_after_suite_hooks
    ensure
      elapsed_time = Time.monotonic - start_time
      root_context.finish(elapsed_time, @@aborted)
      exit 1 unless root_context.succeeded && !@@aborted
    end
  end

  # :nodoc:
  def self.run_filters
    if pattern = @@pattern
      root_context.filter_by_pattern(pattern)
    end

    if line = @@line
      root_context.filter_by_line(line)
    end

    if locations = @@locations
      root_context.filter_by_locations(locations)
    end

    if split_filter = @@split_filter
      root_context.filter_by_split(split_filter)
    end

    if focus = @@focus
      root_context.filter_by_focus
    end
  end
end

require "./*"
