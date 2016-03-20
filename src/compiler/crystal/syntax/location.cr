require "../../../partial_comparable"

module Crystal
  class Location
    include PartialComparable(self)

    getter line_number : Int32
    getter column_number : Int32
    getter filename : String | VirtualFile | Nil

    def initialize(@line_number, @column_number, @filename)
    end

    def dirname
      filename = original_filename
      if filename.is_a?(String)
        File.dirname(filename)
      else
        nil
      end
    end

    def inspect(io)
      to_s(io)
    end

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

    def original_filename
      original_location.try &.filename
    end

    def between?(min, max)
      min <= self && self <= max
    end

    def inspect
      to_s
    end

    def to_s(io)
      io << filename << ":" << line_number << ":" << column_number
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
end
