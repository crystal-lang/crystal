module Crystal
  class Token
    def type
      @type
    end

    def type=(t)
      @type = t
    end

    def value
      @value
    end

    def value=(value)
      @value = value
    end

    def line_number
      @line_number
    end

    def line_number=(line_number)
      @line_number = line_number
    end

    def column_number
      @column_number
    end

    def column_number=(column_number)
      @column_number = column_number
    end

    def filename
      @filename
    end

    def filename=(filename)
      @filename = filename
    end

    def location
      [line_number, column_number, filename]
    end

    def token?(token)
      @type == :TOKEN && @value == token
    end

    def keyword?(keyword)
      @type == :IDENT && @value == keyword
    end

    def to_s
      @value ? @value.to_s : @type.to_s
    end
  end
end
