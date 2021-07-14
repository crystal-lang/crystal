# Implementation of the `crystal repl` command

class Crystal::Command
  private def repl
    decompile = false
    trace = false
    stats = false

    OptionParser.parse(options) do |opts|
      opts.banner = "Usage: crystal repl [options] [files]\n\nOptions:"

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    repl = Repl.new

    if options.empty?
      repl.run
    else
      filename = options.shift
      unless File.file?(filename)
        error "File '#{filename}' doesn't exist"
      end

      repl.run_file(filename, options)
    end
  end
end
