class Crystal::Repl
  def initialize
  end

  def run
    while true
      print "> "
      line = gets.try(&.chomp)
      break unless line
      break if line.strip.in?("exit", "quit")
    end
  end
end
