require "location"

module Crystal
  class Token
    property :type
    property :value
    property :number_kind
    property :line_number
    property :column_number
    property :filename
    property :delimiter_state
    property :macro_state

    record(MacroState, whitespace, nest, delimiter_state, beginning_of_line, yields) do
      def self.default
        MacroState.new(true, 0, nil, true, false)
      end
    end

    record DelimiterState, kind, nest, :end, open_count

    struct DelimiterState
      def self.default
        DelimiterState.new(:string, '\0', '\0', 0)
      end

      def with_open_count_delta(delta)
        DelimiterState.new(@kind, @nest, @end, @open_count + delta)
      end
    end

    def initialize
      @type = :EOF
      @number_kind = :i32
      @line_number = 0
      @column_number = 0
      @delimiter_state = DelimiterState.default
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
      @delimiter_state = other.delimiter_state
      @macro_state = other.macro_state
    end

    def to_s(io)
      @value ? @value.to_s(io) : @type.to_s(io)
    end
  end
end
