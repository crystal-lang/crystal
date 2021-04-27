class Crystal::Repl
  def initialize
    @program = Program.new
    @nest = 0
    @incomplete = false
    @line_number = 1
    @interpreter = Interpreter.new(@program)
    @main_visitor = MainVisitor.new(@program)
    @top_level_visitor = TopLevelVisitor.new(@program)
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
        def_vars: [@interpreter.var_values.keys.to_set]
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

      @top_level_visitor.reset
      @main_visitor.reset

      begin
        node.accept @top_level_visitor
        node.accept @main_visitor

        value = @interpreter.interpret(node)
        p value.value
      rescue ex : Exception
        @nest = 0
        @buffer = ""
        @line_number += 1

        ex.color = true if ex.is_a?(Crystal::CodeError)
        puts ex
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
      @program.top_level_semantic(parsed_nodes)
    end
  end
end
