{% skip_file if flag?(:without_interpreter) %}
require "../config"

# Implementation of the `crystal repl` command

class Crystal::Command
  private def repl
    repl = Repl.new

    parse_with_crystal_opts do |opts|
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

      opts.on("--prelude ", "Use given file as prelude") do |prelude|
        repl.prelude = prelude
      end
    end

    if options.empty?
      show_banner
      repl.run
    else
      filename = options.shift
      unless File.file?(filename)
        error "File '#{filename}' doesn't exist"
      end

      show_banner
      repl.run_file(filename, options)
    end
  end

  private def show_banner
    return unless STDERR.tty? && !ENV.has_key?("CRYSTAL_INTERPRETER_SKIP_BANNER")

    formatted_sha = "[#{Config.build_commit}] " if Config.build_commit
    STDERR.puts "Crystal interpreter #{Config.version} #{formatted_sha}(#{Config.date}).\n" \
                "EXPERIMENTAL SOFTWARE: if you find a bug, please consider opening an issue in\n" \
                "https://github.com/crystal-lang/crystal/issues/new/"
  end
end
