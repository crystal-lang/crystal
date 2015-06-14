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
#   describe "#length" do
#     it "correctly reports the number of elements in the Array" do
#       [1, 2, 3].length.should eq 3
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
  # :nodoc:
  COLORS = {
    success: :green,
    fail: :red,
    error: :red,
    pending: :yellow,
  }

  # :nodoc:
  LETTERS = {
    success: '.',
    fail: 'F',
    error: 'E',
    pending: '*',
  }

  # :nodoc:
  def self.color(str, status)
    str.colorize(COLORS[status])
  end

  # :nodoc:
  class AssertionFailed < Exception
    getter file
    getter line

    def initialize(message, @file, @line)
      super(message)
    end
  end

  @@aborted = false

  # :nodoc:
  def self.abort!
    @@aborted = true
  end

  # :nodoc:
  def self.aborted?
    @@aborted
  end

  @@pattern = nil

  # :nodoc:
  def self.pattern=(pattern)
    @@pattern = Regex.new(Regex.escape(pattern))
  end

  @@line = nil

  # :nodoc:
  def self.line=(@@line)
  end

  # :nodoc:
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

  # :nodoc:
  def self.fail_fast=(@@fail_fast)
  end

  # :nodoc:
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

  # :nodoc:
  def self.run_before_each_hooks
    @@before_each.try &.each &.call
  end

  # :nodoc:
  def self.run_after_each_hooks
    @@after_each.try &.each &.call
  end
end

require "./*"

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
