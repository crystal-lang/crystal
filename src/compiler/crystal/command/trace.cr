class Crystal::Command
  private def trace
    command = "stats"
    color = true

    OptionParser.parse(@options) do |opts|
      opts.banner = <<-USAGE
        Usage: crystal tool trace [command] [- | file or directory ...]

        Analyzes trace logs.

        If a file or directory is omitted, the 'trace.log' file in the
        working directory will be used. To analyze STDIN use '-' in place
        of any path arguments.

        Commands:
        USAGE

      opts.on("stats", "Generate stats from a trace file (default)") do
        command = "stats"
      end

      opts.on("--no-color", "Disable colored output") do
        color = false
      end

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    input = options.first? || "trace.log"

    case command
    when "stats"
      if input == "-" || File.exists?(input)
        Tracing::StatsGenerator.new(input, color: color).run
      else
        error "file '#{input}' does not exist"
      end
    end
  end
end
