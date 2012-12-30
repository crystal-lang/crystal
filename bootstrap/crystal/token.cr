module Crystal
  class Token
    attr :type
    attr :value
    attr :line_number
    attr :column_number
    attr :filename

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
