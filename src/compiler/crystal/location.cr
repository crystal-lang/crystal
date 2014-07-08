module Crystal
  class Location
    getter line_number
    getter column_number
    getter filename

    def initialize(@line_number, @column_number, @filename)
    end

    def inspect
      to_s
    end

    def to_s(io)
      filename.to_s(io)
      io << ":"
      line_number.to_s(io)
      io << ":"
      column_number.to_s(io)
    end
  end
end
