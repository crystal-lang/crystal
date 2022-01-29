require "./location"

module Crystal
  class Token
    enum Kind
      EOF
      SPACE
      NEWLINE

      IDENT
      CONST
      INSTANCE_VAR
      CLASS_VAR

      CHAR
      STRING
      SYMBOL
      NUMBER

      UNDERSCORE
      COMMENT

      DELIMITER_START
      DELIMITER_END

      STRING_ARRAY_START
      INTERPOLATION_START
      SYMBOL_ARRAY_START
      STRING_ARRAY_END

      GLOBAL
      GLOBAL_MATCH_DATA_INDEX

      MAGIC_DIR
      MAGIC_END_LINE
      MAGIC_FILE
      MAGIC_LINE

      MACRO_LITERAL
      MACRO_EXPRESSION_START
      MACRO_CONTROL_START
      MACRO_VAR
      MACRO_END

      # the following operator kinds should be sorted by their codepoints
      # refer to `#to_s` for the constant names of each individual character

      OP_BANG                     # !
      OP_BANG_EQ                  # !=
      OP_BANG_TILDE               # !~
      OP_DOLLAR_QUESTION          # $?
      OP_DOLLAR_TILDE             # $~
      OP_PERCENT                  # %
      OP_PERCENT_EQ               # %=
      OP_PERCENT_CURLYR           # %}
      OP_AMP                      # &
      OP_AMP_AMP                  # &&
      OP_AMP_AMP_EQ               # &&=
      OP_AMP_STAR                 # &*
      OP_AMP_STAR_STAR            # &**
      OP_AMP_STAR_EQ              # &*=
      OP_AMP_PLUS                 # &+
      OP_AMP_PLUS_EQ              # &+=
      OP_AMP_MINUS                # &-
      OP_AMP_MINUS_EQ             # &-=
      OP_AMP_EQ                   # &=
      OP_PARENL                   # (
      OP_PARENR                   # )
      OP_STAR                     # *
      OP_STAR_STAR                # **
      OP_STAR_STAR_EQ             # **=
      OP_STAR_EQ                  # *=
      OP_PLUS                     # +
      OP_PLUS_EQ                  # +=
      OP_COMMA                    # ,
      OP_MINUS                    # -
      OP_MINUS_EQ                 # -=
      OP_MINUS_GT                 # ->
      OP_PERIOD                   # .
      OP_PERIOD_PERIOD            # ..
      OP_PERIOD_PERIOD_PERIOD     # ...
      OP_SLASH                    # /
      OP_SLASH_SLASH              # //
      OP_SLASH_SLASH_EQ           # //=
      OP_SLASH_EQ                 # /=
      OP_COLON                    # :
      OP_COLON_COLON              # ::
      OP_SEMICOLON                # ;
      OP_LT                       # <
      OP_LT_LT                    # <<
      OP_LT_LT_EQ                 # <<=
      OP_LT_EQ                    # <=
      OP_LT_EQ_GT                 # <=>
      OP_EQ                       # =
      OP_EQ_EQ                    # ==
      OP_EQ_EQ_EQ                 # ===
      OP_EQ_GT                    # =>
      OP_EQ_TILDE                 # =~
      OP_GT                       # >
      OP_GT_EQ                    # >=
      OP_GT_GT                    # >>
      OP_GT_GT_EQ                 # >>=
      OP_QUESTION                 # ?
      OP_AT_SQUAREL               # @[
      OP_SQUAREL                  # [
      OP_SQUAREL_SQUARER          # []
      OP_SQUAREL_SQUARER_EQ       # []=
      OP_SQUAREL_SQUARER_QUESTION # []?
      OP_SQUARER                  # ]
      OP_CARET                    # ^
      OP_CARET_EQ                 # ^=
      OP_GRAVE                    # `
      OP_CURLYL                   # {
      OP_CURLYL_PERCENT           # {%
      OP_CURLYL_CURLYL            # {{
      OP_BAR                      # |
      OP_BAR_EQ                   # |=
      OP_BAR_BAR                  # ||
      OP_BAR_BAR_EQ               # ||=
      OP_CURLYR                   # }
      OP_TILDE                    # ~

      # non-flag enums are special since the `IO` overload relies on the
      # `String`-returning overload instead of the other way round
      def to_s : String
        {% begin %}
          {%
            operator1 = {
              "BANG" => "!", "DOLLAR" => "$", "PERCENT" => "%", "AMP" => "&", "PARENL" => "(",
              "PARENR" => ")", "STAR" => "*", "PLUS" => "+", "COMMA" => ",", "MINUS" => "-",
              "PERIOD" => ".", "SLASH" => "/", "COLON" => ":", "SEMICOLON" => ";", "LT" => "<",
              "EQ" => "=", "GT" => ">", "QUESTION" => "?", "AT" => "@", "SQUAREL" => "[",
              "SQUARER" => "]", "CARET" => "^", "GRAVE" => "`", "CURLYL" => "{", "BAR" => "|",
              "CURLYR" => "}", "TILDE" => "~",
            }
          %}

          case value
          {% for member in @type.constants %}
          when {{ @type.constant(member) }}
            {% if member.starts_with?("OP_") %}
              {% parts = member.split("_") %}
              {{ parts.map { |ch| operator1[ch] || "" }.join("") }}
            {% elsif member.starts_with?("MAGIC_") %}
              {{ "__#{member[6..-1].id}__" }}
            {% else %}
              {{ member.stringify }}
            {% end %}
          {% end %}
          else
            value.to_s
          end
        {% end %}
      end

      def operator?
        value.in?(OP_BANG.value..OP_TILDE.value)
      end

      def assignment_operator?
        # += -= *= /= //= %= |= &= ^= **= <<= >>= ||= &&= &+= &-= &*=
        case self
        when .op_plus_eq?, .op_minus_eq?, .op_star_eq?, .op_slash_eq?, .op_slash_slash_eq?,
             .op_percent_eq?, .op_bar_eq?, .op_amp_eq?, .op_caret_eq?, .op_star_star_eq?,
             .op_lt_lt_eq?, .op_gt_gt_eq?, .op_bar_bar_eq?, .op_amp_amp_eq?, .op_amp_plus_eq?,
             .op_amp_minus_eq?, .op_amp_star_eq?
          true
        else
          false
        end
      end

      def magic?
        magic_dir? || magic_end_line? || magic_file? || magic_line?
      end
    end

    property type : Kind
    property value : Char | String | Symbol | Nil
    property number_kind : Symbol
    property line_number : Int32
    property column_number : Int32
    property filename : String | VirtualFile | Nil
    property delimiter_state : DelimiterState
    property macro_state : MacroState
    property passed_backslash_newline : Bool
    property doc_buffer : IO::Memory?
    property raw : String
    property start : Int32
    property invalid_escape : Bool

    record MacroState,
      whitespace : Bool,
      nest : Int32,
      control_nest : Int32,
      delimiter_state : DelimiterState?,
      beginning_of_line : Bool,
      yields : Bool,
      comment : Bool,
      heredocs : Array(DelimiterState)? do
      def self.default
        MacroState.new(true, 0, 0, nil, true, false, false, nil)
      end

      setter whitespace
      setter control_nest
    end

    enum DelimiterKind
      STRING
      REGEX
      STRING_ARRAY
      SYMBOL_ARRAY
      COMMAND
      HEREDOC
    end

    record DelimiterState,
      kind : DelimiterKind,
      nest : Char | String,
      end : Char | String,
      open_count : Int32,
      heredoc_indent : Int32,
      allow_escapes : Bool do
    end

    struct DelimiterState
      def self.default
        DelimiterState.new(:string, '\0', '\0', 0, 0, true)
      end

      def self.new(kind : DelimiterKind, nest, the_end)
        new kind, nest, the_end, 0, 0, true
      end

      def self.new(kind : DelimiterKind, nest, the_end, allow_escapes : Bool)
        new kind, nest, the_end, 0, 0, allow_escapes
      end

      def self.new(kind : DelimiterKind, nest, the_end, open_count : Int32)
        new kind, nest, the_end, open_count, 0, true
      end

      def with_open_count_delta(delta)
        DelimiterState.new(@kind, @nest, @end, @open_count + delta, @heredoc_indent, @allow_escapes)
      end

      def with_heredoc_indent(indent)
        DelimiterState.new(@kind, @nest, @end, @open_count, indent, @allow_escapes)
      end
    end

    def initialize
      @type = Kind::EOF
      @number_kind = :i32
      @line_number = 0
      @column_number = 0
      @delimiter_state = DelimiterState.default
      @macro_state = MacroState.default
      @passed_backslash_newline = false
      @raw = ""
      @start = 0
      @invalid_escape = false
    end

    def doc
      @doc_buffer.try &.to_s
    end

    @location : Location?

    def location
      @location ||= Location.new(filename, line_number, column_number)
    end

    def location=(@location)
    end

    def token?(token)
      @type.token? && @value == token
    end

    def keyword?
      @type.ident? && @value.is_a?(Symbol)
    end

    def keyword?(keyword)
      @type.ident? && @value == keyword
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
      @doc_buffer = other.doc_buffer
    end

    def to_s(io : IO) : Nil
      @value ? @value.to_s(io) : @type.to_s(io)
    end
  end
end
