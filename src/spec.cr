require "colorize"
require "option_parser"
require "signal"

# Crystal's builtin testing library.
#
# A basic spec looks like this:
#
# ```
# require "spec"
#
# describe "Array" do
#   describe "#size" do
#     it "correctly reports the number of elements in the Array" do
#       [1, 2, 3].size.should eq 3
#     end
#   end
#
#   describe "#empty?" do
#     it "is empty when no elements are in the array" do
#       ([] of Int32).empty?.should be_true
#     end
#
#     it "is not empty if there are elements in the array" do
#       [1].empty?.should be_false
#     end
#   end
#
#   # lots of more specs
#
# end
# ```
#
# With `describe` and a descriptive string test files are structured.
# There commonly is one top level `describe` that defines which greater unit,
# such as a class, is tested in this spec file. Further `describe` calls can
# be nested within to specify smaller units under test like individual methods.
# It can also be used to set up a certain context - think empty Array versus
# Array with elements. There is also the `context` method that behaves just like
# `describe` but has a lightly different meaning to the reader.
#
# Concrete test cases are defined with `it` within a `describe` block. A
# descriptive string is supplied to `it` describing what that test case
# tests specifically.
#
# Specs then use the `should` method to verify that the expected value is
# returned, see the example above for details.
#
# By convention, specs live in the `spec` directory of a project. You can compile
# and run the specs of a project by running:
#
# ```
# crystal spec
# ```
#
# Also, you can compile and run individual spec files by providing their path:
#
# ```
# crystal spec spec/my/test/file_spec.cr
# ```
#
# In addition, you can also run individual specs by optionally providing a line
# number:
#
# ```
# crystal spec spec/my/test/file_spec.cr:14
# ```
module Spec
  private COLORS = {
    success: :green,
    fail:    :red,
    error:   :red,
    pending: :yellow,
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

require "./spec/*"

OptionParser.parse! do |opts|
  opts.banner = "crystal spec runner"
  opts.on("-e ", "--example STRING", "run examples whose full nested names include STRING") do |pattern|
    Spec.pattern = pattern
  end
  opts.on("-l ", "--line LINE", "run examples whose line matches LINE") do |line|
    Spec.line = line.to_i
  end
  opts.on("-p", "--profile", "Print the 10 slowest specs") do
    Spec.slowest = 10
  end
  opts.on("--fail-fast", "abort the run on first failure") do
    Spec.fail_fast = true
  end
  opts.on("--location file:line", "run example at line 'line' in file 'file', multiple allowed") do |location|
    if location =~ /\A(.+?)\:(\d+)\Z/
      Spec.add_location $1, $2.to_i
    else
      puts "location #{location} must be file:line"
      exit
    end
  end
  opts.on("--junit_output OUTPUT_DIR", "generate JUnit XML output") do |output_dir|
    junit_formatter = Spec::JUnitFormatter.file(output_dir)
    Spec.add_formatter(junit_formatter)
  end
  opts.on("--help", "show this help") do |pattern|
    puts opts
    exit
  end
  opts.on("-v", "--verbose", "verbose output") do
    Spec.override_default_formatter(Spec::VerboseFormatter.new)
  end
  opts.on("--no-color", "Disable colored output") do
    Spec.use_colors = false
  end
  opts.unknown_args do |args|
  end
end

unless ARGV.empty?
  puts "Error: unknown argument '#{ARGV.first}'"
  exit 1
end

Signal::INT.trap { Spec.abort! }

Spec.run
