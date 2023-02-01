require "./repl_reader"

class Crystal::PryReader < Crystal::ReplReader
  property prompt_info = ""

  def prompt(io, line_number, color?)
    io << "pry("
    io << @prompt_info
    io << ')'

    io.print(@incomplete ? '*' : '>')
    io << ' '
  end

  def continue?(expression : String) : Bool
    if expression == "*s" || expression == "*d"
      @incomplete = false
    else
      super
    end
  end

  def on_ctrl_down(&)
    yield "next"
  end

  def on_ctrl_left(&)
    yield "finish"
  end

  def on_ctrl_right(&)
    yield "step"
  end
end
