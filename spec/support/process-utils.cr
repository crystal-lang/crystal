require "option_parser"

# `process-utils` are a set of simple command line tools required for
# testing process spawn behaviour in `spec/std/process_spec.cr`.
# It can be built into the spec executable which can just spawn itself
# with `pu` as first argument, followed by the command name.
# Alternatively, it can be built as a standalone executable which
# we use for interpreter tests because in interpreted mode there is
# no executable we could call again.
{% if @type.has_constant?(:Spec) %}
  class Spec::CLI
    def main(args)
      return previous_def unless args[0]? == "pu"

      ProcessUtils.main(args[1..])
    end
  end
{% else %}
  args = ARGV
  if args[0]?.in?("pu", "--")
    args = args[1..]
  end
  ProcessUtils.main(args)
{% end %}

# Provides simple helper programs for testing process spawn behaviour in `spec/std/process_spec.cr`.
# The commands similar to coreutils, but much simplified and tailored for
# the testing needs.
module ProcessUtils
  def self.main(args)

    output = STDOUT
    exit_status = 0

    OptionParser.parse(args) do |opts|
      opts.on("", "--exit status", "Exit with the given status code") do |status|
        exit_status = status.to_i
      end
      opts.on("", "--stderr", "Write to stderr instead of stdout") do
        output = STDERR
      end
    end

    case command = args.shift?
    when "cat"
      IO.copy(STDIN, output)
    when "echo"
      args.each do |line|
        output.puts line
      end
    when "env"
      ENV.each do |key, value|
        output.puts "#{key}=#{value}"
      end
    when "exit"
      exit args[0].to_i
    when "long-output"
      output.puts "." * 8000
    when "pwd"
      output.puts Dir.current
    when "sleep"
      sleep
    else
      ::abort "Unknown process util command: #{command}"
    end

    exit exit_status
  end
end
