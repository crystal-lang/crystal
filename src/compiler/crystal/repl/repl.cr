class Crystal::Repl
  def initialize
  end

  def run
    while true
      print "> "
      line = gets.try(&.chomp)
      if line.try(&.strip) == "exit"
        break
      end
    end
  end
end
