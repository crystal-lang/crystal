require "colorize"
require "../syntax_highlighter"

# A syntax highlighter that renders Crystal source code with ANSI escape codes
# suitable for terminal highlighting.
#
# NOTE: To use `Crystal::SyntaxHighlighter::Colorize`, you must explicitly import it with `require "crystal/syntax_highlighter/colorize"`
#
# ```
# require "crystal/syntax_highlighter/colorize"
#
# code = %(foo = bar("baz\#{PI + 1}") # comment)
# colorized = Crystal::SyntaxHighlighter::Colorize.highlight(code)
# colorized # => "foo \e[91m=\e[39m bar(\e[93m\"baz\#{\e[39m\e[36mPI\e[39m \e[91m+\e[39m \e[35m1\e[39m\e[93m}\"\e[39m) \e[90m# comment\e[39m"
# ```
class Crystal::SyntaxHighlighter::Colorize < Crystal::SyntaxHighlighter
  # Highlights *code* and writes the result to *io*.
  def self.highlight(io : IO, code : String)
    new(io).highlight(code)
  end

  # Highlights *code* and returns the result.
  def self.highlight(code : String)
    String.build do |io|
      highlight(io, code)
    end
  end

  # Highlights *code* or returns unhighlighted *code* on error.
  #
  # Same as `.highlight(code : String)` except that any error is rescued and
  # returns unhighlighted source code.
  def self.highlight!(code : String)
    highlight(code)
  rescue
    code
  end

  # Highlights each physical line in *source* independently.
  #
  # The returned array has the same number of elements as `source.split('\n',
  # remove_empty: false)`. Every highlighted line restores the terminal style
  # before its end, so a prefix such as a line number can be inserted before
  # any line without inheriting a style.
  #
  # *through_line* is a zero-based, inclusive line index. When present,
  # highlighting stops after that line and subsequent lines are returned
  # unchanged.
  #
  # If lexing fails, completed lines remain highlighted and each remaining line
  # in the requested range is highlighted in isolation.
  def self.highlight_lines!(source : String, through_line : Int32? = nil, *, colorize : ::Colorize::Object(String) = ::Colorize.with.toggle(true)) : Array(String)
    source_lines = source.split('\n', remove_empty: false)
    render_lines(source_lines, through_line, colorize)
  end

  # :ditto:
  def self.highlight_lines!(source : Array(String), through_line : Int32? = nil, *, colorize : ::Colorize::Object(String) = ::Colorize.with.toggle(true)) : Array(String)
    return source.dup if source.empty?

    render_lines(source, through_line, colorize)
  end

  # Creates a new instance of a Colorize syntax highlighter.
  #
  # Appends highlighted output (when calling `#highlight`) to *io*.
  def initialize(@io : IO, @colorize : ::Colorize::Object(String) = ::Colorize.with.toggle(true))
  end

  property colors : Hash(TokenType, ::Colorize::Color) = {
    :comment           => :dark_gray,
    :number            => :magenta,
    :char              => :light_yellow,
    :symbol            => :magenta,
    :string            => :light_yellow,
    :interpolation     => :light_yellow,
    :const             => :cyan,
    :operator          => :light_red,
    :ident             => :light_green,
    :keyword           => :light_red,
    :primitive_literal => :magenta,
    :self              => :blue,
  } of TokenType => ::Colorize::Color

  def render(type : TokenType, value : String)
    colorize(type, value)
  end

  def render_delimiter(&)
    @colorize.fore(colors[TokenType::STRING]).surround(@io) do
      yield
    end
  end

  def render_interpolation(&)
    colorize :INTERPOLATION, "\#{"
    @colorize.fore(:default).surround(@io) do
      yield
    end
    colorize :INTERPOLATION, "}"
  end

  def render_string_array(&)
    @colorize.fore(colors[TokenType::STRING]).surround(@io) do
      yield
    end
  end

  private def colorize(type : TokenType, token)
    if color = colors[type]?
      @colorize.fore(color).surround(@io) do
        @io << token
      end
    else
      @io << token
    end
  end

  private class LineLimitReached < Exception
  end

  # Renders each highlighted physical line as its own string, carrying the
  # active syntax style across line breaks.
  private class LineRenderer < Crystal::SyntaxHighlighter::Colorize
    getter lines = [] of String

    @foreground : ::Colorize::Color?
    @source_escape_on_line : Bool

    def initialize(@through_line : Int32, colorize : ::Colorize::Object(String))
      @segments = [] of {IO::Memory, ::Colorize::Color?}
      @line_colorize = colorize
      @foreground = nil
      @source_escape_on_line = false
      super(IO::Memory.new, colorize)
    end

    def finish : Nil
      @lines << render_line
    end

    def render(type : TokenType, value : String)
      foreground = colors[type]? || @foreground
      parts = value.split('\n', remove_empty: false)

      parts.each_with_index do |part, index|
        @source_escape_on_line ||= part.includes?('\e')
        append(part, foreground) unless part.empty?
        finish_line if index < parts.size - 1
      end
    end

    def render_delimiter(&)
      with_foreground(colors[TokenType::STRING]) { yield }
    end

    def render_interpolation(&)
      render :INTERPOLATION, "\#{"
      with_foreground(::Colorize::ColorANSI::Default) { yield }
      render :INTERPOLATION, "}"
    end

    def render_string_array(&)
      with_foreground(colors[TokenType::STRING]) { yield }
    end

    private def append(value : String, foreground : ::Colorize::Color?) : Nil
      if previous = @segments.last?
        if previous[1] == foreground
          previous[0] << value
          return
        end
      end

      segment = IO::Memory.new
      segment << value
      @segments << {segment, foreground}
    end

    private def render_line : String
      String.build do |io|
        @segments.each do |segment, foreground|
          if foreground
            @line_colorize.fore(foreground).surround(io) do
              segment.to_s(io)
            end
          else
            segment.to_s(io)
          end
        end

        # Source escapes are opaque to the renderer. A full reset prevents one
        # from leaking a background or mode into the following physical line.
        ::Colorize.reset(io, enabled: true) if @source_escape_on_line
      end
    ensure
      @segments.clear
      @source_escape_on_line = false
    end

    private def finish_line : Nil
      @lines << render_line
      raise LineLimitReached.new if @lines.size > @through_line
    end

    private def with_foreground(foreground : ::Colorize::Color?, &)
      previous_foreground = @foreground
      @foreground = foreground
      yield
    ensure
      @foreground = previous_foreground
    end
  end

  private def self.render_lines(source_lines : Array(String), through_line : Int32?, colorize : ::Colorize::Object(String)) : Array(String)
    result = source_lines.dup
    return result unless colorize.enabled?

    last_line = source_lines.size - 1
    requested_line = through_line || last_line
    return result if requested_line < 0

    requested_line = last_line if requested_line > last_line
    source = build_source(source_lines, requested_line, requested_line < last_line)
    renderer = LineRenderer.new(requested_line, colorize)
    failed = false

    begin
      renderer.highlight(source)
      renderer.finish
    rescue LineLimitReached
      # The requested line was rendered; stopping early is not a failure.
    rescue
      failed = true
    end

    renderer.lines.each_with_index do |line, index|
      result[index] = restore_terminal_carriage_returns(line, source_lines[index]) if index <= requested_line
    end

    if failed
      renderer.lines.size.upto(requested_line) do |index|
        result[index] = highlight_line!(source_lines[index], colorize)
      end
    end

    result
  end

  private def self.highlight_line!(source : String, colorize : ::Colorize::Object(String)) : String
    carriage_return_offset = terminal_carriage_return_offset(source)
    code = source.byte_slice(0, carriage_return_offset)
    highlighted = begin
      String.build do |io|
        new(io, colorize).highlight(code)
      end
    rescue
      code
    end

    String.build do |io|
      io << highlighted
      ::Colorize.reset(io, enabled: true) if code.includes?('\e')
      append_terminal_carriage_returns(io, source, carriage_return_offset)
    end
  end

  private def self.build_source(source_lines : Array(String), last_line : Int32, append_newline : Bool) : String
    String.build do |io|
      0.upto(last_line) do |index|
        line = source_lines[index]
        io.write(line.to_slice[0, terminal_carriage_return_offset(line)])
        io << '\n' if index < last_line || append_newline
      end
    end
  end

  private def self.restore_terminal_carriage_returns(rendered : String, source : String) : String
    carriage_return_offset = terminal_carriage_return_offset(source)
    return rendered if carriage_return_offset == source.bytesize

    String.build(rendered.bytesize + source.bytesize - carriage_return_offset) do |io|
      io << rendered
      append_terminal_carriage_returns(io, source, carriage_return_offset)
    end
  end

  private def self.append_terminal_carriage_returns(io : IO, source : String, offset : Int32) : Nil
    io.write(source.to_slice[offset, source.bytesize - offset])
  end

  private def self.terminal_carriage_return_offset(source : String) : Int32
    offset = source.bytesize
    while offset > 0 && source.to_unsafe[offset - 1] === '\r'
      offset -= 1
    end
    offset
  end
end
