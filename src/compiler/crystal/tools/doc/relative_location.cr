class Crystal::Doc::RelativeLocation
  include Comparable(self)
  property show_line_number : Bool = false

  # This property is only used to keep backwards compatibility in JSON output.
  property url : String?

  getter filename, line_number

  def initialize(@filename : String, @line_number : Int32)
  end

  def_equals_and_hash @filename, @line_number

  def filename_in_project
    filename.lchop("src/")
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field "filename", filename
      builder.field "line_number", line_number
      builder.field "url", url
    end
  end

  def <=>(other : self)
    cmp = filename <=> other.filename
    return cmp unless cmp == 0
    line_number <=> other.line_number
  end

  def self.from(node : ASTNode, base_dir : String)
    if location = node.location
      from(location, base_dir)
    end
  end

  def self.from(location : Location, base_dir : String)
    filename = location.filename
    if filename.is_a?(VirtualFile)
      location = filename.expanded_location || return
      filename = location.filename
    end

    return unless filename.is_a?(String)
    return unless filename.starts_with? base_dir
    filename = filename[(base_dir.size + 1)..]

    new(filename, location.line_number)
  end
end
