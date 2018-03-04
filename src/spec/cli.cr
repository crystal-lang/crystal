require "./formatter"
require "option_parser"

module Spec
  # :nodoc:
  class CLI
    # :nodoc:
    class Options
      property formatters = Array(Spec::Formatter).new
      property locations = Array({String, Int32}).new

      property? default_formatter : Spec::Formatter?
      property? fail_fast : Bool = false
      property? line : Int32?
      property? no_color : Bool = false
      property? pattern : String?
      property? slowest : Int32?
    end

    getter options : Options

    private getter argv : Array(String)
    private getter parser = OptionParser.new
    private getter stderr : IO
    private getter stdout : IO

    private getter? prepared : Bool = false

    def initialize(@argv, *, @options = Options.new, @stderr = STDERR, @stdout = STDOUT)
      setup
    end

    def prepare
      return if prepared?

      parser.parse(argv)

      unless argv.empty?
        terminate "Error: unknown argument '#{argv.first}'"
      end

      if ENV["SPEC_VERBOSE"]? == "1"
        options.default_formatter = Spec::VerboseFormatter.new
      end
    ensure
      @prepared = true
    end

    def run
      prepare
      apply_options

      Signal::INT.trap { Spec.abort! }

      Spec.run
    end

    private def apply_options
      if pattern = options.pattern?
        Spec.pattern = pattern
      end

      if line = options.line?
        Spec.line = line
      end

      if slowest = options.slowest?
        Spec.slowest = slowest
      end

      Spec.fail_fast = options.fail_fast?

      if options.no_color?
        Spec.use_colors = false
      end

      options.locations.each do |file, line|
        Spec.add_location file, line
      end

      options.formatters.each do |formatter|
        Spec.add_formatter formatter
      end

      if formatter = options.default_formatter?
        Spec.override_default_formatter formatter
      end
    end

    private def setup
      parser.banner = "crystal spec runner"

      parser.on("-e ", "--example STRING", "run examples whose full nested names include STRING") do |pattern|
        options.pattern = pattern
      end

      parser.on("-l ", "--line LINE", "run examples whose line matches LINE") do |line|
        options.line = line.to_i
      end

      parser.on("-p", "--profile", "Print the 10 slowest specs") do
        options.slowest = 10
      end

      parser.on("--fail-fast", "abort the run on first failure") do
        options.fail_fast = true
      end

      parser.on("--location file:line", "run example at line 'line' in file 'file', multiple allowed") do |location|
        if location =~ /\A(.+?)\:(\d+)\Z/
          options.locations << {$1, $2.to_i}
        else
          terminate "location #{location} must be file:line"
        end
      end

      parser.on("--junit_output OUTPUT_DIR", "generate JUnit XML output") do |output_dir|
        junit_formatter = Spec::JUnitFormatter.file(output_dir)
        options.formatters << junit_formatter
      end

      parser.on("--help", "show this help") do |pattern|
        display parser
      end

      parser.on("-v", "--verbose", "verbose output") do
        options.default_formatter = Spec::VerboseFormatter.new
      end

      parser.on("--no-color", "Disable colored output") do
        options.no_color = true
      end

      parser.unknown_args do |args|
      end
    end

    private def display(message)
      stdout.puts message
      exit
    end

    private def terminate(message, status = 1)
      stderr.puts message
      exit status
    end
  end
end
