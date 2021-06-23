# Implementation of the `crystal repl` command

class Crystal::Command
  private def repl
    decompile = false
    trace = false
    stats = false

    OptionParser.parse(options) do |opts|
      opts.banner = "Usage: crystal repl [options] [files]\n\nOptions:"

      opts.on("-d", "--decompile", "Show decompilation") do
        decompile = true
      end

      opts.on("-s", "--status", "Show time taken to execute") do
        stats = true
      end

      opts.on("-t", "--trace", "Trace execution") do
        trace = true
      end

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    repl = Repl.new(
      decompile: decompile,
      decompile_defs: false,
      trace: trace,
      stats: stats,
    )

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
