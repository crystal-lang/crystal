require "./macros/virtual_file"
require "./types"
require "colorize"

module Crystal
  abstract class Exception < ::Exception
    property? color
    @color : Bool?
    @color = false

    @filename : String | VirtualFile | Nil

    def to_s(io)
      to_s_with_source(nil, io)
    end

    abstract def to_s_with_source(source, io)

    def to_json(io)
      io.json_array { |ar| json_obj(ar, io) }
    end

    def true_filename(filename = @filename) : String
      if filename.is_a? VirtualFile
        loc = filename.expanded_location
        if loc
          return true_filename loc.filename
        else
          return ""
        end
      else
        if filename
          return filename
        else
          return ""
        end
      end
    end

    def to_s_with_source(source)
      String.build do |io|
        to_s_with_source source, io
      end
    end

    def relative_filename(filename)
      Crystal.relative_filename(filename)
    end

    def colorize(obj)
      obj.colorize.toggle(@color)
    end

    def with_color
      ::with_color.toggle(@color)
    end

    def replace_leading_tabs_with_spaces(line)
      found_non_space = false
      line.gsub do |char|
        if found_non_space
          char
        elsif char == '\t'
          ' '
        elsif char.whitespace?
          char
        else
          found_non_space = true
          char
        end
      end
    end
  end

  class SyntaxException < Exception
    getter line_number : Int32
    getter column_number : Int32
    getter filename
    getter size : Int32?

    def initialize(message, @line_number, @column_number, @filename, @size = nil)
      super(message)
    end

    def has_location?
      @filename || @line_number
    end

    def json_obj(ar, io)
      ar.push do
        io.json_object do |obj|
          obj.field "file", true_filename
          obj.field "line", @line_number
          obj.field "column", @column_number
          obj.field "size", @size
          obj.field "message", @message
        end
      end
    end

    def append_to_s(source, io)
      if @filename
        io << "Syntax error in #{relative_filename(@filename)}:#{@line_number}: #{colorize(@message).bold}"
      else
        io << "Syntax error in line #{@line_number}: #{colorize(@message).bold}"
      end

      source = fetch_source(source)

      if source
        lines = source.lines
        if @line_number - 1 < lines.size
          line = lines[@line_number - 1]
          if line
            io << "\n\n"
            io << replace_leading_tabs_with_spaces(line.chomp)
            io << "\n"
            (@column_number - 1).times do
              io << " "
            end
            with_color.green.bold.surround(io) do
              io << "^"
              if size = @size
                io << ("~" * (size - 1))
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
        new message, location.line_number, column_number, location.filename, name_size, inner
      else
        new message, nil, 0, nil, 0, inner
      end
    end

    def initialize(message, @line, @column : Int32, @filename, @size, @inner = nil)
      super(message)
    end

    def self.new(message : String)
      new message, nil, 0, nil, 0
    end

    def self.new(message : String, location : Location)
      new message, location.line_number, location.column_number, location.filename, 0
    end

    def json_obj(ar, io)
      ar.push do
        io.json_object do |obj|
          obj.field "file", true_filename
          obj.field "line", @line
          obj.field "column", @column
          obj.field "size", @size
          obj.field "message", @message
        end
      end
      if inner = @inner
        inner.json_obj(ar, io)
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
    @owner : Type?
    @trace : Array(ASTNode)
    @nil_reason : NilReason?

    def initialize(@owner, @trace, @nil_reason)
      super(nil)
    end

    def has_location?
      true
    end

    def json_obj(ar, io)
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

      io << colorize("Error: ").bold
      case nil_reason.reason
      when :not_in_initialize
        scope = nil_reason.scope.not_nil!
        found = instance_var_not_initialized scope, nil, scope, nil_reason.name, io
      when :used_before_initialized
        io << colorize("instance variable '#{nil_reason.name}' was used before it was initialized in one of the 'initialize' methods, rendering it nilable").bold
      when :used_self_before_initialized
        io << colorize("'self' was used before initializing instance variable '#{nil_reason.name}', rendering it nilable").bold
      end

      if nil_reason_nodes = nil_reason.nodes
        nil_reason_nodes.each do |node|
          print_with_location node, io
        end
      end
    end

    def instance_var_not_initialized(original_scope, common_supertype, scope : VirtualType, var_name, io, recurse = true)
      scope.each_concrete_type do |subtype|
        unless subtype.has_instance_var_in_initialize?(var_name)
          found = instance_var_not_initialized original_scope, common_supertype, subtype, var_name, io, recurse: recurse
          break true if found
        end
      end
      false
    end

    def instance_var_not_initialized(original_scope, common_supertype, scope, var_name, io, recurse = true)
      defs, all_defs = defs_without_instance_var_initialized scope, var_name

      if defs.empty? && !all_defs.empty?
        # Couldn't find a def, let's see who owns the instance variable
        if recurse && (owner = scope.instance_var_owner(var_name)) && (owner != scope)
          common_supertype = owner.virtual_type!
          instance_var_not_initialized original_scope, common_supertype, common_supertype, var_name, io, recurse: false
        else
          false
        end
      else
        if original_scope == scope
          io << colorize("instance variable '#{var_name}' of #{scope} was not initialized in all of the 'initialize' methods, rendering it nilable").bold
        else
          io << colorize("instance variable '#{var_name}' of #{scope} was not initialized in all of the 'initialize' methods, rendering '#{var_name}' of #{original_scope.devirtualize} nilable").bold
          if common_supertype
            io << colorize(" (#{common_supertype.devirtualize} is the common supertype that defines it)").bold
          end
        end
        io.puts
        io.puts
        io << "Specifically in "
        io << (defs.size == 1 ? "this one" : "these ones")
        io << ":"
        defs.each do |a_def|
          print_with_location a_def, io
        end
        true
      end
    end

    def defs_without_instance_var_initialized(scope, var_name)
      defs = scope.lookup_defs("initialize")
      filtered = defs.select do |a_def|
        if a_def.calls_super
          false
        elsif (instance_vars = a_def.instance_vars)
          !instance_vars.includes?(var_name)
        else
          true
        end
      end
      {filtered, defs}
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
end
