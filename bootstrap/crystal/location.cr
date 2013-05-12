module Crystal
  class Location
    attr_accessor :line_number
    attr_accessor :column_number
    attr_accessor :filename

    def initialize(line_number, column_number, filename)
      @line_number = line_number
      @column_number = column_number
      @filename = filename
    end

    def clone
      Location.new(@line_number, @column_number, @filename)
    end
  end
end