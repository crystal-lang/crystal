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
      io << filename << ":" << line_number << ":" << column_number
    end
  end
end
