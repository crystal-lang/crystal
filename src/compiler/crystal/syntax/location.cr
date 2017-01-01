require "../../../partial_comparable"

# A location of an `ASTnode`, including its filename, line number and column number.
class Crystal::Location
  include PartialComparable(self)

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
  def original_location
    case filename = @filename
    when String
      self
    when VirtualFile
      filename.expanded_location.try &.original_location
    else
      nil
    end
  end

  # Returns the filename of the `original_location`
  def original_filename
    original_location.try &.filename.as?(String)
  end

  def between?(min, max)
    min <= self && self <= max
  end

  def inspect(io)
    to_s(io)
  end

  def to_s(io)
    io << filename << ":" << line_number << ":" << column_number
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
