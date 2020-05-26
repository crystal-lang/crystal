require "./virtual_file"

# A location of an `ASTNode`, including its filename, line number, column number and (optional) size.
record Crystal::Location,
  filename : String | VirtualFile | Nil,
  line_number : Int32,
  column_number : Int32,
  size : Int32 = 0 do
  include Comparable(self)

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
    return false unless min && max

    min <= self && self <= max
  end

  def inspect(io : IO) : Nil
    io << "Location("
    case filename = @filename
    when String
      filename.inspect_unquoted(io)
    when VirtualFile
      io << filename
    when Nil
    end
    io << ':' << line_number << ':' << column_number

    unless size.zero?
      io << '+' << size
    end

    io << ')'
  end

  def to_s(io : IO) : Nil
    io << filename << ':' << line_number << ':' << column_number

    unless size.zero?
      io << '+' << size
    end
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
