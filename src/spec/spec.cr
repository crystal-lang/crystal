require "colorize"
require "option_parser"
require "signal"

module Spec
  COLORS = {
    success: :green,
    fail: :red,
    error: :red,
    pending: :yellow,
  }

  LETTERS = {
    success: '.',
    fail: 'F',
    error: 'E',
    pending: '*',
  }

  def self.color(str, status)
    str.colorize(COLORS[status])
  end

  class AssertionFailed < Exception
    getter file
    getter line

    def initialize(message, @file, @line)
      super(message)
    end
  end

  @@aborted = false

  def self.abort!
    @@aborted = true
  end

  def self.aborted?
    @@aborted
  end

  @@pattern = nil

  def self.pattern=(pattern)
    @@pattern = Regex.new(Regex.escape(pattern))
  end

  @@line = nil

  def self.line=(@@line)
  end

  def self.matches?(description, file, line)
    spec_pattern = @@pattern
    spec_line = @@line

    if line == spec_line
      return true
    elsif spec_pattern || spec_line
      Spec::RootContext.matches?(description, spec_pattern, spec_line)
    else
      true
    end
  end

  @@fail_fast = false

  def self.fail_fast=(@@fail_fast)
  end

  def self.fail_fast?
    @@fail_fast
  end

  def self.before_each(&block)
    before_each = @@before_each ||= [] of ->
    before_each << block
  end

  def self.after_each(&block)
    after_each = @@after_each ||= [] of ->
    after_each << block
  end

  def self.run_before_each_hooks
    @@before_each.try &.each &.call
  end

  def self.run_after_each_hooks
    @@after_each.try &.each &.call
  end
end

require "./*"

def describe(description, file = __FILE__, line = __LINE__)
  Spec::RootContext.describe(description.to_s, file, line) do |context|
    yield
  end
end

def context(description, file = __FILE__, line = __LINE__)
  describe(description.to_s, file, line) { |ctx| yield ctx }
end

def it(description, file = __FILE__, line = __LINE__)
  return if Spec.aborted?
  return unless Spec.matches?(description, file, line)

  Spec.formatter.before_example description

  Spec::RootContext.before.try &.call()
  begin
    Spec.run_before_each_hooks
    yield
    Spec::RootContext.report(:success, description, file, line)
  rescue ex : Spec::AssertionFailed
    Spec::RootContext.report(:fail, description, file, line, ex)
    Spec.abort! if Spec.fail_fast?
  rescue ex
    Spec::RootContext.report(:error, description, file, line, ex)
    Spec.abort! if Spec.fail_fast?
  ensure
    Spec.run_after_each_hooks
  end
  Spec::RootContext.after.try &.call()
end

def pending(description, file = __FILE__, line = __LINE__, &block)
  return if Spec.aborted?
  return unless Spec.matches?(description, file, line)

  Spec.formatter.before_example description

  Spec::RootContext.report(:pending, description, file, line)
end

def assert(file = __FILE__, line = __LINE__)
  it("assert", file, line) { yield }
end

def fail(msg, file = __FILE__, line = __LINE__)
  raise Spec::AssertionFailed.new(msg, file, line)
end

def before(&block : ->)
  Spec::RootContext.before = block
end

def after(&block : ->)
  Spec::RootContext.after = block
end

OptionParser.parse! do |opts|
  opts.banner = "crystal spec runner"
  opts.on("-e ", "--example STRING", "run examples whose full nested names include STRING") do |pattern|
    Spec.pattern = pattern
  end
  opts.on("-l ", "--line LINE", "run examples whose line matches LINE") do |line|
    Spec.line = line.to_i
  end
  opts.on("--fail-fast", "abort the run on first failure") do
    Spec.fail_fast = true
  end
  opts.on("--help", "show this help") do |pattern|
    puts opts
    exit
  end
  opts.on("-v", "--verbose", "verbose output") do
    Spec.formatter = Spec::VerboseFormatter.new
  end
end

Signal::INT.trap { Spec.abort! }

redefine_main do |main|
  time = Time.now
  {{main}}
  elapsed_time = Time.now - time
  Spec::RootContext.print_results(elapsed_time)
  exit 1 unless Spec::RootContext.succeeded
end
