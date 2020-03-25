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
    order:   :cyan,
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
    finish_run
  end

  # :nodoc:
  class_getter randomizer_seed : UInt64?
  class_getter randomizer : Random::PCG32?

  # :nodoc:
  def self.order=(mode)
    seed =
      case mode
      when "default"
        nil
      when "random"
        Random::Secure.rand(1..99999).to_u64 # 5 digits or less for simplicity
      when UInt64
        mode
      else
        raise ArgumentError.new("order must be either 'default', 'random', or a numeric seed value")
      end

    @@randomizer_seed = seed
    @@randomizer = seed ? Random::PCG32.new(seed) : nil
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

  # :nodoc:
  def self.add_tag(tag)
    if anti_tag = tag.lchop?('~')
      (@@anti_tags ||= Set(String).new) << anti_tag
    else
      (@@tags ||= Set(String).new) << tag
    end
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

  @@start_time : Time::Span? = nil

  # :nodoc:
  def self.run
    @@start_time = Time.monotonic

    at_exit do
      maybe_randomize
      run_filters
      run_before_suite_hooks
      root_context.run
      run_after_suite_hooks
    ensure
      finish_run
    end
  end

  def self.finish_run
    elapsed_time = Time.monotonic - @@start_time.not_nil!
    root_context.finish(elapsed_time, @@aborted)
    exit 1 if !root_context.succeeded || @@aborted
  end

  # :nodoc:
  def self.maybe_randomize
    if randomizer = @@randomizer
      root_context.randomize(randomizer)
    end
  end

  # :nodoc:
  def self.run_filters
    root_context.run_filters(@@pattern, @@line, @@locations, @@split_filter, @@focus, @@tags, @@anti_tags)
  end
end

require "./*"
