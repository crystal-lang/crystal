# A VirtualFile is used as a Location's filename when
# expanding a macro. It contains the macro expanded source
# code so the user can debug it as if there was a file in the
# filesystem with those contents.
class Crystal::VirtualFile
  getter :macro
  getter :source
  getter :expanded_location

  def initialize(@macro, @source, @expanded_location)
  end

  def to_s
    "expanded macro: #{@macro.name}"
  end

  def to_s(io)
    io << to_s
  end
end
