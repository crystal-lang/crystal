class Crystal::Repl
  def initialize(decompile : Bool, decompile_defs : Bool, trace : Bool, stats : Bool)
    @program = Program.new
    @context = Context.new(@program,
      decompile: decompile,
      decompile_defs: decompile_defs,
      trace: trace,
      stats: stats)
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
      print "icr:#{@line_number}:#{@nest}"
      print(@incomplete ? '*' : '>')
      print ' '
      print "  " * @nest if @nest > 0

      line = gets(chomp: false)
      break unless line
      break if line.strip.in?("exit", "quit")

      new_buffer =
        if @buffer.empty?
          line
        else
          @buffer + line
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
        node = @program.semantic(node, main_visitor: @main_visitor)
        value = @interpreter.interpret_with_main_already_visited(node, @main_visitor)

        print "=> "
        puts value
      rescue ex : Crystal::CodeError
        @nest = 0
        @buffer = ""
        @line_number += 1

        ex.color = true
        ex.error_trace = true
        puts ex
        next
      rescue ex : Exception
        @nest = 0
        @buffer = ""
        @line_number += 1

        ex.inspect_with_backtrace(STDOUT)
        next
      end
    end
  end

  def run_file(filename, argv)
    @interpreter.argv = argv

    prelude_node = parse_prelude

    other_node = parse_file(filename)

    exps = Expressions.new([prelude_node, other_node] of ASTNode)
    node = @program.semantic(exps, main_visitor: @main_visitor)

    interpret_with_main_already_visited(node)
  end

  private def load_prelude
    node = @program.semantic(parse_prelude, main_visitor: @main_visitor)

    interpret_with_main_already_visited(node)
  end

  private def interpret_with_main_already_visited(node : ASTNode)
    @interpreter.interpret_with_main_already_visited(node, @main_visitor)
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
    filenames = @program.find_in_path("prelude")
    parsed_nodes = filenames.map { |filename| parse_file(filename) }
    Expressions.new(parsed_nodes)
  end

  private def parse_file(filename)
    parser = Parser.new File.read(filename), @program.string_pool
    parser.filename = filename
    parsed_nodes = parser.parse
    @program.normalize(parsed_nodes, inside_exp: false)
  end
end
