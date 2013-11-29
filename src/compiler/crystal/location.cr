module Crystal
  class Location
    getter :line_number
    getter :column_number
    getter :filename

    def initialize(@line_number, @column_number, @filename)
    end

    def clone
      Location.new(@line_number, @column_number, @filename)
    end

    def to_s
      "#{filename}:#{line_number}:#{column_number}"
    end
  end
end
