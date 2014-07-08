require "location"

module Crystal
  class Token
    property :type
    property :value
    property :number_kind
    property :line_number
    property :column_number
    property :filename
    property :regex_modifiers
    property :string_state
    property :macro_state

    make_named_tuple MacroState, [whitespace, nest, string_state] do
      def self.default
        MacroState.new(true, 0, nil)
      end
    end

    make_named_tuple StringState, [nest, :end, open_count]

    struct StringState
      def self.default
        StringState.new('\0', '\0', 0)
      end

      def with_open_count_delta(delta)
        StringState.new(@nest, @end, @open_count + delta)
      end
    end

    def initialize
      @type = :EOF
      @number_kind = :i32
      @line_number = 0
      @column_number = 0
      @regex_modifiers = 0
      @string_state = StringState.default
      @macro_state = MacroState.default
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
      @line_number = other.line_number
      @column_number = other.column_number
      @filename = other.filename
      @regex_modifiers = other.regex_modifiers
      @string_state = other.string_state
      @macro_state = other.macro_state
    end

    def to_s(io)
      @value ? @value.to_s(io) : @type.to_s(io)
    end
  end
end
