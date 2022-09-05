# A location of an `ASTnode`, including its filename, line number and column number.
class Crystal::Location
  include Comparable(self)

  getter line_number
  getter column_number
  getter filename

  def initialize(@filename : String | VirtualFile | Nil, @line_number : Int32, @column_number : Int32)
  end

  # Returns the directory name of this location's filename. If
  # the filename is a VirtualFile, this is invoked on its expanded
  # location.
  def dirname : String?
    original_filename.try { |filename| File.dirname(filename) }
  end

  # Returns the Location whose filename is a String, not a VirtualFile,
  # traversing virtual file expanded locations.
  def expanded_location
    case filename = @filename
    when String
      self
    when VirtualFile
      filename.expanded_location.try &.expanded_location
    else
      nil
    end
  end

  # Returns the Location whose filename is a String, not a VirtualFile,
  # traversing virtual file expanded locations leading to the original user source code
  def macro_location
    case filename = @filename
    when String
      self
    when VirtualFile
      filename.macro.location.try(&.macro_location)
    else
      nil
    end
  end

  # Returns the filename of the `expanded_location`
  def original_filename
    expanded_location.try &.filename.as?(String)
  end

  def between?(min, max)
    return false unless min && max

    min <= self && self <= max
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  def to_s(io : IO) : Nil
    io << filename << ':' << line_number << ':' << column_number
  end

  def pretty_print(pp)
    pp.text to_s
  end

  def <=>(other)
    self_file = @filename
    other_file = other.filename
    if self_file.is_a?(String) && other_file.is_a?(String) && self_file == other_file
      {@line_number, @column_number} <=> {other.line_number, other.column_number}
    else
      nil
    end
  end
end
