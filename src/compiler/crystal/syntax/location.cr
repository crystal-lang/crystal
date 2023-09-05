# A location of an `ASTnode`, including its filename, line number and column number.
class Crystal::Location
  include Comparable(self)

  getter line_number
  getter column_number
  getter filename

  def initialize(@filename : String | VirtualFile | Nil, @line_number : Int32, @column_number : Int32)
  end

  # Returns a location from a string representation. Used by compiler tools like
  # `context` and `implementations`.
  def self.parse(cursor : String, *, expand : Bool = false) : self
    file_and_line, _, col = cursor.rpartition(':')
    file, _, line = file_and_line.rpartition(':')

    raise ArgumentError.new "cursor location must be file:line:column" if file.empty? || line.empty? || col.empty?

    file = File.expand_path(file) if expand

    line_number = line.to_i? || 0
    if line_number <= 0
      raise ArgumentError.new "line must be a positive integer, not #{line}"
    end

    column_number = col.to_i? || 0
    if column_number <= 0
      raise ArgumentError.new "column must be a positive integer, not #{col}"
    end

    new(file, line_number, column_number)
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

  # Returns the number of lines between start and finish locations.
  def self.lines(start, finish)
    return unless start && finish && start.filename == finish.filename
    start, finish = finish, start if finish < start

    finish.line_number - start.line_number + 1
  end
end
