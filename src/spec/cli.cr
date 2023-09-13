require "option_parser"

# This file is included in the compiler to add usage instructions for the
# spec runner on `crystal spec --help`.

module Spec
  # :nodoc:
  class_property pattern : Regex?

  # :nodoc:
  class_property line : Int32?

  # :nodoc:
  class_property slowest : Int32?

  # :nodoc:
  class_property? fail_fast = false

  # :nodoc:
  class_property? focus = false

  # :nodoc:
  def self.add_location(file, line)
    locations = @@locations ||= {} of String => Array(Int32)
    locations.put_if_absent(File.expand_path(file)) { [] of Int32 } << line
  end

  # :nodoc:
  def self.add_tag(tag)
    if anti_tag = tag.lchop?('~')
      (@@anti_tags ||= Set(String).new) << anti_tag
    else
      (@@tags ||= Set(String).new) << tag
    end
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
        raise ArgumentError.new("Order must be either 'default', 'random', or a numeric seed value")
      end

    @@randomizer_seed = seed
    @@randomizer = seed ? Random::PCG32.new(seed) : nil
  end

  # :nodoc:
  class_property option_parser : OptionParser = begin
    OptionParser.new do |opts|
      opts.banner = "crystal spec runner"
      opts.on("-e", "--example STRING", "run examples whose full nested names include STRING") do |pattern|
        Spec.pattern = Regex.new(Regex.escape(pattern))
      end
      opts.on("-l", "--line LINE", "run examples whose line matches LINE") do |line|
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
          STDERR.puts "location #{location} must be file:line"
          exit 1
        end
      end
      opts.on("--tag TAG", "run examples with the specified TAG, or exclude examples by adding ~ before the TAG.") do |tag|
        Spec.add_tag tag
      end
      opts.on("--order MODE", "run examples in random order by passing MODE as 'random' or to a specific seed by passing MODE as the seed value") do |mode|
        if mode.in?("default", "random")
          Spec.order = mode
        elsif seed = mode.to_u64?
          Spec.order = seed
        else
          abort("order must be either 'default', 'random', or a numeric seed value")
        end
      end
      opts.on("--junit_output OUTPUT_PATH", "generate JUnit XML output within the given OUTPUT_PATH") do |output_path|
        configure_formatter("junit", output_path)
      end
      opts.on("-h", "--help", "show this help") do |pattern|
        puts opts
        exit
      end
      opts.on("-v", "--verbose", "verbose output") do
        configure_formatter("verbose")
      end
      opts.on("--tap", "Generate TAP output (Test Anything Protocol)") do
        configure_formatter("tap")
      end
      opts.on("--color", "Enabled ANSI colored output") do
        Colorize.enabled = true
      end
      opts.on("--no-color", "Disable ANSI colored output") do
        Colorize.enabled = false
      end
      opts.unknown_args do |args|
      end
    end
  end

  # :nodoc:
  #
  # Blank implementation to reduce the interface of spec's option parser for
  # inclusion in the compiler. This avoids depending on more of `Spec`
  # module.
  # The real implementation in `../spec.cr` overrides this for actual use.
  def self.configure_formatter(formatter, output_path = nil)
  end
end
