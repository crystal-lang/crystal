require "../src/reply"
require "crystal/syntax_highlighter/colorize"
require "compiler/crystal/tools/formatter"

CRYSTAL_KEYWORD = %w(
  abstract alias annotation asm begin break case class
  def do else elsif end ensure enum extend for fun
  if in include instance_sizeof lib macro module
  next of offsetof out pointerof private protected require
  rescue return select sizeof struct super
  then type typeof union uninitialized unless until
  verbatim when while with yield
)

CONTINUE_ERROR = [
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

# `"`, `:`, `'`, are not a delimiter because symbols and strings are treated as one word.
# '=', !', '?' are not a delimiter because they could make part of method name.
WORD_DELIMITERS = {{" \n\t+-*/,;@&%<>^\\[](){}|.~".chars}}

class CrystalReader < Reply::Reader
  def prompt(io : IO, line_number : Int32, color? : Bool) : Nil
    io << "crystal".colorize.blue.toggle(color?)
    io << ':'
    io << sprintf("%03d", line_number)
    io << "> "
  end

  def highlight(expression : String) : String
    Crystal::SyntaxHighlighter::Colorize.highlight!(expression)
  end

  def continue?(expression : String) : Bool
    Crystal::Parser.new(expression).parse
    false
  rescue e : Crystal::CodeError
    e.message.in? CONTINUE_ERROR
  end

  def format(expression : String) : String?
    Crystal.format(expression).chomp rescue nil
  end

  def indentation_level(expression_before_cursor : String) : Int32?
    parser = Crystal::Parser.new(expression_before_cursor)
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

  def history_file : Path | String | IO | Nil
    "history.txt"
  end

  def auto_complete(name_filter : String, expression : String) : {String, Array(String)}
    return "Keywords:", CRYSTAL_KEYWORD.dup
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
end

reader = CrystalReader.new
reader.word_delimiters = WORD_DELIMITERS

reader.read_loop do |expression|
  case expression
  when "clear_history"
    reader.clear_history
  when "reset"
    reader.reset
  when "exit"
    break
  when .presence
    # Eval expression here
    print " => "
    puts Crystal::SyntaxHighlighter::Colorize.highlight!(expression)
  end
end
