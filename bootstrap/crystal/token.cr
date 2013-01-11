module Crystal
  class Token
    attr_accessor :type
    attr_accessor :value
    attr_accessor :line_number
    attr_accessor :column_number
    attr_accessor :filename

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
