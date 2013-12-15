module Crystal
  class VirtualFile; end

  class Location
    @line_number :: Int32
    def line_number
      @line_number
    end

    @column_number :: Int32
    def column_number
      @column_number
    end

    @filename :: String | VirtualFile | Nil
    def filename
      @filename
    end

    def initialize(@line_number, @column_number, @filename)
    end

    def to_s
      "#{filename}:#{line_number}:#{column_number}"
    end
  end
end
