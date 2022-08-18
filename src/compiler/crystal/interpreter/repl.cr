class Crystal::Repl
  property prelude : String = "prelude"
  getter program : Program
  getter context : Context

  def initialize
    @program = Program.new
    @context = Context.new(@program)
    @line_number = 1
    @main_visitor = MainVisitor.new(@program)

    @interpreter = Interpreter.new(@context)
  end

  def run
    load_prelude

    prompt = Prompt.new(@context, show_nest: true)

    while true
      input = prompt.prompt("icr:#{prompt.line_number}")
      unless input
        # Explicitly call exit on ctrl+D so at_exit handlers run
        interpret_exit
        break
      end

      if input.blank?
        prompt.line_number += 1
        next
      end

      node = prompt.parse(
        input: input,
        var_scopes: [@interpreter.local_vars.names_at_block_level_zero.to_set],
      )
      next unless node

      begin
        value = interpret(node)
        prompt.display(value)
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
      Interpreter.interpret(@context, exps) do |stack|
        stack.as(UInt8**).value = exception.exception_pointer
      end
    rescue ex
      puts "Error while calling Crystal.exit: #{ex.message}"
    end
  end
end
