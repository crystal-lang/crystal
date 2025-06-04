require "../exception"
require "../types"

module Crystal
  class TypeException < CodeError
    include ErrorFormat

    getter node
    property inner : CodeError?
    getter line_number : Int32?
    getter column_number : Int32
    getter size : Int32

    def color=(@color : Bool)
      inner.try &.color=(color)
      color
    end

    def error_trace=(@error_trace : Bool)
      inner.try &.error_trace=(error_trace)
      error_trace
    end

    def warning=(@warning : Bool)
      inner.try &.warning=(warning)
      warning
    end

    def self.for_node(node, message, inner = nil)
      location = node.name_location || node.location
      if location
        ex = new message, location.line_number, location.column_number, location.filename, node.name_size, inner
        wrap_macro_expression(ex, location)
      else
        new message, nil, 0, nil, 0, inner
      end
    end

    def initialize(message, @line_number, @column_number : Int32, @filename, @size, @inner = nil)
      @error_trace = true

      super(message)
    end

    def self.new(message : String)
      new message, nil, 0, nil, 0
    end

    def self.new(message : String, location : Location)
      ex = new message, location.line_number, location.column_number, location.filename, 0
      wrap_macro_expression(ex, location)
    end

    protected def self.wrap_macro_expression(ex, location)
      filename = location.filename
      if filename.is_a?(VirtualFile) && (expanded_location = filename.expanded_location)
        ex = TypeException.new "expanding macro", expanded_location.line_number, expanded_location.column_number, expanded_location.filename, 0, ex
      end
      ex
    end

    def to_json_single(json)
      json.object do
        json.field "file", true_filename
        json.field "line", @line_number
        json.field "column", @column_number
        json.field "size", @size
        json.field "message", @message
      end
      if inner = @inner
        inner.to_json_single(json)
      end
    end

    def inspect_with_backtrace(io : IO) : Nil
      to_s(io)

      backtrace?.try &.each do |frame|
        io.print "  from "
        io.puts frame
      end

      io.flush
    end

    def to_s_with_source(io : IO, source)
      append_to_s io, source
    end

    def append_to_s(io : IO, source)
      inner = @inner

      unless @error_trace || inner.is_a? MethodTraceException
        if inner && inner.has_location?
          return inner.append_to_s(io, source)
        end
      end

      # If the inner exception has no location it means that they came from virtual nodes.
      # In that case, get the deepest error message and only show that.
      if inner && !inner.has_location?
        msg = deepest_error_message.to_s
      else
        msg = @message.to_s
      end

      error_message_lines = msg.lines

      unless @error_trace || @warning
        io << colorize("Showing last frame. Use --error-trace for full trace.").dim
        io << "\n\n"
      end

      if body = error_body(source, default_message)
        io << body
        io << '\n'
      end

      unless error_message_lines.empty?
        io << error_headline(error_message_lines.shift)
        io << remaining error_message_lines
      end

      if inner
        return if inner.is_a? MethodTraceException && !inner.has_message?
        return unless inner.has_location?
        io << "\n\n"
        io << '\n' unless inner.is_a? MethodTraceException
        inner.append_to_s io, source
      end
    end

    def default_message
      if line_number = @line_number
        "#{@warning ? "warning" : "error"} in line #{line_number}"
      end
    end

    def error_headline(msg)
      return "Warning: #{msg}" if @warning

      if (inner = @inner) && !inner.is_a? MethodTraceException? && inner.has_location?
        colorize("Error: #{msg}").yellow
      else
        colorize("Error: #{msg}").yellow.bold
      end
    end

    def has_location?
      if @inner.try &.has_location?
        true
      else
        @filename || @line_number
      end
    end

    def deepest_error_message
      if inner = @inner
        inner.deepest_error_message
      else
        @message
      end
    end
  end

  class MethodTraceException < CodeError
    def initialize(@owner : Type?, @trace : Array(ASTNode), @nil_reason : NilReason?, @show : Bool)
      super(nil)
    end

    def has_location?
      true
    end

    def to_json_single(json)
    end

    def to_s_with_source(io : IO, source)
      append_to_s(io, source)
    end

    def has_trace?
      @trace.any?(&.location)
    end

    def has_message?
      @nil_reason || has_trace? && @show
    end

    def append_to_s(io : IO, source)
      nil_reason = @nil_reason

      if !@show
        if nil_reason
          print_nil_reason(nil_reason, io)
          if has_trace? || nil_reason.try(&.nodes)
            io.puts
            io.puts
          end
        end
        return
      end

      if has_trace?
        io << "#{@owner} trace:"
        @trace.each do |node|
          print_with_location node, io
        end
      end

      return unless nil_reason

      if has_trace?
        io.puts
        io.puts
      end

      print_nil_reason(nil_reason, io)

      if nil_reason_nodes = nil_reason.nodes
        nil_reason_nodes.each do |node|
          print_with_location node, io
        end
      end
    end

    def print_nil_reason(nil_reason, io)
      case nil_reason.reason
      in .used_before_initialized?
        io << "Instance variable '#{nil_reason.name}' was used before it was initialized in one of the 'initialize' methods, rendering it nilable"
      in .used_self_before_initialized?
        io << "'self' was used before initializing instance variable '#{nil_reason.name}', rendering it nilable"
      in .initialized_in_rescue?
        io << "Instance variable '#{nil_reason.name}' is initialized inside a begin-rescue, so it can potentially be left uninitialized if an exception is raised and rescued"
      end
    end

    def print_with_location(node, io)
      location = node.location
      return unless location

      filename = location.filename
      line_number = location.line_number

      case filename
      when VirtualFile
        lines = filename.source.lines.to_a
        filename = "macro #{filename.macro.name} (in #{filename.macro.location.try &.filename}:#{filename.macro.location.try &.line_number})"
      when String
        lines = File.read_lines(filename) if File.file?(filename)
      else
        return
      end

      io << "\n\n"
      io << "  "
      io << relative_filename(filename) << ':' << line_number
      io << "\n\n"

      return unless lines

      line = lines[line_number - 1]

      name_location = node.name_location
      name_size = node.name_size

      io << "    "
      io << replace_leading_tabs_with_spaces(line.chomp)
      io.puts

      return unless name_location

      io << "    "
      io << (" " * (name_location.column_number - 1))
      with_color.green.bold.surround(io) do
        io << '^'
        if name_size > 0
          io << ("~" * (name_size - 1)) if name_size
        end
      end
    end

    def deepest_error_message
      nil
    end
  end

  class FrozenTypeException < TypeException
  end

  class UndefinedMacroMethodError < TypeException
  end

  class MacroRaiseException < TypeException
  end

  class TopLevelMacroRaiseException < MacroRaiseException
  end

  class SkipMacroException < ::Exception
    getter expanded_before_skip : String
    getter macro_expansion_pragmas : Hash(Int32, Array(Lexer::LocPragma))?

    def initialize(@expanded_before_skip, @macro_expansion_pragmas)
      super()
    end
  end

  # Raised when another exception is raised when calculating macro code coverage.
  # Extends `SkipMacroException` to ensure it's also treated as a somewhat non-failure exception.
  class SkipMacroCodeCoverageException < SkipMacroException
    def initialize(exception : ::Exception)
      super "", nil
      @message = exception.message
      @cause = exception
    end
  end

  class Program
    def undefined_class_variable(node, owner, similar_name)
      common = String.build do |str|
        str << "can't infer the type of class variable '#{node.name}' of #{owner.devirtualize}"
        if similar_name
          str << '\n'
          str << "Did you mean '#{similar_name}'?"
        end
      end

      msg = String.build do |str|
        str << common
        str << "\n\n"
        str << undefined_variable_message("class variable", node.name, owner.devirtualize)
      end
      node.raise msg
    end

    def undefined_instance_variable(node, owner, similar_name)
      common = String.build do |str|
        str << "can't infer the type of instance variable '#{node.name}' of #{owner.devirtualize}"
        if similar_name
          str << '\n'
          str << "Did you mean '#{similar_name}'?"
        end
      end

      msg = String.build do |str|
        str << common
        str << "\n\n"
        str << undefined_variable_message("instance variable", node.name, owner.devirtualize)
      end
      node.raise msg
    end

    def undefined_variable_message(kind, example_name, owner)
      owner_keyword =
        if owner.module?
          "module"
        elsif owner.struct?
          "struct"
        else
          "class"
        end

      <<-MSG
      Could you add a type annotation like this

          #{owner_keyword} #{owner}
            #{example_name} : Type
          end

      replacing `Type` with the expected type of `#{example_name}`?
      MSG
    end
  end
end
