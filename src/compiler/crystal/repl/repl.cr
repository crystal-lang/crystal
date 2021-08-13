require "../../../crystal/readline"

class Crystal::Repl
  property prelude : String = "prelude"
  getter program : Program
  private getter context

  def initialize
    @program = Program.new
    @context = Context.new(@program)
    @nest = 0
    @incomplete = false
    @line_number = 1
    @main_visitor = MainVisitor.new(@program)

    @interpreter = Interpreter.new(@context)

    @buffer = ""
  end

  def run
    load_prelude

    while true
      prompt = String.build do |io|
        io.print "icr:#{@line_number}:#{@nest}"
        io.print(@incomplete ? '*' : '>')
        io.print ' '
        io.print "  " * @nest if @nest > 0
      end

      line = Readline.readline(prompt, add_history: true)
      unless line
        # Explicitly call exit on ctrl+D so at_exit handlers run
        interpret_exit
        break
      end

      new_buffer =
        if @buffer.empty?
          line
        else
          "#{@buffer}\n#{line}"
        end

      if new_buffer.blank?
        @line_number += 1
        next
      end

      parser = Parser.new(
        new_buffer,
        string_pool: @program.string_pool,
        def_vars: [@interpreter.local_vars.names_at_block_level_zero.to_set]
      )

      begin
        node = parser.parse
      rescue ex : Crystal::SyntaxException
        # TODO: improve this
        if ex.message.in?("unexpected token: EOF", "expecting identifier 'end', not 'EOF'")
          @nest = parser.type_nest + parser.def_nest + parser.fun_nest
          @buffer = new_buffer
          @line_number += 1
          @incomplete = @nest == 0
        elsif ex.message == "expecting token ']', not 'EOF'"
          @nest = parser.type_nest + parser.def_nest + parser.fun_nest
          @buffer = new_buffer
          @line_number += 1
          @incomplete = true
        else
          puts "Error: #{ex.message}"
          @nest = 0
          @buffer = ""
          @incomplete = false
        end
        next
      else
        @nest = 0
        @buffer = ""
        @line_number += 1
      end

      begin
        value = interpret(node)

        print "=> "
        puts value
      rescue ex : EscapingException
        @nest = 0
        @buffer = ""
        @line_number += 1

        print "Unhandled exception: "
        print ex
      rescue ex : Crystal::CodeError
        @nest = 0
        @buffer = ""
        @line_number += 1

        ex.color = true
        ex.error_trace = true
        puts ex
      rescue ex : Exception
        @nest = 0
        @buffer = ""
        @line_number += 1

        ex.inspect_with_backtrace(STDOUT)
      end
    end
  end

  def run_file(filename, argv)
    @interpreter.argv = argv

    prelude_node = parse_prelude
    other_node = parse_file(filename)
    file_node = FileNode.new(other_node, filename)
    exps = Expressions.new([prelude_node, file_node] of ASTNode)

    interpret_and_exit_on_error(exps)

    # Explicitly call exit at the end so at_exit handlers run
    interpret_exit
  end

  def run_code(code, argv = [] of String)
    @interpreter.argv = argv

    prelude_node = parse_prelude
    other_node = parse_code(code)
    exps = Expressions.new([prelude_node, other_node] of ASTNode)

    interpret(exps)
  end

  private def load_prelude
    node = parse_prelude

    interpret_and_exit_on_error(node)
  end

  private def interpret(node : ASTNode)
    node = @program.normalize(node)
    node = @program.semantic(node, main_visitor: @main_visitor)
    @interpreter.interpret(node, @main_visitor.meta_vars)
  end

  private def interpret_and_exit_on_error(node : ASTNode)
    interpret(node)
  rescue ex : EscapingException
    # First run at_exit handlers by calling Crystal.exit
    interpret_crystal_exit(ex)
    exit 1
  rescue ex : Crystal::CodeError
    ex.color = true
    ex.error_trace = true
    puts ex
    exit 1
  rescue ex : Exception
    ex.inspect_with_backtrace(STDOUT)
    exit 1
  end

  private def parse_prelude
    filenames = @program.find_in_path(prelude)
    parsed_nodes = filenames.map { |filename| parse_file(filename) }
    Expressions.new(parsed_nodes)
  end

  private def parse_file(filename)
    parse_code File.read(filename), filename
  end

  private def parse_code(code, filename = "")
    parser = Parser.new code, @program.string_pool
    parser.filename = filename
    parsed_nodes = parser.parse
    @program.normalize(parsed_nodes, inside_exp: false)
  end

  private def interpret_exit
    interpret(Call.new(nil, "exit", global: true))
  end

  private def interpret_crystal_exit(exception : EscapingException)
    decl = UninitializedVar.new(Var.new("ex"), TypeNode.new(@context.program.exception.virtual_type))
    call = Call.new(Path.global("Crystal"), "exit", [NumberLiteral.new(1), Var.new("ex")] of ASTNode)
    exps = Expressions.new([decl, call] of ASTNode)

    begin
      meta_vars = MetaVars.new

      interpreter = Interpreter.new(context)
      # TODO: make stack private? Does it matter?
      interpreter.stack.as(Void**).value = exception.exception_pointer

      main_visitor = MainVisitor.new(context.program, meta_vars: meta_vars)

      exps = context.program.normalize(exps)
      exps = context.program.semantic(exps, main_visitor: main_visitor)

      interpreter.interpret(exps, main_visitor.meta_vars)
    rescue ex
      puts "Error while calling Crystal.exit: #{ex.message}"
    end
  end
end
