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
      @location ||= Location.new(line_number, column_number, filename)
    end

    def location=(@location)
    end

    def token?(token)
      @type == :TOKEN && @value == token
    end

    def keyword?(keyword)
      @type == :IDENT && @value == keyword
    end

    def copy_from(other)
      @type = other.type
      @value = other.value
      @number_kind = other.number_kind
      @string_end = other.string_end
      @string_nest = other.string_nest
      @string_open_count = other.string_open_count
      @line_number = other.line_number
      @column_number = other.column_number
      @filename = other.filename
      @regex_modifiers = other.regex_modifiers
    end

    def to_s
      @value ? @value.to_s : @type.to_s
    end
  end
end
