module Crystal
  class Location
    property :line_number
    property :column_number
    property :filename

    def initialize(@line_number, @column_number, @filename)
    end

    def clone
      Location.new(@line_number, @column_number, @filename)
    end
  end
end
