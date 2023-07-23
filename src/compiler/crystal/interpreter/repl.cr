class Crystal::Repl
  property prelude : String = "prelude"
  getter program : Program
  getter context : Context

  def initialize
    @program = Program.new
    @context = Context.new(@program)
    @main_visitor = MainVisitor.new(@program)

    @interpreter = Interpreter.new(@context)
  end

  def run
    load_prelude

    reader = ReplReader.new(repl: self)
    reader.color = @context.program.color?

    reader.read_loop do |expression|
      case expression
      when "exit"
        break
      when .presence
        parser = new_parser(expression)
        parser.warnings.report(STDOUT)

        node = parser.parse
        next unless node

        value = interpret(node)
        print " => "
        puts SyntaxHighlighter::Colorize.highlight!(value.to_s)
      end
    rescue ex : EscapingException
      print "Unhandled exception: "
      print ex
    rescue ex : Crystal::CodeError
      ex.color = @context.program.color?
      ex.error_trace = true
      puts ex
    rescue ex : Exception
      ex.inspect_with_backtrace(STDOUT)
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
    @main_visitor = MainVisitor.new(from_main_visitor: @main_visitor)

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
    warnings = @program.warnings.dup
    warnings.infos = [] of String
    parser = Parser.new code, @program.string_pool, warnings: warnings
    parser.filename = filename
    parsed_nodes = parser.parse
    warnings.report(STDOUT)
    @program.normalize(parsed_nodes, inside_exp: false)
  end

  private def interpret_exit
    interpret(Call.new(nil, "exit", global: true))
  end

  private def interpret_crystal_exit(exception : EscapingException)
    decl = UninitializedVar.new(Var.new("ex"), TypeNode.new(@context.program.exception.virtual_type))
    call = Call.new(Path.global("Crystal"), "exit", NumberLiteral.new(1), Var.new("ex"))
    exps = Expressions.new([decl, call] of ASTNode)

    begin
      Interpreter.interpret(@context, exps) do |stack|
        stack.as(UInt8**).value = exception.exception_pointer
      end
    rescue ex
      puts "Error while calling Crystal.exit: #{ex.message}"
    end
  end

  protected def new_parser(source)
    Parser.new(
      source,
      string_pool: @context.program.string_pool,
      var_scopes: [@interpreter.local_vars.names_at_block_level_zero.to_set]
    )
  end
end
