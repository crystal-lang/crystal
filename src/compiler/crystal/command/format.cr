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

    OptionParser.parse(@options) do |opts|
      opts.banner = <<-USAGE
        Usage: crystal tool format [options] [- | file or directory ...]

        Formats Crystal code in place.

        If a file or directory is omitted,
        Crystal source files beneath the working directory are formatted.

        To format STDIN to STDOUT, use '-' in place of any path arguments.

        Options:
        USAGE

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

      includes.map! { |p| Crystal.normalize_path p }
      excludes.map! { |p| Crystal.normalize_path p }
      excludes = excludes - includes
      if files.empty?
        files = Dir["./**/*.cr"]
      else
        files.map! { |p| Crystal.normalize_path p }
      end

      @files = files
      @excludes = excludes
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
      error "syntax error in '#{filename}:#{ex.line_number}:#{ex.column_number}': #{ex.message}"
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
      Crystal.format(source, filename: filename, report_warnings: STDERR)
    end

    private def error(msg)
      Crystal.error msg, @color, exit_code: nil, stderr: @stderr, leading_error: false
    end
  end
end
