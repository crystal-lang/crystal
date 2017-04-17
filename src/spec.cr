require "./spec/dsl"

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
# It can also be used to set up a certain context - think empty `Array` versus
# `Array` with elements. There is also the `context` method that behaves just like
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
# ```shell
# crystal spec
# ```
#
# Also, you can compile and run individual spec files by providing their path:
#
# ```shell
# crystal spec spec/my/test/file_spec.cr
# ```
#
# In addition, you can also run individual specs by optionally providing a line
# number:
#
# ```shell
# crystal spec spec/my/test/file_spec.cr:14
# ```
module Spec
end

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

if ENV["SPEC_VERBOSE"]? == "1"
  Spec.override_default_formatter(Spec::VerboseFormatter.new)
end

Signal::INT.trap { Spec.abort! }

Spec.run
