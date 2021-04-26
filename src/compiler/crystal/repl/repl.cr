class Crystal::Repl
  def initialize
    @program = Program.new
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
end
