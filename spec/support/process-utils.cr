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
