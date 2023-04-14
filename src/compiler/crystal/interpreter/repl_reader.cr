require "../../../../lib/reply/src/reply"

class Crystal::ReplReader < Reply::Reader
  KEYWORDS = %w(
    abstract alias annotation asm begin break case class
    def do else elsif end ensure enum extend for fun
    if in include instance_sizeof lib macro module
    next of offsetof out pointerof private protected require
    rescue return select sizeof struct super
    then type typeof union uninitialized unless until
    verbatim when while with yield
  )
  METHOD_KEYWORDS = %w(as as? is_a? nil? responds_to?)
  CONTINUE_ERROR  = [
    "expecting identifier 'end', not 'EOF'",
    "expecting token 'CONST', not 'EOF'",
    "expecting any of these tokens: IDENT, CONST, `, <<, <, <=, ==, ===, !=, =~, !~, >>, >, >=, +, -, *, /, //, !, ~, %, &, |, ^, **, [], []?, []=, <=>, &+, &-, &*, &** (not 'EOF')",
    "expecting any of these tokens: ;, NEWLINE (not 'EOF')",
    "expecting token ')', not 'EOF'",
    "expecting token ']', not 'EOF'",
    "expecting token '}', not 'EOF'",
    "expecting token '%}', not 'EOF'",
    "expecting token '}', not ','",
    "expected '}' or named tuple name, not EOF",
    "unexpected token: NEWLINE",
    "unexpected token: EOF",
    "unexpected token: EOF (expecting when, else or end)",
    "unexpected token: EOF (expecting ',', ';' or '\n')",
    "Unexpected EOF on heredoc identifier",
    "unterminated parenthesized expression",
    "unterminated call",
    "Unterminated string literal",
    "unterminated hash literal",
    "Unterminated command literal",
    "unterminated array literal",
    "unterminated tuple literal",
    "unterminated macro",
    "Unterminated string interpolation",
    "invalid trailing comma in call",
    "unknown token: '\\u{0}'",
  ]
  @incomplete = false
  @repl : Repl?

  def initialize(@repl = nil)
    super()

    # `"`, `:`, `'`, are not a delimiter because symbols and strings are treated as one word.
    # '=', !', '?' are not a delimiter because they could make part of method name.
    self.word_delimiters = {{" \n\t+-*/,;@&%<>^\\[](){}|.~".chars}}
  end

  def prompt(io : IO, line_number : Int32, color? : Bool) : Nil
    io << "icr:"
    io << line_number

    io.print(@incomplete ? '*' : '>')
    io << ' '
  end

  def highlight(expression : String) : String
    SyntaxHighlighter::Colorize.highlight!(expression)
  end

  def continue?(expression : String) : Bool
    new_parser(expression).parse
    @incomplete = false
    false
  rescue e : CodeError
    @incomplete = e.message.in?(CONTINUE_ERROR)
    if (message = e.message) && message.matches? /Unterminated heredoc: can't find ".*" anywhere before the end of file/
      @incomplete = true
    end

    @incomplete
  end

  def format(expression : String) : String?
    Crystal.format(expression).chomp rescue nil
  end

  def indentation_level(expression_before_cursor : String) : Int32?
    parser = new_parser(expression_before_cursor)
    parser.parse rescue nil

    parser.type_nest + parser.def_nest + parser.fun_nest
  end

  def reindent_line(line)
    case line.strip
    when "end", ")", "]", "}"
      0
    when "else", "elsif", "rescue", "ensure", "in", "when"
      -1
    else
      nil
    end
  end

  def save_in_history?(expression : String) : Bool
    !expression.blank?
  end

  def auto_complete(name_filter : String, expression : String) : {String, Array(String)}
    if expression.ends_with? '.'
      return "Keywords:", METHOD_KEYWORDS.dup
    else
      return "Keywords:", KEYWORDS.dup
    end
  end

  def auto_completion_display_title(io : IO, title : String)
    io << title
  end

  def auto_completion_display_selected_entry(io : IO, entry : String)
    io << entry.colorize.red.bright
  end

  def auto_completion_display_entry(io : IO, entry_matched : String, entry_remaining : String)
    io << entry_matched.colorize.red.bright << entry_remaining
  end

  private def new_parser(source)
    if repl = @repl
      repl.new_parser(source)
    else
      Parser.new(source)
    end
  end
end
