require "../exception"
require "../../../crystal/syntax_highlighter/colorize"

module Crystal::DiagnosticSyntaxHighlighter
  def self.highlight(source : String, color : Bool) : String
    return source unless color

    Crystal::SyntaxHighlighter::Colorize.highlight!(source)
  end

  def self.highlight_lines(source : Array(String), color : Bool, *, through_line : Int32? = nil) : Array(String)
    return source unless color

    Crystal::SyntaxHighlighter::Colorize.highlight_lines!(source, through_line)
  end

  def self.highlight_line(source : Array(String), line_index : Int32, displayed_line : String, color : Bool) : String
    return displayed_line unless color
    return highlight(displayed_line, true) unless source[line_index]?

    contextual_source = source.dup
    contextual_source[line_index] = displayed_line
    highlight_lines(contextual_source, true, through_line: line_index)[line_index]? || highlight(displayed_line, true)
  end
end

class Crystal::DiagnosticMessage
  def render(color : Bool) : String
    return text unless color
    return text unless valid_highlights?

    String.build(text.bytesize) do |io|
      cursor = 0
      highlights.each do |highlight|
        io << text.byte_slice(cursor, highlight.offset - cursor)
        fragment = text.byte_slice(highlight.offset, highlight.size)

        case highlight.kind
        in .syntax?
          if numbered_source = highlight.numbered_source
            highlighted_source = DiagnosticSyntaxHighlighter.highlight_lines(numbered_source.lines, true)
            io << Crystal.with_line_numbers(highlighted_source)
          else
            io << DiagnosticSyntaxHighlighter.highlight(fragment, true)
          end
        in .blue?
          io << fragment.colorize.toggle(true).blue
        in .yellow_bold?
          io << fragment.colorize.toggle(true).yellow.bold
        end

        cursor = highlight.offset + highlight.size
      end
      io << text.byte_slice(cursor, text.bytesize - cursor)
    end
  end

  private def valid_highlights? : Bool
    cursor = 0
    highlights.all? do |highlight|
      offset = highlight.offset
      size = highlight.size
      valid = offset >= cursor && size >= 0 && offset <= text.bytesize && size <= text.bytesize - offset
      if valid && (numbered_source = highlight.numbered_source)
        valid = highlight.kind.syntax? &&
                text.byte_slice(offset, size) == Crystal.with_line_numbers(numbered_source)
      end
      cursor = offset + size if valid
      valid
    end
  end
end

class Crystal::CodeError
  def syntax_highlight(source : String) : String
    DiagnosticSyntaxHighlighter.highlight(source, color?)
  end

  def syntax_highlight_line(source : Array(String), line_index : Int32, displayed_line : String) : String
    DiagnosticSyntaxHighlighter.highlight_line(source, line_index, displayed_line, color?)
  end
end

module Crystal::ErrorFormat
  private def syntax_highlight_lines(source : Array(String), *, through_line : Int32? = nil) : Array(String)
    DiagnosticSyntaxHighlighter.highlight_lines(source, color?, through_line: through_line)
  end
end
