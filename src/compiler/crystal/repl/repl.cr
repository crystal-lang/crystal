class Crystal::Repl
  def initialize
    @program = Program.new
    load_prelude

    @interpreter = Interpreter.new(@program)
  end

  def run
    while true
      print "> "
      line = gets.try(&.chomp)
      break unless line
      break if line.strip.in?("exit", "quit")

      node = Parser.new(
        line,
        string_pool: @program.string_pool,
        def_vars: [@interpreter.vars.keys.to_set]
      ).parse
      value = @interpreter.interpret(node)
      p value.value
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
