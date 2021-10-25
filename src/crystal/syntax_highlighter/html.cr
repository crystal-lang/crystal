require "../syntax_highlighter"

class Crystal::SyntaxHighlighter::HTML < Crystal::SyntaxHighlighter
  def initialize(@io : IO)
  end

  def visit_token(token : Token, last_is_def)
    case token.type
    when :NEWLINE
      @io.puts
    when :SPACE
      @io << token.value
    when :COMMENT
      span "c", ::HTML.escape(token.value.to_s)
    when :NUMBER
      span "n", token.raw
    when :CHAR
      span "s", ::HTML.escape(token.raw)
    when :SYMBOL
      span "n", ::HTML.escape(token.raw)
    when :CONST, :"::"
      span "t", token
    when :DELIMITER_START
      span "s", ::HTML.escape(token.raw)
    when :IDENT
      if last_is_def
        span "m", token
      else
        case token.value
        when :def, :if, :else, :elsif, :end,
             :class, :module, :include, :extend,
             :while, :until, :do, :yield, :return, :unless, :next, :break, :begin,
             :lib, :fun, :type, :struct, :union, :enum, :macro, :out, :require,
             :case, :when, :select, :then, :of, :abstract, :rescue, :ensure, :is_a?,
             :alias, :pointerof, :sizeof, :instance_sizeof, :offsetof, :as, :as?, :typeof, :for, :in,
             :with, :self, :super, :private, :asm, :nil?, :protected, :uninitialized, "new",
             :annotation, :verbatim
          span "k", token
        when :true, :false, :nil
          span "n", token
        else
          @io << token
        end
      end
    when :+, :-, :*, :&+, :&-, :&*, :/, ://,
         :"=", :==, :<, :<=, :>, :>=, :!, :!=, :=~, :!~,
         :&, :|, :^, :~, :**, :>>, :<<, :%,
         :[], :[]?, :[]=, :<=>, :===
      span "o", ::HTML.escape(token.to_s)
    when :"}"
      @io << token
    when :UNDERSCORE
      @io << '_'
    else
      @io << token
    end
  end

  def visit_interpolation(&)
    span_end
    span "i", "\#{"
    yield
    span "i", "}"
    span_start "s"
  end

  def visit_delimiter(&)
    span_start "s"
    yield
    span_end
  end

  def visit_delimiter_token(token)
    ::HTML.escape(token.raw, @io)
  end

  def visit_whitespace(char)
    @io << char
  end

  def visit_string_array(&)
    span_start "s"
    yield
    span_end
  end

  def visit_string_array_token(token)
    ::HTML.escape(token.raw, @io)
  end

  private def span(klass, token)
    span_start klass
    @io << token
    span_end
  end

  private def span_start(klass)
    @io << %(<span class=")
    @io << klass
    @io << %(">)
  end

  private def span_end
    @io << %(</span>)
  end
end
