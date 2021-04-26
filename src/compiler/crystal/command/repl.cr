# Implementation of the `crystal repl` command

class Crystal::Command
  private def repl
    Repl.new.run
  end
end
