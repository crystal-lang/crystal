require "./util"
require "./error"
require "colorize"

module Crystal
  # A compiler error message with source fragments that should be highlighted
  # when rendered with color. The stored text always remains ANSI-free.
  class DiagnosticMessage
    enum HighlightKind
      Syntax
      Blue
      YellowBold
    end

    record Highlight,
      offset : Int32,
      size : Int32,
      kind : HighlightKind,
      numbered_source : String? = nil

    getter text : String
    getter highlights : Array(Highlight)

    def initialize(@text : String, @highlights : Array(Highlight))
    end

    # Overridden in `diagnostic/syntax_highlighter` when the full compiler is
    # loaded.
    def render(color : Bool) : String
      @text
    end
  end

  # Base class for all errors related to specific user code.
  abstract class CodeError < Error
    property? color = false
    property? error_trace = false
    property? warning = false

    @filename : String | VirtualFile | Nil

    def to_s(io) : Nil
      to_s_with_source(io, nil)
    end

    abstract def to_s_with_source(io : IO, source)

    def to_json(json : JSON::Builder)
      json.array do
        to_json_single(json)
      end
    end

    def true_filename(filename = @filename) : String
      if filename.is_a? VirtualFile
        loc = filename.expanded_location
        if loc
          true_filename loc.filename
        else
          ""
        end
      else
        if filename
          filename
        else
          ""
        end
      end
    end

    def to_s_with_source(source)
      String.build do |io|
        to_s_with_source(io, source)
      end
    end

    def relative_filename(filename)
      Crystal.relative_filename(filename)
    end

    def colorize(obj)
      obj.colorize.toggle(@color)
    end

    def with_color
      Colorize.with.toggle(@color)
    end

    # Overridden in `diagnostic/syntax_highlighter` when the full compiler is
    # loaded.
    def syntax_highlight(source : String) : String
      source
    end

    # :ditto:
    def syntax_highlight_line(source : Array(String), line_index : Int32, displayed_line : String) : String
      displayed_line
    end

    def replace_leading_tabs_with_spaces(line)
      found_non_space = false
      line.gsub do |char|
        if found_non_space
          char
        elsif char == '\t'
          ' '
        elsif char.ascii_whitespace?
          char
        else
          found_non_space = true
          char
        end
      end
    end
  end

  module ErrorFormat
    MACRO_LINES_TO_SHOW               = 3
    OFFSET_FROM_LINE_NUMBER_DECORATOR = 6

    def error_body(source, default_message) : String | Nil
      case filename = @filename
      in VirtualFile
        return format_macro_error(filename)
      in String
        if File.file?(filename)
          return format_error_from_file(filename)
        end
      in Nil
        # go on
      end

      return format_error(source) if source
      default_message
    end

    def line_number_decorator(line_number)
      " #{line_number} | "
    end

    def append_error_indicator(io, offset, column_number, size = 0)
      size ||= 0
      io << '\n'
      io << (" " * (offset + column_number - 1))
      with_color.green.bold.surround(io) do
        io << '^'
        if size > 0
          io << ("-" * (size - 1))
        end
      end
    end

    def filename_row_col_message(filename, line_number, column_number)
      String.build do |io|
        io << colorize("#{relative_filename(filename)}:#{line_number}:#{column_number}").underline
      end
    end

    def format_error(filename, lines, line_number, column_number, size = 0)
      return "#{relative_filename(filename)}" unless line_number

      unless line = lines[line_number - 1]?
        return filename_row_col_message(filename, line_number, column_number)
      end

      String.build do |io|
        case filename
        in String
          io << filename_row_col_message(filename, line_number, column_number)
        in VirtualFile
          io << "macro '" << colorize("#{filename.macro.name}").underline << '\''
        in Nil
          io << "unknown location"
        end

        decorator = line_number_decorator(line_number)
        lstripped_line = line.lstrip
        space_delta = line.size - lstripped_line.size
        # Column number should start at `1`. We're using `0` to track bogus passed
        # `column_number`.
        final_column_number = (column_number - space_delta).clamp(0..)

        highlighted_line = syntax_highlight_line(lines, line_number - 1, lstripped_line.chomp)

        io << "\n\n"
        io << colorize(decorator).dim << colorize(highlighted_line).bold
        append_error_indicator(io, decorator.size, final_column_number, size || 0)
      end
    end

    def format_error_from_file(filename : String)
      lines = File.read_lines(filename)
      formatted_error = format_error(
        filename: @filename,
        lines: lines,
        line_number: @line_number,
        column_number: @column_number,
        size: @size
      )
      "In #{formatted_error}"
    end

    def format_macro_error(virtual_file : VirtualFile)
      show_where_macro_expanded = !(@error_trace && self.responds_to?(:error_trace=))
      String.build do |io|
        io << "There was a problem expanding macro '#{virtual_file.macro.name}'"
        io << "\n\n"
        if show_where_macro_expanded
          append_where_macro_expanded(io, virtual_file)
          io << '\n'
        end
        io << "Called macro defined in "
        append_macro_definition_location(io, virtual_file)
        io << "\n\n"
        io << "Which expanded to:"
        io << "\n\n"
        append_expanded_macro(io, virtual_file.source)
      end
    end

    def remaining(lines : Array(String))
      String.build do |io|
        return if lines.empty?
        io << "\n\n"
        io << lines.skip_while(&.blank?).join('\n')
      end
    end

    def source_lines(filename)
      case filename
      in Nil
        nil
      in String
        if File.file? filename
          File.read_lines(filename)
        else
          nil
        end
      in VirtualFile
        filename.source.lines
      end
    end

    def append_macro_definition_location(io, filename : VirtualFile)
      macro_source = filename.macro.location
      source_filename = macro_source.try &.filename
      line_number = macro_source.try &.line_number
      column_number = macro_source.try &.column_number

      case source_filename
      in String
        io << colorize("#{relative_filename(source_filename)}:#{line_number}:#{column_number}").underline
      in VirtualFile
        io << "macro '" << colorize("#{source_filename.macro.name}").underline << '\''
      in Nil
        "unknown location"
      end

      lines = source_lines(source_filename)

      if lines && line_number
        io << "\n\n"
        io << colorize(line_number_decorator(line_number)).dim
        displayed_line = lines[line_number - 1].lstrip.chomp
        io << syntax_highlight_line(lines, line_number - 1, displayed_line)
      end
    end

    def minimize_indentation(source)
      min_leading_white_space =
        source.min_of? { |line| leading_white_space(line) } || 0

      source = remove_indentation(source, min_leading_white_space)

      {source, min_leading_white_space}
    end

    private def remove_indentation(source, size)
      return source unless size > 0

      source.map do |line|
        replace_leading_tabs_with_spaces(line).lchop(" " * size)
      end
    end

    private def leading_white_space(line)
      match = line.match(/^(\s+)\S/)
      return 0 unless match

      spaces = match[1]?
      return 0 unless spaces

      spaces.size
    end

    def append_expanded_macro(io, source)
      line_number = @line_number
      if @error_trace || !line_number
        source, _ = minimize_indentation(source.lines)
        source = syntax_highlight_lines(source)
        io << Crystal.with_line_numbers(source, line_number, @color)
      else
        # Materialize only the lines up to the reported one, plus one more so
        # the highlighter sees its terminating newline; the rest of a large
        # expansion is never displayed.
        source_lines = [] of String
        source.each_line do |line|
          source_lines << line
          break if source_lines.size > line_number
        end
        source = source_lines
        to_index = line_number.clamp(0..source.size)
        from_index = {0, to_index - MACRO_LINES_TO_SHOW}.max
        source_slice = source[from_index...to_index]
        source_slice, spaces_removed = minimize_indentation(source_slice)
        if @color
          source = remove_indentation(source, spaces_removed)
          source_slice = syntax_highlight_lines(source, through_line: to_index - 1)[from_index...to_index]
        end

        io << Crystal.with_line_numbers(source_slice, line_number, @color, from_index + 1)
        offset = OFFSET_FROM_LINE_NUMBER_DECORATOR + line_number.to_s.size - spaces_removed
        append_error_indicator(io, offset, @column_number, @size)
      end
    end

    # Overridden in `diagnostic/syntax_highlighter` when the full compiler is
    # loaded.
    private def syntax_highlight_lines(source : Array(String), *, through_line : Int32? = nil) : Array(String)
      source
    end

    def append_where_macro_expanded(io, filename : VirtualFile)
      expanded_source = filename.expanded_location
      return unless expanded_source
      source_filename = expanded_source.filename
      lines = source_lines(source_filename)
      return unless lines

      io << "Code in " << format_error(
        filename: source_filename,
        lines: lines,
        line_number: expanded_source.line_number,
        column_number: expanded_source.column_number,
      )
    end
  end
end
