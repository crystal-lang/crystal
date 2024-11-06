module Crystal
  # Which warnings to detect.
  enum WarningLevel
    None
    All
  end

  # This collection handles warning detection, reporting, and related options.
  # It is shared between a `Crystal::Compiler` and other components that need to
  # produce warnings.
  class WarningCollection
    # Which kind of warnings we want to detect.
    property level : WarningLevel = :all

    @excluded_paths = [] of String
    @lib_path : String?

    # Whether to ignore the "lib" path for warning detection. Turned off by
    # the `--exclude-warnings` command-line option.
    def exclude_lib_path? : Bool
      !@lib_path.nil?
    end

    def exclude_lib_path=(exclude : Bool)
      @lib_path = exclude ? File.expand_path(Crystal.normalize_path("lib")) : nil
    end

    # Detected warnings.
    property infos = [] of String

    # Whether the compiler will error if any warnings are detected.
    property? error_on_warnings = false

    def exclude_path(path : ::Path | String)
      @excluded_paths << File.expand_path(Crystal.normalize_path(path))
    end

    def add_warning(node : ASTNode, message : String)
      return unless @level.all?
      return if ignore_warning_due_to_location?(node.location)

      @infos << node.warning(message)
    end

    def add_warning_at(location : Location?, message : String)
      return unless @level.all?
      return if ignore_warning_due_to_location?(location)

      if location
        message = String.build do |io|
          exception = SyntaxException.new message, location.line_number, location.column_number, location.filename
          exception.warning = true
          exception.append_to_s(io, nil)
        end
      end

      @infos << message
    end

    def report(io : IO)
      unless @infos.empty?
        @infos.each do |message|
          io.puts message
          io.puts "\n"
        end
        io.puts "A total of #{@infos.size} warnings were found."
      end
    end

    def ignore_warning_due_to_location?(location : Location?)
      return false unless location

      filename = location.original_filename
      return false unless filename

      if lib_path = @lib_path
        return true if filename.starts_with?(lib_path)
      end

      @excluded_paths.any? do |path|
        filename.starts_with?(path)
      end
    end
  end

  class ASTNode
    def warning(message, inner = nil, exception_type = Crystal::TypeException)
      # TODO extract message formatting from exceptions
      String.build do |io|
        exception = exception_type.for_node(self, message, inner)
        exception.warning = true
        exception.append_to_s(io, nil)
      end
    end
  end

  class Command
    def report_warnings
      @compiler.try &.warnings.report(STDERR)
    end

    def warnings_fail_on_exit?
      compiler = @compiler
      return false unless compiler

      warnings = compiler.warnings
      warnings.error_on_warnings? && !warnings.infos.empty?
    end
  end
end
