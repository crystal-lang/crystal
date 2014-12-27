class Markdown::Parser
  def initialize(text, @renderer)
    @lines = text.lines
    @line = 0
  end

  def parse
    while @line < @lines.length
      process_paragraph
    end
  end

  def process_paragraph
    line = @lines[@line]

    if empty? line
      @line += 1
      return
    end

    if next_line_is_all?('=')
      return render_header 1, line, 2
    end

    if next_line_is_all?('-')
      return render_header 2, line, 2
    end

    pounds = count_pounds line
    if pounds
      return render_prefix_header pounds, line
    end

    if line.starts_with? "    "
      return render_code
    end

    if starts_with_star? line
      return render_unordered_list
    end

    if line.starts_with? "```"
      return render_fenced_code
    end

    render_paragraph
  end

  def render_prefix_header(level, line)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = level
    while pos < bytesize && str[pos].chr.whitespace?
      pos += 1
    end

    render_header level, line.byte_slice(pos), 1
  end

  def render_header(level, line, increment)
    @renderer.begin_header level
    process_line line
    @renderer.end_header level
    @line += increment

    append_double_newline_if_has_more
  end

  def render_paragraph
    @renderer.begin_paragraph

    while true
      process_line @lines[@line]
      @line += 1

      if @line == @lines.length
        break
      end

      line = @lines[@line]

      if empty? line
        @line += 1
        break
      end

      if starts_with_star? line
        break
      end

      newline
    end

    @renderer.end_paragraph

    append_double_newline_if_has_more
  end

  def render_code
    @renderer.begin_code

    while true
      line = @lines[@line]

      break unless has_code_spaces? line

      @renderer.text line.byte_slice(4)
      @line += 1

      if @line == @lines.length
        break
      end

      newline
    end

    @renderer.end_code

    append_double_newline_if_has_more
  end

  def render_fenced_code
    line = @lines[@line]
    language = line[3 .. -1].strip

    if language.empty?
      @renderer.begin_code
    else
      @renderer.begin_code language
    end

    @line += 1

    if @line < @lines.length
      while true
        line = @lines[@line]

        if line.starts_with? "```"
          @line += 1
          break
        end

        @renderer.text line
        @line += 1

        if @line == @lines.length
          break
        end

        newline
      end
    end

    @renderer.end_code

    append_double_newline_if_has_more
  end

  def render_unordered_list
    @renderer.begin_unordered_list

    while true
      line = @lines[@line]

      if empty? line
        @line += 1

        if @line == @lines.length
          break
        end

        next
      end

      break unless starts_with_star? line

      @renderer.begin_list_item
      process_line line.byte_slice(line.index('*').not_nil! + 1)
      @renderer.end_list_item
      @line += 1

      if @line == @lines.length
        break
      end
    end

    @renderer.end_unordered_list

    append_double_newline_if_has_more
  end

  def append_double_newline_if_has_more
    if @line < @lines.length
      newline
      newline
    end
  end

  def process_line(line)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = 0

    while pos < bytesize && str[pos].chr.whitespace?
      pos += 1
    end

    cursor = pos
    one_star = false
    two_stars = false
    one_underscore = false
    two_underscores = false
    one_backtick = false

    while pos < bytesize
      case str[pos].chr
      when '*'
        if pos + 1 < bytesize && str[pos + 1].chr == '*'
          if two_stars || has_closing?('*', 2, str, (pos + 2), bytesize)
            @renderer.text line.byte_slice(cursor, pos - cursor)
            pos += 1
            cursor = pos + 1
            if two_stars
              @renderer.end_bold
            else
              @renderer.begin_bold
            end
            two_stars = !two_stars
          end
        elsif one_star || has_closing?('*', 1, str, (pos + 1), bytesize)
          @renderer.text line.byte_slice(cursor, pos - cursor)
          cursor = pos + 1
          if one_star
            @renderer.end_italic
          else
            @renderer.begin_italic
          end
          one_star = !one_star
        end
      when '_'
        if pos + 1 < bytesize && str[pos + 1].chr == '_'
          if two_underscores || has_closing?('_', 2, str, (pos + 2), bytesize)
            @renderer.text line.byte_slice(cursor, pos - cursor)
            pos += 1
            cursor = pos + 1
            if two_underscores
              @renderer.end_bold
            else
              @renderer.begin_bold
            end
            two_underscores = !two_underscores
          end
        elsif one_underscore || has_closing?('_', 1, str, (pos + 1), bytesize)
          @renderer.text line.byte_slice(cursor, pos - cursor)
          cursor = pos + 1
          if one_underscore
            @renderer.end_italic
          else
            @renderer.begin_italic
          end
          one_underscore = !one_underscore
        end
      when '`'
        if one_backtick || has_closing?('`', 1, str, (pos + 1), bytesize)
          @renderer.text line.byte_slice(cursor, pos - cursor)
          cursor = pos + 1
          if one_backtick
            @renderer.end_inline_code
          else
            @renderer.begin_inline_code
          end
          one_backtick = !one_backtick
        end
      end
      pos += 1
    end

    @renderer.text line.byte_slice(cursor, pos - cursor)
  end

  def empty?(line)
    line_is_all? line, ' '
  end

  def has_closing?(char, count, str, pos, bytesize)
    str += pos
    bytesize -= pos
    idx = str.as_enumerable(bytesize).index char.ord
    return false unless idx

    if count == 2
      return false unless idx + 1 < bytesize && str[idx + 1].chr == char
    end

    !str[idx - 1].chr.whitespace?
  end

  def next_line_is_all?(char)
    return false unless @line + 1 < @lines.length

    line = @lines[@line + 1]
    return false if line.empty?

    line_is_all? line, char
  end

  def line_is_all?(line, char)
    line.each_byte do |byte|
      return false if byte != char.ord
    end
    true
  end

  def count_pounds(line)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = 0
    while pos < bytesize && pos < 6 && str[pos].chr == '#'
      pos += 1
    end
    pos == 0 ? nil : pos
  end

  def has_code_spaces?(line)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = 0
    while pos < bytesize && pos < 4 && str[pos].chr.whitespace?
      pos += 1
    end

    if pos < 4
      pos == bytesize
    else
      true
    end
  end

  def starts_with_star?(line)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = 0
    while pos < bytesize && str[pos].chr.whitespace?
      pos += 1
    end

    return false unless pos < bytesize
    return false unless str[pos].chr == '*'

    pos += 1

    return false unless pos < bytesize
    str[pos].chr.whitespace?
  end

  def newline
    @renderer.text "\n"
  end
end
