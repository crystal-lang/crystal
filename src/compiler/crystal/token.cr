require "location"

module Crystal
  class Token
    property :type
    property :value
    property :number_kind
    property :string_end
    property :string_nest
    property :string_open_count
    property :line_number
    property :column_number
    property :filename
    property :regex_modifiers

    def initialize
      @type = :EOF
      @number_kind = :i32
      @string_end = '\0'
      @string_nest = '\0'
      @string_open_count = 0
      @line_number = 0
      @column_number = 0
      @regex_modifiers = 0
    end

    def location
      Location.new(line_number, column_number, filename)
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
