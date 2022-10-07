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

    # This is a workaround until we find a better solution.
    #
    # We keep old interpreters in memory because if we don't,
    # once the memory is no longer used the finalizers in that program
    # will run, but the memory won't be there anymore.
    #
    # See https://github.com/crystal-lang/crystal/issues/11580
    @old_interpreters = [] of Interpreter

    # Nodes we successfully interpreted. These will be replayed
    # when we detect structural changes.
    @past_nodes = [] of ASTNode
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

      if input == "reload!"
        reload!
        next
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

      # Add to past nodes right way: we'll pop it if we encounter errors.
      @past_nodes << node.clone

      begin
        value = interpret(node)
        prompt.display(value) if value
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

        ex.color = true if @program.color?
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

  private def interpret(node : ASTNode, check_structural_changes : Bool = true)
    @main_visitor = MainVisitor.new(from_main_visitor: @main_visitor)

    begin
      node = @program.normalize(node)
      node = @program.semantic(node, main_visitor: @main_visitor)
    rescue ex : Crystal::Error
      # Don't show the error right away: they might have happened
      # because of structural changes that aren't compatible with
      # the current code.
    end

    if check_structural_changes && has_structural_changes?(node)
      return handle_structural_changes
    end

    if ex
      # If an error happened with the last node we tried to interpreter,
      # don't consider it for future replays.
      @past_nodes.pop
      raise ex
    end

    @interpreter.interpret(node, @main_visitor.meta_vars)
  end

  private def handle_structural_changes(show_output : Bool = true)
    puts "Structural change detected. Replaying session...", &.dark_gray if show_output

    begin
      value = replay
      puts "Session replayed!", &.dark_gray if show_output
      value
    rescue ex : Crystal::Error
      puts "An error happened while replaying with the recent structural changes:", &.yellow
      puts ex
      puts "Continuing without the last input.", &.dark_gray

      # Note: no need to pop the last node because it was removed
      # in the past `interpret` call.

      handle_structural_changes(show_output: false)

      nil
    end
  end

  private def reload!
    begin
      replay
    rescue ex : Crystal::Error
      puts "An error happened while reloading:", &.yellow
      puts ex
      puts "Aborting... bye! 👋", &.yellow
      exit 1
    end
  end

  private def replay
    reset_interpreter

    expressions = Expressions.new
    expressions.expressions << parse_prelude
    expressions.expressions.concat(@past_nodes.clone)

    interpret(expressions, check_structural_changes: false)
  end

  private def interpret_and_exit_on_error(node : ASTNode)
    interpret(node, check_structural_changes: false)
  rescue ex : EscapingException
    # First run at_exit handlers by calling Crystal.exit
    interpret_crystal_exit(ex)
    exit 1
  rescue ex : Crystal::CodeError
    ex.color = true if @program.color?
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

  private def has_structural_changes?(node : ASTNode)
    detector = StructuralChangesDetector.new
    node.accept detector
    detector.has_structural_changes?
  end

  private def reset_interpreter
    # Keep the old interpreter around. See comment on this instance
    # var initialization.
    @old_interpreters << @interpreter
    @program = Program.new
    @context = Context.new(@program)
    @interpreter = Interpreter.new(@context)
    @main_visitor = MainVisitor.new(@program)
  end

  private def puts(message : String, &)
    if @program.color?
      ::puts(yield message.colorize)
    else
      ::puts message
    end
  end

  class StructuralChangesDetector < Visitor
    getter? has_structural_changes = false

    def visit(node : Require | ClassDef | ModuleDef | Def | EnumDef | LibDef | FunDef | Include | Extend | Macro | AnnotationDef | Alias)
      @has_structural_changes = true
      false
    end

    def visit(node : ASTNode)
      true
    end
  end
end
