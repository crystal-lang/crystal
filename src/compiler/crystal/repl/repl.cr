class Crystal::Repl
  def initialize
    @interpreter = Interpreter.new
  end

  def run
    while true
      print "> "
      line = gets.try(&.chomp)
      break unless line
      break if line.strip.in?("exit", "quit")

      node = Parser.new(line).parse
      value = @interpreter.interpret(node)
      puts value.value
    end
  end
end
