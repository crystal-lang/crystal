require "./macros/virtual_file"
require "./types"
require "colorize"

module Crystal
  abstract class Exception < ::Exception
    def to_s(io)
      to_s_with_source(nil, io)
    end

    def to_s_with_source(source)
      String.build do |io|
        to_s_with_source source, io
      end
    end

    def relative_filename(filename)
      Crystal.relative_filename(filename)
    end
  end

  class SyntaxException < Exception
    getter line_number
    getter column_number
    getter filename
    getter length

    def initialize(message, @line_number, @column_number, @filename, @length = nil)
      super(message)
    end

    def has_location?
      @filename || @line
    end

    def append_to_s(source, io)
      if @filename
        io << "Syntax error in #{relative_filename(@filename)}:#{@line_number}: #{@message.colorize.bold}"
      else
        io << "Syntax error in line #{@line_number}: #{@message.colorize.bold}"
      end

      source = fetch_source(source)

      if source
        lines = source.lines
        if @line_number - 1 < lines.length
          line = lines[@line_number - 1]
          if line
            io << "\n\n"
            io << line.chomp
            io << "\n"
            (@column_number - 1).times do
              io << " "
            end
            with_color.green.bold.surround(io) do
              io << "^"
              if length = @length
                io << ("~" * (length - 1))
              end
            end
            io << "\n"
          end
        end
      end
    end

    def to_s_with_source(source, io)
      append_to_s fetch_source(source), io
    end

    def fetch_source(source)
      case filename = @filename
      when String
        source = File.read(filename) if File.file?(filename)
      when VirtualFile
        source = filename.source
      end
      source
    end

    def deepest_error_message
      @message
    end
  end

  class TypeException < Exception
    getter :node
    getter :inner

    def self.for_node(node, message, inner = nil)
      location = node.location
      if location
        column_number = node.name_column_number
        name_length = node.name_length
        if column_number == 0
          name_length = 0
          column_number = location.column_number
        end
        new message, location.line_number, column_number, location.filename, name_length, inner
      else
        new message, nil, 0, nil, 0, inner
      end
    end

    def initialize(message, @line, @column : Int32, @filename, @length, @inner = nil)
      super(message)
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
        lines = filename.source.lines.to_a
        io << "in macro '#{filename.macro.name}' #{filename.macro.location.try &.filename}:#{filename.macro.location.try &.line_number}, line #{@line}:\n\n"
        io << lines.to_s_with_line_numbers
        is_macro = true
      else
        lines = source ? source.lines.to_a : nil
        io << "in line #{@line}: " if @line
        append_error_message io, msg
      end

      if lines && (line_number = @line) && (line = lines[line_number - 1]?)
        io << "\n\n"
        io << line.chomp
        io << "\n"
        io << (" " * (@column - 1))
        with_color.green.bold.surround(io) do
          io << "^"
          if @length > 0
            io << ("~" * (@length - 1))
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
        io << msg.colorize.bold
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
    def initialize(@owner, @trace, @nil_reason)
      super(nil)
    end

    def has_location?
      true
    end

    def to_s_with_source(source, io)
      append_to_s(source, io)
    end

    def append_to_s(source, io)
      has_trace = @trace.any?(&.location)
      if has_trace
        io.puts ("=" * 80)
        io << "\n#{@owner} trace:"
        @trace.each do |node|
          print_with_location node, io
        end
      end

      nil_reason = @nil_reason
      return unless nil_reason

      if has_trace
        io.puts
        io.puts
      end
      io.puts ("=" * 80)
      io.puts

      io << "Error: ".colorize.bold
      case nil_reason.reason
      when :not_in_initialize
        scope = nil_reason.scope.not_nil!
        if scope.is_a?(VirtualType)
          scope.each_concrete_type do |subtype|
            unless subtype.has_instance_var_in_initialize?(nil_reason.name)
              instance_var_not_initialized subtype, nil_reason.name, io
            end
          end
        else
          instance_var_not_initialized scope, nil_reason.name, io
        end
      when :used_before_initialized
        io << "instance variable '#{nil_reason.name}' was used before it was initialized in one of the 'initialize' methods, rendering it nilable".colorize.bold
      when :used_self_before_initialized
        io << "'self' was used before initializing instance variable '#{nil_reason.name}', rendering it nilable".colorize.bold
      end

      if nil_reason_nodes = nil_reason.nodes
        nil_reason_nodes.each do |node|
          print_with_location node, io
        end
      end
    end

    def instance_var_not_initialized(scope, var_name, io)
      io << "instance variable '#{var_name}' of #{scope} was not initialized in all of the 'initialize' methods, rendering it nilable".colorize.bold
      defs = defs_without_instance_var_initialized scope, var_name
      unless defs.empty?
        io << "."
        io.puts
        io.puts
        io << "Specifically in "
        io << (defs.length == 1 ? "this one" : "these ones")
        io << ":"
        defs.each do |a_def|
          print_with_location a_def, io
        end
      end
    end

    def defs_without_instance_var_initialized(scope, var_name)
      defs = scope.lookup_defs("initialize")
      defs = defs.select do |a_def|
        instance_vars = a_def.instance_vars
        if instance_vars
          !instance_vars.includes?(var_name)
        else
          true
        end
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
      name_length = node.name_length

      io << "    "
      io << line.chomp
      io.puts

      return unless name_column > 0

      io << "    "
      io << (" " * (name_column - 1))
      with_color.green.bold.surround(io) do
        io << "^"
        if name_length > 0
          io << ("~" * (name_length - 1)) if name_length
        end
      end
    end

    def deepest_error_message
      nil
    end
  end

  class FrozenTypeException < TypeException
  end
end
