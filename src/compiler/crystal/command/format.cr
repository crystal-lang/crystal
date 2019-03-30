# Implementation of the `crystal tool format` command
#
# This is just the command-line part. The formatter
# logic is in `crystal/tools/formatter.cr`.

class Crystal::Command
  private def format
    excludes = ["lib"] of String
    includes = [] of String
    check = false
    show_backtrace = false

    option_parser =
      OptionParser.parse(options) do |opts|
        opts.banner = "Usage: crystal tool format [options] [file or directory]\n\nOptions:"

        opts.on("--check", "Checks that formatting code produces no changes") do |f|
          check = true
        end

        opts.on("-i <path>", "--include <path>", "Include path") do |f|
          includes << f
        end

        opts.on("-e <path>", "--exclude <path>", "Exclude path (default: lib)") do |f|
          excludes << f
        end

        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit
        end

        opts.on("--no-color", "Disable colored output") do
          @color = false
        end

        opts.on("--show-backtrace", "Show backtrace on a bug (used only for debugging)") do
          show_backtrace = true
        end
      end

    files = options

    format_command = FormatCommand.new(
      files,
      includes,
      excludes,
      check,
      show_backtrace,
      @color,
    )
    format_command.run
    exit format_command.status_code
  end

  class FormatCommand
    @format_stdin : Bool
    @files : Array(String)
    @excludes : Array(String)

    getter status_code = 0

    def initialize(
      files : Array(String),
      includes = [] of String, excludes = [] of String,
      @check : Bool = false,
      @show_backtrace : Bool = false,
      @color : Bool = true,
      # stdio is injectable for testing
      @stdin : IO = STDIN, @stdout : IO = STDOUT, @stderr : IO = STDERR
    )
      @format_stdin = files.size == 1 && files[0] == "-"

      includes = normalize_paths includes
      excludes = normalize_paths excludes
      excludes = excludes - includes
      if files.empty?
        files = Dir["./**/*.cr"]
      else
        files = normalize_paths files
      end

      @files = files
      @excludes = excludes
    end

    private def normalize_paths(paths)
      path_start = ".#{File::SEPARATOR}"
      paths.map do |path|
        unless path.starts_with?(path_start) || path.starts_with?(File::SEPARATOR)
          path = path_start + path
        end
        path.rstrip(File::SEPARATOR)
      end
    end

    def run
      if @format_stdin
        format_stdin
      else
        format_many @files
      end
    end

    private def format_stdin
      source = @stdin.gets_to_end
      format_source "STDIN", source
    end

    private def format_many(files)
      files.each do |filename|
        format_file_or_directory filename
      end
    end

    private def format_file_or_directory(filename)
      if File.file?(filename)
        unless @excludes.any? { |exclude| filename.starts_with?(exclude) }
          format_file filename
        end
      elsif Dir.exists?(filename)
        filename = filename.chomp('/')
        filenames = Dir["#{filename}/**/*.cr"]
        format_many filenames
      else
        error "file or directory does not exist: #{filename}"
      end
    end

    private def format_file(filename)
      source = File.read(filename)
      format_source filename, source
    end

    private def format_source(filename, source)
      result = format(filename, source)
      @stdout.print result if @format_stdin
      return if result == source

      if @check
        error "formatting '#{filename}' produced changes"
        @status_code = 1
      else
        unless @format_stdin
          File.write filename, result
          @stdout << "Format".colorize(:green).toggle(@color) << ' ' << filename << '\n'
        end
      end
    rescue ex : InvalidByteSequenceError
      error "file '#{filename}' is not a valid Crystal source file: #{ex.message}"
      @status_code = 1
    rescue ex : Crystal::SyntaxException
      error ex
      @status_code = 1
    rescue ex
      if @show_backtrace
        ex.inspect_with_backtrace @stderr
        @stderr.puts
        error "couldn't format '#{filename}', please report a bug including the contents of it: https://github.com/crystal-lang/crystal/issues"
      else
        error "there's a bug formatting '#{filename}', to show more information, please run:\n\n  $ crystal tool format --show-backtrace #{@format_stdin ? "-" : "'#{filename}'"}\n"
      end
      @status_code = 1
    end

    # This method is for mocking `Crystal.format` in test.
    private def format(filename, source)
      result = Crystal.format(source, filename: filename)
    end

    private def error(msg)
      Crystal.error msg, @color, exit_code: nil, stderr: @stderr
    end
  end
end
