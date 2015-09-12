require "../../../partial_comparable"

module Crystal
  class Location
    include PartialComparable(self)

    getter line_number
    getter column_number
    getter filename

    def initialize(@line_number, @column_number, @filename)
    end

    def dirname
      filename = @filename
      if filename.is_a?(String)
        File.dirname(filename)
      else
        nil
      end
    end

    def inspect(io)
      to_s(io)
    end

    def original_filename
      case filename = @filename
      when String
        filename
      when VirtualFile
        filename.expanded_location.try &.original_filename
      else
        nil
      end
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
