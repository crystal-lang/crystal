require "spec"

class Spec::CLI
  def main(args)
    return previous_def unless args[0]? == "pu"

    args.shift # Remove "pu" from the arguments

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
    when Nil
    else
      ::abort "Unknown process util command: #{command}"
    end

    exit exit_status
  end
end
