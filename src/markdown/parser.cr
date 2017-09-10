class Markdown::Parser
  record PrefixHeader, count : Int32
  record UnorderedList, char : Char

  @lines : Array(String)

  def initialize(text : String, @renderer : Renderer)
    @lines = text.lines
    @line = 0
  end

  def parse
    while @line < @lines.size
      process_paragraph
    end
  end

  def process_paragraph
    line = @lines[@line]

    case item = classify(line)
    when :empty
      @line += 1
    when :header1
      render_header 1, line, 2
    when :header2
      render_header 2, line, 2
    when PrefixHeader
      render_prefix_header(item.count, line)
    when :code
      render_code
    when :horizontal_rule
      render_horizontal_rule
    when UnorderedList
      render_unordered_list(item.char)
    when :fenced_code
      render_fenced_code
    when :ordered_list
      render_ordered_list
    when :quote
      render_quote
    else
      render_paragraph
    end
  end

  def classify(line)
    if empty? line
      return :empty
    end

    if pounds = count_pounds line
      return PrefixHeader.new(pounds)
    end

    if line.starts_with? "    "
      return :code
    end

    if horizontal_rule? line
      return :horizontal_rule
    end

    if starts_with_bullet_list_marker?(line, '*')
      return UnorderedList.new('*')
    end

    if starts_with_bullet_list_marker?(line, '+')
      return UnorderedList.new('+')
    end

    if starts_with_bullet_list_marker?(line, '-')
      return UnorderedList.new('-')
    end

    if starts_with_backticks? line
      return :fenced_code
    end

    if starts_with_digits_dot? line
      return :ordered_list
    end

    if line.starts_with? ">"
      return :quote
    end

    if next_line_is_all?('=')
      return :header1
    end

    if next_line_is_all?('-')
      return :header2
    end

    nil
  end

  def render_prefix_header(level, line)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = level
    while pos < bytesize && str[pos].unsafe_chr.ascii_whitespace?
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

    join_next_lines continue_on: nil
    process_line @lines[@line]
    @line += 1

    @renderer.end_paragraph

    append_double_newline_if_has_more
  end

  def render_code
    @renderer.begin_code nil

    while true
      line = @lines[@line]

      break unless has_code_spaces? line

      @renderer.text line.byte_slice(Math.min(line.bytesize, 4))
      @line += 1

      if @line == @lines.size
        break
      end

      if next_lines_empty_of_code?
        break
      end

      newline
    end

    @renderer.end_code

    append_double_newline_if_has_more
  end

  def render_fenced_code
    line = @lines[@line]
    language = line[3..-1].strip

    if language.empty?
      @renderer.begin_code nil
    else
      @renderer.begin_code language
    end

    @line += 1

    if @line < @lines.size
      while true
        line = @lines[@line]

        @renderer.text line
        @line += 1

        if (@line == @lines.size)
          break
        end

        if starts_with_backticks? @lines[@line]
          @line += 1
          break
        end

        newline
      end
    end

    @renderer.end_code

    append_double_newline_if_has_more
  end

  def render_quote
    @renderer.begin_quote

    join_next_lines continue_on: :quote
    line = @lines[@line]

    process_line line.byte_slice(line.index('>').not_nil! + 1)

    @line += 1

    @renderer.end_quote

    append_double_newline_if_has_more
  end

  def render_unordered_list(prefix = '*')
    @renderer.begin_unordered_list

    while true
      break unless starts_with_bullet_list_marker?(@lines[@line], prefix)

      join_next_lines continue_on: nil, stop_on: UnorderedList.new(prefix)
      line = @lines[@line]

      if empty? line
        @line += 1

        if @line == @lines.size
          break
        end

        next
      end

      if line.starts_with?("  ") && previous_line_is_not_intended_and_starts_with_bullet_list_marker?(prefix)
        @renderer.begin_unordered_list
      end

      @renderer.begin_list_item
      process_line line.byte_slice(line.index(prefix).not_nil! + 1)
      @renderer.end_list_item

      if line.starts_with?("  ") && next_line_is_not_intended?
        @renderer.end_unordered_list
      end

      @line += 1

      if @line == @lines.size
        break
      end
    end

    @renderer.end_unordered_list

    append_double_newline_if_has_more
  end

  def render_ordered_list
    @renderer.begin_ordered_list

    while true
      break unless starts_with_digits_dot? @lines[@line]

      join_next_lines continue_on: nil, stop_on: :ordered_list
      line = @lines[@line]

      if empty? line
        @line += 1

        if @line == @lines.size
          break
        end

        next
      end

      @renderer.begin_list_item
      process_line line.byte_slice(line.index('.').not_nil! + 1)
      @renderer.end_list_item
      @line += 1

      if @line == @lines.size
        break
      end
    end

    @renderer.end_ordered_list

    append_double_newline_if_has_more
  end

  def append_double_newline_if_has_more
    if @line < @lines.size
      newline
      newline
    end
  end

  def process_line(line)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = 0

    while pos < bytesize && str[pos].unsafe_chr.ascii_whitespace?
      pos += 1
    end

    cursor = pos
    one_star = false
    two_stars = false
    one_underscore = false
    two_underscores = false
    one_backtick = false
    in_link = false
    last_is_space = true

    while pos < bytesize
      case str[pos].unsafe_chr
      when '*'
        if pos + 1 < bytesize && str[pos + 1].unsafe_chr == '*'
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
        if pos + 1 < bytesize && str[pos + 1].unsafe_chr == '_'
          if two_underscores || (last_is_space && has_closing?('_', 2, str, (pos + 2), bytesize))
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
        elsif one_underscore || (last_is_space && has_closing?('_', 1, str, (pos + 1), bytesize))
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
      when '!'
        if pos + 1 < bytesize && str[pos + 1] === '['
          link = check_link str, (pos + 2), bytesize
          if link
            @renderer.text line.byte_slice(cursor, pos - cursor)

            bracket_idx = (str + pos + 2).to_slice(bytesize - pos - 2).index(']'.ord).not_nil!
            alt = line.byte_slice(pos + 2, bracket_idx)

            @renderer.image link, alt

            paren_idx = (str + pos + 2 + bracket_idx + 1).to_slice(bytesize - pos - 2 - bracket_idx - 1).index(')'.ord).not_nil!
            pos += 2 + bracket_idx + 1 + paren_idx
            cursor = pos + 1
          end
        end
      when '['
        unless in_link
          link = check_link str, (pos + 1), bytesize
          if link
            @renderer.text line.byte_slice(cursor, pos - cursor)
            cursor = pos + 1
            @renderer.begin_link link
            in_link = true
          end
        end
      when ']'
        if in_link
          @renderer.text line.byte_slice(cursor, pos - cursor)
          @renderer.end_link

          paren_idx = (str + pos + 1).to_slice(bytesize - pos - 1).index(')'.ord).not_nil!
          pos += paren_idx + 1
          cursor = pos + 1
          in_link = false
        end
      end
      last_is_space = pos < bytesize && str[pos].unsafe_chr.ascii_whitespace?
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
    idx = str.to_slice(bytesize).index char.ord
    return false unless idx

    if count == 2
      return false unless idx + 1 < bytesize && str[idx + 1].unsafe_chr == char
    end

    !str[idx - 1].unsafe_chr.ascii_whitespace?
  end

  def check_link(str, pos, bytesize)
    # We need to count nested brackets to do it right
    bracket_count = 1
    while pos < bytesize
      case str[pos].unsafe_chr
      when '['
        bracket_count += 1
      when ']'
        bracket_count -= 1
        if bracket_count == 0
          break
        end
      end
      pos += 1
    end

    return nil unless bracket_count == 0
    bracket_idx = pos

    return nil unless str[bracket_idx + 1] === '('

    paren_idx = (str + bracket_idx + 1).to_slice(bytesize - bracket_idx - 1).index ')'.ord
    return nil unless paren_idx

    String.new(Slice.new(str + bracket_idx + 2, paren_idx - 1))
  end

  def next_line_is_all?(char)
    return false unless @line + 1 < @lines.size

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

  def next_line_starts_with_backticks?
    return false unless @line + 1 < @lines.size
    starts_with_backticks? @lines[@line + 1]
  end

  def count_pounds(line)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = 0
    while pos < bytesize && pos < 6 && str[pos].unsafe_chr == '#'
      pos += 1
    end
    pos == 0 ? nil : pos
  end

  def has_code_spaces?(line)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = 0
    while pos < bytesize && pos < 4 && str[pos].unsafe_chr.ascii_whitespace?
      pos += 1
    end

    if pos < 4
      pos == bytesize
    else
      true
    end
  end

  def starts_with_bullet_list_marker?(line, prefix = nil)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = 0
    while pos < bytesize && str[pos].unsafe_chr.ascii_whitespace?
      pos += 1
    end

    return false unless pos < bytesize
    return false unless prefix ? str[pos].unsafe_chr == prefix : (str[pos].unsafe_chr == '*' || str[pos].unsafe_chr == '-' || str[pos].unsafe_chr == '+')

    pos += 1

    return false unless pos < bytesize
    str[pos].unsafe_chr.ascii_whitespace?
  end

  def previous_line_is_not_intended_and_starts_with_bullet_list_marker?(prefix)
    previous_line = @lines[@line - 1]
    !previous_line.starts_with?("  ") && starts_with_bullet_list_marker?(previous_line, prefix)
  end

  def next_line_is_not_intended?
    return true unless @line + 1 < @lines.size

    next_line = @lines[@line + 1]
    !next_line.starts_with?("  ")
  end

  def starts_with_backticks?(line)
    line.starts_with? "```"
  end

  def starts_with_digits_dot?(line)
    bytesize = line.bytesize
    str = line.to_unsafe
    pos = 0
    while pos < bytesize && str[pos].unsafe_chr.ascii_whitespace?
      pos += 1
    end

    return false unless pos < bytesize
    return false unless str[pos].unsafe_chr.ascii_number?

    while pos < bytesize && str[pos].unsafe_chr.ascii_number?
      pos += 1
    end

    return false unless pos < bytesize
    str[pos].unsafe_chr == '.'
  end

  def next_lines_empty_of_code?
    line_number = @line

    while line_number < @lines.size
      line = @lines[line_number]

      if empty? line
        # Nothing
      elsif has_code_spaces? line
        return false
      else
        return true
      end

      line_number += 1
    end

    return true
  end

  def horizontal_rule?(line)
    non_space_char = nil
    count = 1

    line.each_char do |char|
      next if char.ascii_whitespace?

      if non_space_char
        if char == non_space_char
          count += 1
        else
          return false
        end
      else
        case char
        when '*', '-', '_'
          non_space_char = char
        else
          return false
        end
      end
    end

    count >= 3
  end

  def render_horizontal_rule
    @renderer.horizontal_rule
    @line += 1
  end

  def newline
    @renderer.text "\n"
  end

  # Join this line with next lines if they form a paragraph,
  # until next lines don't start another entity like a list,
  # header, etc.
  def join_next_lines(continue_on = :none, stop_on = :none)
    start = @line
    line = @line
    line += 1
    while line < @lines.size
      item = classify(@lines[line])

      case item
      when continue_on
        # continue
      when stop_on
        line -= 1
        break
      when nil
        # paragraph: continue
      else
        line -= 1
        break
      end

      line += 1
    end
    line -= 1 if line == @lines.size

    if line > start
      @lines[line] = (start..line).join("\n") { |i| @lines[i] }
      @line = line
    end
  end
end
