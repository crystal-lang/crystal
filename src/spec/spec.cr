require "colorize"
require "option_parser"
require "signal"

module Spec
  record Result, kind, description, exception

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

  def self.matches?(description)
    pattern = @@pattern
    if pattern
      Spec::RootContext.matches?(description, pattern)
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
end

require "./*"

def describe(description)
  Spec::RootContext.describe(description) do |context|
    yield
  end
end

def it(description)
  return if Spec.aborted?
  return unless Spec.matches?(description)

  Spec.formatter.before_example description

  begin
    yield
    Spec::RootContext.report(:success, description)
  rescue ex : Spec::AssertionFailed
    Spec::RootContext.report(:fail, description, ex)
    Spec.abort! if Spec.fail_fast?
  rescue ex
    Spec::RootContext.report(:error, description, ex)
    Spec.abort! if Spec.fail_fast?
  end
end

def pending(description, &block)
  return if Spec.aborted?
  return unless Spec.matches?(description)

  Spec.formatter.before_example description

  Spec::RootContext.report(:pending, description)
end

def assert
  it("assert") { yield }
end

def fail(msg)
  raise Spec::AssertionFailed.new(msg)
end

OptionParser.parse! do |opts|
  opts.banner = "crystal spec runner"
  opts.on("-e ", "--example STRING", "run examples whose full nested names include STRING") do |pattern|
    Spec.pattern = pattern
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

Signal.trap(Signal::INT) { Spec.abort! }

redefine_main do |main|
  time = Time.now
  {{main}}
  elapsed_time = Time.now - time
  Spec::RootContext.print_results(elapsed_time)
  exit 1 unless Spec::RootContext.succeeded
end
