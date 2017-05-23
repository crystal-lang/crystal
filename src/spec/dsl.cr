require "colorize"
require "option_parser"
require "signal"

module Spec
  private COLORS = {
    success: :green,
    fail:    :red,
    error:   :red,
    pending: :yellow,
    comment: :cyan,
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
  class AssertionFailed < Exception
    getter file : String
    getter line : Int32

    def initialize(message, @file, @line)
      super(message)
    end
  end

  @@aborted = false

  # :nodoc:
  def self.abort!
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

  # :nodoc:
  def self.matches?(description, file, line, end_line = line)
    spec_pattern = @@pattern
    spec_line = @@line
    locations = @@locations

    # When a method invokes `it` and only forwards line information,
    # not end_line information (this can happen in code before we
    # introduced the end_line feature) then running a spec by giving
    # a line won't work because end_line might be located before line.
    # So, we also check `line == spec_line` to somehow preserve
    # backwards compatibility.
    if spec_line && (line == spec_line || line <= spec_line <= end_line)
      return true
    end

    if locations
      lines = locations[file]?
      return true if lines && lines.any? { |l| line == l || line <= l <= end_line }
    end

    if spec_pattern || spec_line || locations
      Spec::RootContext.matches?(description, spec_pattern, spec_line, locations)
    else
      true
    end
  end

  @@fail_fast = false

  # :nodoc:
  def self.fail_fast=(@@fail_fast)
  end

  # :nodoc:
  def self.fail_fast?
    @@fail_fast
  end

  # Instructs the spec runner to execute the given block
  # before each spec, regardless of where this method is invoked.
  def self.before_each(&block)
    before_each = @@before_each ||= [] of ->
    before_each << block
  end

  # Instructs the spec runner to execute the given block
  # after each spec, regardless of where this method is invoked.
  def self.after_each(&block)
    after_each = @@after_each ||= [] of ->
    after_each << block
  end

  # :nodoc:
  def self.run_before_each_hooks
    @@before_each.try &.each &.call
  end

  # :nodoc:
  def self.run_after_each_hooks
    @@after_each.try &.each &.call
  end

  # :nodoc:
  def self.run
    start_time = Time.now
    at_exit do
      elapsed_time = Time.now - start_time
      Spec::RootContext.print_results(elapsed_time)
      exit 1 unless Spec::RootContext.succeeded
    end
  end
end

require "./*"
