# Implementation of the `crystal tool format` command
#
# This is just the command-line part. The formatter
# logic is in `crystal/tools/formatter.cr`.

class Crystal::Command
  record FormatResult, filename : String, code : Code do
    enum Code
      FORMAT
      SYNTAX
      INVALID_BYTE_SEQUENCE
      BUG
    end
  end

  private def format
    @format = "text"
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

        opts.on("-f text|json", "--format text|json", "Output format text (default) or json") do |f|
          @format = f
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

        opts.on("--show-backtrace", "Show backtrace on a bug (it is only for report!)") do
          show_backtrace = true
        end
      end

    files = options
    check_files = [] of FormatResult

    if files.size == 1
      file = files.first
      if file == "-"
        format_stdin(check)
        return
      end
    end

    includes = normalize_paths includes
    excludes = normalize_paths excludes
    excludes = excludes - includes

    if files.empty?
      files = Dir["./**/*.cr"]
    else
      files = normalize_paths files
    end

    format_many files, check, check_files, excludes, show_backtrace

    if check
      check_files.each do |result|
        case result.code
        when .format?
          error "formatting '#{result.filename}' produced changes", exit_code: nil
        when .syntax?
          error "'#{result.filename}' has syntax errors", exit_code: nil
        when .invalid_byte_sequence?
          error "'#{result.filename}' is not a valid Crystal source file", exit_code: nil
        when .bug?
          error "there's a bug formatting '#{result.filename}'", exit_code: nil
        end
      end
    end

    exit check_files.empty? ? 0 : 1
  end

  private def normalize_paths(paths)
    path_start = ".#{File::SEPARATOR}"
    paths.map do |path|
      path = path_start + path unless path.starts_with?(path_start)
      path.rstrip(File::SEPARATOR)
    end
  end

  private def format_stdin(check)
    source = STDIN.gets_to_end

    begin
      result = Crystal.format(source)
      exit(result == source ? 0 : 1) if check

      print result
    rescue ex : InvalidByteSequenceError
      STDERR.print "Error: ".colorize.toggle(@color).red.bold
      STDERR.print "source is not a valid Crystal source file: ".colorize.toggle(@color).bold
      STDERR.puts ex.message
      exit 1
    rescue ex : Crystal::SyntaxException
      if @format == "json"
        STDERR.puts ex.to_json
      else
        STDERR.puts ex
      end
      exit 1
    rescue ex
      couldnt_format "STDIN", ex
      STDERR.puts
      exit 1
    end
  end

  private def format_many(files, check, check_files, excludes, show_backtrace)
    files.each do |filename|
      format_file_or_directory filename, check, check_files, excludes, show_backtrace
    end
  end

  private def format_file_or_directory(filename, check, check_files, excludes, show_backtrace)
    if File.file?(filename)
      unless excludes.any? { |exclude| filename.starts_with?(exclude) }
        format_file filename, check, check_files, show_backtrace
      end
    elsif Dir.exists?(filename)
      filename = filename.chomp('/')
      filenames = Dir["#{filename}/**/*.cr"]
      format_many filenames, check, check_files, excludes, show_backtrace
    else
      error "file or directory does not exist: #{filename}"
    end
  end

  private def format_file(filename, check, check_files, show_backtrace)
    source = File.read(filename)

    begin
      result = Crystal.format(source, filename: filename)
      return if result == source

      if check
        check_files << FormatResult.new(filename, FormatResult::Code::FORMAT)
      else
        File.write(filename, result)
        STDOUT << "Format".colorize(:green).toggle(@color) << ' ' << filename << '\n'
      end
    rescue ex : InvalidByteSequenceError
      check_files << FormatResult.new(filename, FormatResult::Code::INVALID_BYTE_SEQUENCE)
      unless check
        STDERR.print "Error: ".colorize.toggle(@color).red.bold
        STDERR.print "file '#{Crystal.relative_filename(filename)}' is not a valid Crystal source file: ".colorize.toggle(@color).bold
        STDERR.puts ex.message
      end
    rescue ex : Crystal::SyntaxException
      check_files << FormatResult.new(filename, FormatResult::Code::SYNTAX)
      unless check
        STDERR << "Syntax Error:".colorize(:yellow).toggle(@color) << ' ' << ex.message << " at " << filename << ':' << ex.line_number << ':' << ex.column_number << '\n'
      end
    rescue ex
      check_files << FormatResult.new(filename, FormatResult::Code::BUG)
      unless check
        couldnt_format "'#{filename}'", show_backtrace ? ex : nil
      end
    end
  end

  private def couldnt_format(file, ex)
    if ex
      ex.inspect_with_backtrace STDERR
      STDERR.puts
      error "couldn't format #{file}, please report a bug including the contents of it: https://github.com/crystal-lang/crystal/issues", exit_code: nil
    else
      error "there's a bug formatting #{file}, to show more information, please run:\n\n  $ crystal tool format --show-backtrace #{file}\n", exit_code: nil
    end

    STDERR.flush
  end
end
