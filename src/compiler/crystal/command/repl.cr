{% skip_file if flag?(:without_interpreter) %}

# Implementation of the `crystal repl` command

class Crystal::Command
  private def repl
    repl = Repl.new

    option_parser = parse_with_crystal_opts do |opts|
      opts.banner = "Usage: crystal i [options] [programfile] [arguments]\n\nOptions:"

      opts.on("-D FLAG", "--define FLAG", "Define a compile-time flag") do |flag|
        repl.program.flags << flag
      end

      opts.on("--error-trace", "Show full error trace") do
        repl.program.show_error_trace = true
        @error_trace = true
      end

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      opts.on("--no-color", "Disable colored output") do
        @color = false
        repl.program.color = false
      end
    end

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
