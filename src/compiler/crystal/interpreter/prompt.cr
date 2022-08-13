# Allows reading a prompt for the interpreter.
class Crystal::Repl::Prompt
  property line_number : Int32

  def initialize(@context : Context, @show_nest : Bool)
    @buffer = ""
    @nest = 0
    @incomplete = false
    @line_number = 1
  end

  # Asks for a line of input, prefixed with the given prefix.
  # Returns nil if the user pressed CTRL-C.
  def prompt(prefix) : String?
    prompt = String.build do |io|
      io.print prefix
      if @show_nest
        io.print ':'
        io.print @nest
      end
      io.print(@incomplete ? '*' : '>')
      io.print ' '
      if @nest == 0 && @incomplete
        io.print "  "
      else
        io.print "  " * @nest if @nest > 0
      end
    end

    print prompt
    line = gets
    return unless line

    if @context.program.color?
      # Go back one line to print it again colored
      print "\033[F"
      print prompt

      colored_line = line
      begin
        colored_line = Crystal::SyntaxHighlighter::Colorize.highlight(colored_line)
      rescue
        # Ignore highlight errors
      end

      puts colored_line
    end

    new_buffer =
      if @buffer.empty?
        line
      else
        "#{@buffer}\n#{line}"
      end

    new_buffer
  end

  # Parses the given input with the given var_scopes.
  # The input must be that returned from `#prompt`.
  # Returns a parsed ASTNode if the input was valid Crystal syntax.
  # If the input was partial Crystal syntax, `nil` is returned
  # but the partial input is remembered. Next time `#prompt` is called,
  # the returned value there will be the new complete input (what there
  # was before plus the new input, separated by a new line).
  def parse(input : String, var_scopes : Array(Set(String))) : ASTNode?
    parser = Parser.new(
      input,
      string_pool: @context.program.string_pool,
      var_scopes: var_scopes,
    )

    begin
      node = parser.parse

      @nest = 0
      @buffer = ""
      @line_number += 1
      @incomplete = false

      node
    rescue ex : Crystal::SyntaxException
      # TODO: improve this
      case ex.message
      when "unexpected token: EOF",
           "expecting identifier 'end', not 'EOF'"
        @nest = parser.type_nest + parser.def_nest + parser.fun_nest
        @buffer = input
        @line_number += 1
        @incomplete = @nest == 0
      when "expecting token ']', not 'EOF'",
           "unterminated array literal",
           "unterminated hash literal",
           "unterminated tuple literal"
        @nest = parser.type_nest + parser.def_nest + parser.fun_nest
        @buffer = input
        @line_number += 1
        @incomplete = true
      else
        puts "Error: #{ex.message}"
        @nest = 0
        @buffer = ""
        @incomplete = false
      end
      nil
    end
  end

  # Displays a value, preceding it with "=> ".
  def display(value : Value)
    print "=> "
    puts value
  end
end
