class Crystal::Repl
  def initialize(decompile : Bool, trace : Bool, stats : Bool)
    @program = Program.new
    @context = Context.new(@program, decompile: decompile, trace: trace, stats: stats)
    @nest = 0
    @incomplete = false
    @line_number = 1
    @interpreter = Interpreter.new(@context)
    @buffer = ""

    load_prelude
  end

  def run
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

      parser = Parser.new(
        new_buffer,
        string_pool: @program.string_pool,
        def_vars: [@interpreter.local_var_keys.to_set]
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
        value = @interpreter.interpret(node)
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

  private def load_prelude
    filenames = @program.find_in_path("prelude")
    filenames.each do |filename|
      parser = Parser.new File.read(filename), @program.string_pool
      parser.filename = filename
      parsed_nodes = parser.parse
      parsed_nodes = @program.normalize(parsed_nodes, inside_exp: false)
      semantic(parsed_nodes)
    end
  end

  # TODO: this is more or less a copy of semantic.cr except
  # that we replace some method's bodies for primitives
  private def semantic(node : ASTNode, cleanup = true) : ASTNode
    node, processor = @program.top_level_semantic(node)

    @interpreter.define_primitives

    visitor = InstanceVarsInitializerVisitor.new(@program)
    @program.visit_with_finished_hooks(node, visitor)
    visitor.finish

    @program.visit_class_vars_initializers(node)

    # Check that class vars without an initializer are nilable,
    # give an error otherwise
    processor.check_non_nilable_class_vars_without_initializers

    result = @program.visit_main(node, process_finished_hooks: true, cleanup: cleanup)

    @program.cleanup_types
    @program.cleanup_files

    RecursiveStructChecker.new(@program).run

    result
  end
end
