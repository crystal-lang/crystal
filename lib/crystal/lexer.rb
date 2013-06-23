require 'strscan'

module Crystal
  class Lexer < StringScanner
    MAX_INT_32 = 2147483647
    MAX_UINT_32 = 4294967295
    MAX_INT_64 = 9223372036854775807
    MAX_UINT_64 = 18446744073709551615

    def initialize(str)
      super
      @token = Token.new
      @line_number = 1
      @column_number = 1
    end

    def filename=(filename)
      @filename = filename
    end

    def next_token
      reset_token

      if eos?
        @token.type = :EOF
      elsif scan /\n/
        @token.type = :NEWLINE
        @line_number += 1
        @column_number = 1
      elsif scan /[^\S\n]+/
        @token.type = :SPACE
      elsif scan /;+/
        @token.type = :";"
      elsif match = scan(/(?:\+|-)?\d(?:(_\d)|\d)*\.\d(?:(_\d)|\d)*(?:e(?:\+|-)?\d+)?/)
        has_underscore = self[1] || self[2]
        @token.type = :NUMBER
        lex_float_suffix :f64
        @token.value = has_underscore ? match.gsub('_', '') : match
      elsif match = scan(/(?:\+|-)?\d(?:(_\d)|\d)*e(?:\+|-)?\d+/)
        has_underscore = self[1] || self[2]
        @token.type = :NUMBER
        lex_float_suffix :f64
        @token.value = has_underscore ? match.gsub('_', '') : match
      elsif match = scan(/(?:\+|-)?0x(?:\d|a|A|b|B|c|C|d|D|e|E|f|F)(?:(_(?:\d|a|A|b|B|c|C|d|D|e|E|f|F))|(?:\d|a|A|b|B|c|C|d|D|e|E|f|F))*/)
        has_underscore = self[1]
        @token.type = :NUMBER
        str = (has_underscore ? match.gsub('_', '') : match)
        num = str.to_i(16)
        unless lex_integer_suffix :i32
          set_number_kind_based_on_value num
        end
        @token.value = num.to_s
      elsif match = scan(/(?:\+|-)?0b(?:0|1)(?:(_(?:0|1))|(?:0|1))*/)
        has_underscore = self[1]
        @token.type = :NUMBER
        str = (has_underscore ? match.gsub('_', '') : match)
        num = str.to_i(2)
        unless lex_integer_suffix :i32
          set_number_kind_based_on_value num
        end
        @token.value = num.to_s
      elsif match = scan(/(?:\+|-)?\d(?:(_\d)|\d)*/)
        has_underscore = self[1]
        @token.type = :NUMBER
        str = has_underscore ? match.gsub('_', '') : match
        unless lex_suffix :i32
          num = str.to_i
          set_number_kind_based_on_value num
        end
        @token.value = str
      elsif match = scan(/'\\n'/)
        @token.type = :CHAR
        @token.value = ?\n.ord
      elsif match = scan(/'\\r'/)
        @token.type = :CHAR
        @token.value = ?\r.ord
      elsif match = scan(/'\\t'/)
        @token.type = :CHAR
        @token.value = ?\t.ord
      elsif match = scan(/'\\v'/)
        @token.type = :CHAR
        @token.value = ?\v.ord
      elsif match = scan(/'\\f'/)
        @token.type = :CHAR
        @token.value = ?\f.ord
      elsif match = scan(/'\\0'/)
        @token.type = :CHAR
        @token.value = ?\0.ord
      elsif match = scan(/'\\''/)
        @token.type = :CHAR
        @token.value = ?'.ord
      elsif match = scan(/'\\\\'/)
        @token.type = :CHAR
        @token.value = '\\'.ord
      elsif match = scan(/'.'/)
        @token.type = :CHAR
        @token.value = match[1 .. -2].ord
      elsif match = scan(/"[^\\#\n]*?"/)
        @token.type = :STRING
        @token.value = match[1 .. -2]
      elsif match = scan(/"/)
        @token.type = :STRING_START
      elsif match = scan(/:[a-zA-Z_][a-zA-Z_0-9]*((\?|!)|\b)/)
        @token.type = :SYMBOL
        @token.value = match[1 .. -1]
      elsif match = scan(/:"[^"]+"/)
        @token.type = :SYMBOL
        @token.value = match[2 .. -2]
      elsif match = scan(/\/\S+\//)
        @token.type = :REGEXP
        @token.value = match[1 .. -2]
      elsif match = scan(/\%w\(/)
        @token.type = :STRING_ARRAY_START
      elsif match = scan(%r(!=|!@\B|!|===|==|=~|=>|=|<<=|<<|<=>|<=|<|>>=|>>|>=|>|\+@|\+=|\+|-@|-=|->|-|\*=|\*\*=|\*\*|\*|/=|%=|&=|\|=|\^=|/|\(|\)|,|\.\.\.|\.\.|\.|&&=|&&|&|\|\|=|\|\||\||\{|\}|\?|::|:|%|\^|~@|~|\[\]\=|\[\]|\[|\]))
        @token.type = match.to_sym
      elsif match = scan(/(abstract|def|do|elsif|else|end|if|true|false|class|module|include|while|nil|yield|return|unless|next|break|begin|lib|fun|type|struct|union|enum|macro|out|require|case|when|then|of)((\?|!)|\b)/)
        @token.type = :IDENT
        @token.value = match.end_with?('?') || match.end_with?('!') ? match : match.to_sym
      elsif match = scan(/[A-Z][a-zA-Z_0-9]*\b/)
        @token.type = :CONST
        @token.value = match
      elsif match = scan(/__LINE__\b/)
        @token.type = :INT
        @token.value = @token.line_number
      elsif match = scan(/__FILE__\b/)
        @token.type = :STRING
        @token.value = @filename || '-'
      elsif match = scan(/__DIR__\b/)
        @token.type = :STRING
        @token.value = @filename ? File.dirname(@filename) : '-'
      elsif match = scan(/[a-zA-Z_][a-zA-Z_0-9]*((\?|!)|\b)/)
        @token.type = :IDENT
        @token.value = match
      elsif match = scan(/@[a-zA-Z_][a-zA-Z_0-9]*\b/)
        @token.type = :INSTANCE_VAR
        @token.value = match
      elsif match = scan(/\$\~/)
        @token.type = :GLOBAL
        @token.value = match
      elsif match = scan(/\$\d+/)
        @token.type = :GLOBAL_MATCH
        @token.value = match[1 .. -1].to_i
      elsif match = scan(/\$[a-zA-Z_][a-zA-Z_0-9]*\b/)
        @token.type = :GLOBAL
        @token.value = match
      elsif scan /#/
        if scan /.*\n/
          @token.type = :NEWLINE
          @line_number += 1
          @column_number = 1
        else
          scan /.*/
          @token.type = :EOF
        end
      else
        raise "unknown token: #{rest}"
      end

      @token
    end

    def lex_suffix(default)
      if scan(/_?((?:i|u|f)(?:8|16|32|64))/)
        @token.number_kind = self[1].to_sym
        true
      else
        @token.number_kind = default
        false
      end
    end

    def lex_integer_suffix(default)
      if scan(/_?((?:i|u)(?:8|16|32|64))/)
        @token.number_kind = self[1].to_sym
        true
      else
        @token.number_kind = default
        false
      end
    end

    def lex_float_suffix(default)
      if scan(/_?(f(?:8|16|32|64))/)
        @token.number_kind = self[1].to_sym
        true
      else
        @token.number_kind = default
        false
      end
    end

    def set_number_kind_based_on_value(num)
      if num >= 0
        if num <= MAX_INT_32
          @token.number_kind = :i32
        elsif num <= MAX_UINT_32
          @token.number_kind = :u32
        elsif num <= MAX_INT_64
          @token.number_kind = :i64
        elsif num <= MAX_UINT_64
          @token.number_kind = :u64
        else
          raise "number absolute value too big"
        end
      else
        num_abs = num.abs
        if num_abs <= MAX_INT_32
          @token.number_kind = :i32
        elsif num_abs <= MAX_INT_64
          @token.number_kind = :i64
        else
          raise "number absolute value too big"
        end
      end
    end

    def next_string_token
      reset_token

      if eos?
        @token.type = :EOF
      elsif scan(/"/)
        @token.type = :STRING_END
      elsif scan(/\n/)
        @line_number += 1
        @column_number = 1
        @token.type = :STRING
        @token.value = "\n"
      elsif scan(/\\n/)
        @token.type = :STRING
        @token.value = "\n"
      elsif scan(/\\r/)
        @token.type = :STRING
        @token.value = "\r"
      elsif scan(/\\"/)
        @token.type = :STRING
        @token.value = '"'
      elsif scan(/\\t/)
        @token.type = :STRING
        @token.value = "\t"
      elsif scan(/\\v/)
        @token.type = :STRING
        @token.value = "\v"
      elsif scan(/\\f/)
        @token.type = :STRING
        @token.value = "\f"
      elsif scan(/\\0/)
        @token.type = :STRING
        @token.value = "\0"
      elsif match = scan(/\\./)
        @token.type = :STRING
        @token.value = match[1]
      elsif scan(/\#{/)
        @token.type = :INTERPOLATION_START
      elsif scan(/\#\#/)
        @token.type = :STRING
        @token.value = '#'
      elsif scan(/\#/)
        @token.type = :STRING
        @token.value = '#'
      elsif match = scan(/[^"\\\#\n]+/)
        @token.type = :STRING
        @token.value = match
      end

      @token
    end

    def next_string_array_token
      reset_token

      if eos?
        @token.type = :EOF
      else
        while true
          if match = scan(/\n/)
            @line_number += 1
            @column_number = 1
          elsif scan /[^\S\n]+/
            next
          elsif match = scan(/\)/)
            @token.type = :STRING_ARRAY_END
            break
          else match = scan(/[^\s\)]+/)
            @token.type = :STRING
            @token.value = match
            break
          end
        end
      end

      @token
    end

    def scan(regex)
      if (match = super)
        @column_number += match.length
      end
      match
    end

    def reset_token
      @token.value = nil
      @token.number_kind = nil
      @token.line_number = @line_number
      @token.column_number = @column_number
      @token.filename = @filename
    end

    def next_token_skip_space
      next_token
      skip_space
    end

    def next_token_skip_space_or_newline
      next_token
      skip_space_or_newline
    end

    def next_token_skip_statement_end
      next_token
      skip_statement_end
    end

    def skip_space
      next_token_if :SPACE
    end

    def skip_space_or_newline
      next_token_if :SPACE, :NEWLINE
    end

    def skip_statement_end
      next_token_if :SPACE, :NEWLINE, :";"
    end

    def next_token_if(*types)
      next_token while types.include? @token.type
    end

    def raise(message, line_number = @line_number, column_number = @token.column_number, filename = @filename)
      Kernel::raise Crystal::SyntaxException.new(message, line_number, column_number, filename)
    end
  end
end
