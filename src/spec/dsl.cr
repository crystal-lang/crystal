require "colorize"
require "option_parser"

module Spec
  # :nodoc:
  enum InfoKind
    Comment
    Focus
    Order
  end

  private STATUS_COLORS = {
    Status::Success => :green,
    Status::Fail    => :red,
    Status::Error   => :red,
    Status::Pending => :yellow,
  }

  private INFO_COLORS = {
    InfoKind::Comment => :cyan,
    InfoKind::Focus   => :cyan,
    InfoKind::Order   => :cyan,
  }

  private LETTERS = {
    Status::Success => '.',
    Status::Fail    => 'F',
    Status::Error   => 'E',
    Status::Pending => '*',
  }

  # :nodoc:
  def self.color(str, status : Status)
    str.colorize(STATUS_COLORS[status])
  end

  # :nodoc:
  def self.color(str, kind : InfoKind)
    str.colorize(INFO_COLORS[kind])
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
  class ExamplePending < SpecError
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

  # Instructs the spec runner to execute the given block
  # before each spec in the spec suite.
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
    root_context.before_each(&block)
  end

  # Instructs the spec runner to execute the given block
  # after each spec in the spec suite.
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
    root_context.after_each(&block)
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
    root_context.before_all(&block)
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
    root_context.after_all(&block)
  end

  # Instructs the spec runner to execute the given block when each spec in the
  # spec suite runs.
  #
  # The block must call `run` on the given `Example::Procsy` object.
  #
  # If multiple blocks are registered they run in the reversed
  # order that they are given.
  #
  # ```
  # require "spec"
  #
  # Spec.around_each do |example|
  #   puts "runs before each sample"
  #   example.run
  #   puts "runs after each sample"
  # end
  #
  # it { }
  # it { }
  # ```
  def self.around_each(&block : Example::Procsy ->)
    root_context.around_each(&block)
  end

  @@start_time : Time::Span? = nil

  # :nodoc:
  def self.run
    @@start_time = Time.monotonic

    at_exit do
      log_setup
      maybe_randomize
      run_filters
      root_context.run
    rescue ex
      STDERR.print "Unhandled exception: "
      ex.inspect_with_backtrace(STDERR)
      STDERR.flush
      @@aborted = true
    ensure
      finish_run
    end
  end

  # :nodoc:
  #
  # Workaround for #8914
  private macro defined?(t)
    {% if t.resolve? %}
      {{ yield }}
    {% end %}
  end

  # :nodoc:
  def self.log_setup
  end

  # :nodoc:
  macro finished
    # :nodoc:
    #
    # Initialized the log module for the specs.
    # If the "log" module is required it is configured to emit no entries by default.
    def self.log_setup
      defined?(::Log) do
        if Log.responds_to?(:setup)
          Log.setup_from_env(default_level: :none)
        end
      end
    end
  end

  def self.finish_run
    elapsed_time = Time.monotonic - @@start_time.not_nil!
    root_context.finish(elapsed_time, @@aborted)
    exit 1 if !root_context.succeeded || @@aborted || (focus? && ENV["SPEC_FOCUS_NO_FAIL"]? != "1")
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
