# A VirtualFile is used as a Location's filename when
# expanding a macro. It contains the macro expanded source
# code so the user can debug it as if there was a file in the
# filesystem with those contents.
class Crystal::VirtualFile
  # The macro that produced this VirtualFile
  getter macro : Macro

  # The expanded source code of the macro
  getter source : String

  # The location where the macro was expanded (where the macro was invoked).
  getter expanded_location : Location?

  def initialize(@macro : Macro, @source : String, @expanded_location : Location?)
  end

  def to_s(io)
    io << "expanded macro: " << @macro.name
  end

  def inspect(io)
    to_s(io)
  end

  def pretty_print(pp)
    pp.text inspect
  end
end
