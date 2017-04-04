require "../exception"
require "../types"

module Crystal
  class TypeException < Exception
    getter node
    property inner : Exception?
    @line : Int32?
    @column : Int32
    @size : Int32

    def color=(color)
      @color = !!color
      inner.try &.color=(color)
    end

    def self.for_node(node, message, inner = nil)
      location = node.location
      if location
        column_number = node.name_column_number
        name_size = node.name_size
        if column_number == 0
          name_size = 0
          column_number = location.column_number
        end
        ex = new message, location.line_number, column_number, location.filename, name_size, inner
        wrap_macro_expression(ex, location)
      else
        new message, nil, 0, nil, 0, inner
      end
    end

    def initialize(message, @line, @column : Int32, @filename, @size, @inner = nil)
      # If the inner exception is a macro raise, we replace this exception's
      # message with that message. In this way the error message will
      # look like a regular message produced by the compiler, and not
      # because of an incorrect macro expansion.
      if inner.is_a?(MacroRaiseException)
        message = inner.message
        @inner = nil
      end
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
        json.field "line", @line
        json.field "column", @column
        json.field "size", @size
        json.field "message", @message
      end
      if inner = @inner
        inner.to_json_single(json)
      end
    end

    def to_s_with_source(source, io)
      io << "Error "
      append_to_s source, io
    end

    def append_to_s(source, io)
      inner = @inner
      filename = @filename

      # If the inner exception has no location it means that they came from virtual nodes.
      # In that case, get the deepest error message and only show that.
      if inner && !inner.has_location?
        msg = deepest_error_message.to_s
      else
        msg = @message.to_s
      end

      is_macro = false

      case filename
      when String
        if File.file?(filename)
          lines = File.read_lines(filename)
          io << "in " << relative_filename(filename) << ":" << @line << ": "
          append_error_message io, msg
        else
          lines = source ? source.lines.to_a : nil
          io << "in line #{@line}: " if @line
          append_error_message io, msg
        end
      when VirtualFile
        io << "in macro '#{filename.macro.name}' #{filename.macro.location.try &.filename}:#{filename.macro.location.try &.line_number}, line #{@line}:\n\n"
        io << Crystal.with_line_numbers(filename.source, @line, @color)
        is_macro = true
      else
        lines = source ? source.lines.to_a : nil
        io << "in line #{@line}: " if @line
        append_error_message io, msg
      end

      if lines && (line_number = @line) && (line = lines[line_number - 1]?)
        io << "\n\n"
        io << replace_leading_tabs_with_spaces(line.chomp)
        io << "\n"
        io << (" " * (@column - 1))
        with_color.green.bold.surround(io) do
          io << "^"
          if @size > 0
            io << ("~" * (@size - 1))
          end
        end
      end
      io << "\n"

      if is_macro
        io << "\n"
        append_error_message io, @message
      end

      if inner && inner.has_location?
        io << "\n"
        inner.append_to_s source, io
      end
    end

    def append_error_message(io, msg)
      if @inner
        io << msg
      else
        io << colorize(msg).bold
      end
    end

    def has_location?
      if @inner.try &.has_location?
        true
      else
        @filename || @line
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

  class MethodTraceException < Exception
    def initialize(@owner : Type?, @trace : Array(ASTNode), @nil_reason : NilReason?, @show : Bool)
      super(nil)
    end

    def has_location?
      true
    end

    def to_json_single(json)
    end

    def to_s_with_source(source, io)
      append_to_s(source, io)
    end

    def append_to_s(source, io)
      has_trace = @trace.any?(&.location)
      nil_reason = @nil_reason

      if !@show
        if nil_reason
          print_nil_reason(nil_reason, io)
          if has_trace || nil_reason.try(&.nodes)
            io.puts
            io.puts
          end
        end
        if has_trace || nil_reason.try(&.nodes)
          io.print "Rerun with --error-trace to show a complete error trace."
        end
        return
      end

      if has_trace
        io.puts ("=" * 80)
        io.puts
        io << "#{@owner} trace:"
        @trace.each do |node|
          print_with_location node, io
        end
      end

      return unless nil_reason

      if has_trace
        io.puts
        io.puts
      end
      io.puts ("=" * 80)
      io.puts

      print_nil_reason(nil_reason, io)

      if nil_reason_nodes = nil_reason.nodes
        nil_reason_nodes.each do |node|
          print_with_location node, io
        end
      end
    end

    def print_nil_reason(nil_reason, io)
      io << colorize("Error: ").bold
      case nil_reason.reason
      when :used_before_initialized
        io << colorize("instance variable '#{nil_reason.name}' was used before it was initialized in one of the 'initialize' methods, rendering it nilable").bold
      when :used_self_before_initialized
        io << colorize("'self' was used before initializing instance variable '#{nil_reason.name}', rendering it nilable").bold
      when :initialized_in_rescue
        io << colorize("instance variable '#{nil_reason.name}' is initialized inside a begin-rescue, so it can potentially be left uninitialized if an exception is raised and rescued").bold
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
      io << relative_filename(filename) << ":" << line_number
      io << "\n\n"

      return unless lines

      line = lines[line_number - 1]

      name_column = node.name_column_number
      name_size = node.name_size

      io << "    "
      io << replace_leading_tabs_with_spaces(line.chomp)
      io.puts

      return unless name_column > 0

      io << "    "
      io << (" " * (name_column - 1))
      with_color.green.bold.surround(io) do
        io << "^"
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

  class SkipMacroException < ::Exception
    getter expanded_before_skip : String

    def initialize(@expanded_before_skip)
      super()
    end
  end

  class Program
    def undefined_global_variable(node, similar_name)
      common = String.build do |str|
        str << "Can't infer the type of global variable '#{node.name}'"
        if similar_name
          str << colorize(" (did you mean #{similar_name}?)").yellow.bold.to_s
        end
      end

      msg = String.build do |str|
        str << common
        str << "\n\n"
        str << undefined_variable_message("global", node.name)
        str << "\n\n"
        str << common
      end
      node.raise msg
    end

    def undefined_class_variable(node, owner, similar_name)
      common = String.build do |str|
        str << "Can't infer the type of class variable '#{node.name}' of #{owner.devirtualize}"
        if similar_name
          str << colorize(" (did you mean #{similar_name}?)").yellow.bold.to_s
        end
      end

      msg = String.build do |str|
        str << common
        str << "\n\n"
        str << undefined_variable_message("class", node.name)
        str << "\n\n"
        str << common
      end
      node.raise msg
    end

    def undefined_instance_variable(node, owner, similar_name)
      common = String.build do |str|
        str << "Can't infer the type of instance variable '#{node.name}' of #{owner.devirtualize}"
        if similar_name
          str << colorize(" (did you mean #{similar_name}?)").yellow.bold.to_s
        end
      end

      msg = String.build do |str|
        str << common
        str << "\n\n"
        str << undefined_variable_message("instance", node.name)
        str << "\n\n"
        str << common
      end
      node.raise msg
    end

    def undefined_variable_message(kind, example_name)
      <<-MSG
      The type of a #{kind} variable, if not declared explicitly with
      `#{example_name} : Type`, is inferred from assignments to it across
      the whole program.

      The assignments must look like this:

        1. `#{example_name} = 1` (or other literals), inferred to the literal's type
        2. `#{example_name} = Type.new`, type is inferred to be Type
        3. `#{example_name} = Type.method`, where `method` has a return type
           annotation, type is inferred from it
        4. `#{example_name} = arg`, with 'arg' being a method argument with a
           type restriction 'Type', type is inferred to be Type
        5. `#{example_name} = arg`, with 'arg' being a method argument with a
           default value, type is inferred using rules 1, 2 and 3 from it
        6. `#{example_name} = uninitialized Type`, type is inferred to be Type
        7. `#{example_name} = LibSome.func`, and `LibSome` is a `lib`, type
           is inferred from that fun.
        8. `LibSome.func(out #{example_name})`, and `LibSome` is a `lib`, type
           is inferred from that fun argument.

      Other assignments have no effect on its type.
      MSG
    end
  end
end
