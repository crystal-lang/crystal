require "token"
require "exception"
require "char_reader"

struct Char
  def ident_start?
    alpha? || self == '_'
  end

  def ident_part?
    ident_start? || digit? || self == '$'
  end

  def ident_part_or_end?
    ident_part? || self == '?' || self == '!'
  end
end

module Crystal
  class Lexer
    def initialize(string)
      @reader = CharReader.new(string)
      @token = Token.new
      @line_number = 1
      @column_number = 1
      @filename = ""
    end

    def filename=(filename)
      @filename = filename
    end

    def next_token
      reset_token

      # Skip comments
      if current_char == '#'
        char = next_char_no_column_increment
        while char != '\n' && char != '\0'
          char = next_char_no_column_increment
        end
      end

      start = current_pos

      case current_char
      when '\0'
        @token.type = :EOF
      when ' ', '\t'
        @token.type = :SPACE
        next_char
        while current_char == ' ' || current_char == '\t'
          next_char
        end
      when '\n'
        @token.type = :NEWLINE
        next_char
        @line_number += 1
        @column_number = 1
        consume_newlines
      when '\r'
        if next_char == '\n'
          next_char
          @token.type = :NEWLINE
          @line_number += 1
          @column_number = 1
          consume_newlines
        else
          raise "expected '\\n' after '\\r'"
        end
      when '='
        case next_char
        when '='
          case next_char
          when '='
            next_char :"==="
          else
            @token.type = :"=="
          end
        when '>'
          next_char :"=>"
        when '~'
          next_char :"=~"
        else
          @token.type = :"="
        end
      when '!'
        case next_char
        when '='
          next_char :"!="
        else
          @token.type = :"!"
        end
      when '<'
        case next_char
        when '='
          case next_char
          when '>'
            next_char :"<=>"
          else
            @token.type = :"<="
          end
        when '<'
          case next_char
          when '='
            next_char :"<<="
          when '-'
            here = String::Buffer.new(20)
            here_start = 0

            while true
              case char = next_char
              when '\n'
                next_char
                here_start = current_pos
                break
              else
                here << char
              end
            end

            here = here.to_s

            while true
              case char = next_char
              when '\0'
                raise "unterminated heredoc"
              when '\n'
                here_end = current_pos
                is_here  = false
                here.each_char do |c|
                  unless c == next_char
                    is_here = false
                    break
                  end
                  is_here = true
                end

                if is_here
                  next_char
                  @token.value = string_range(here_start, here_end)
                  @token.type = :STRING
                  break
                end
              end
            end
          else
            @token.type = :"<<"
          end
        else
          @token.type = :"<"
        end
      when '>'
        case next_char
        when '='
          next_char :">="
        when '>'
          case next_char
          when '='
            next_char :">>="
          else
            @token.type = :">>"
          end
        else
          @token.type = :">"
        end
      when '+'
        start = current_pos
        case next_char
        when '='
          next_char :"+="
        when '0'
          case peek_next_char
          when 'x'
            scan_hex_number
          when 'b'
            scan_bin_number
          when '.'
            scan_number(start)
          else
            scan_octal_number
          end
        when '1', '2', '3', '4', '5', '6', '7', '8', '9'
          scan_number(start)
        else
          @token.type = :"+"
        end
      when '-'
        start = current_pos
        case next_char
        when '='
          next_char :"-="
        when '>'
          next_char :"->"
        when '0'
          case peek_next_char
          when 'x'
            scan_hex_number(-1)
          when 'b'
            scan_bin_number(-1)
          when '.'
            scan_number(start)
          else
            scan_octal_number(-1)
          end
        when '1', '2', '3', '4', '5', '6', '7', '8', '9'
          scan_number(start)
        else
          @token.type = :"-"
        end
      when '*'
        case next_char
        when '='
          next_char :"*="
        when '*'
          case next_char
          when '='
            next_char :"**="
          else
            @token.type = :"**"
          end
        else
          @token.type = :"*"
        end
      when '/'
        char = next_char
        if char == '='
          next_char :"/="
        elsif char.whitespace? || char == '\0' || char == ';'
          @token.type = :"/"
        else
          start = current_pos
          string_buffer = String::Buffer.new(20)

          while true
            case char
            when '\\'
              if peek_next_char == '/'
                string_buffer << '/'
                next_char
              else
                string_buffer << char
              end
            when '/'
              next_char
              break
            when '\0'
              raise "unterminated regular expression"
            else
              string_buffer << char
            end
            char = next_char
          end

          modifiers = 0
          while true
            case current_char
            when 'i'
              modifiers |= Regex::IGNORE_CASE
              next_char
            when 'm'
              modifiers |= Regex::MULTILINE
              next_char
            when 'x'
              modifiers |= Regex::EXTENDED
              next_char
            else
              if 'a' <= current_char.downcase <= 'z'
                raise "unknown regex option: #{current_char}"
              end
              break
            end
          end

          @token.type = :REGEX
          @token.regex_modifiers = modifiers
          @token.value = string_buffer.to_s
        end
      when '%'
        case next_char
        when '='
          next_char :"%="
        when '('
          string_start_pair '(', ')'
        when '['
          string_start_pair '[', ']'
        when '{'
          string_start_pair '{', '}'
        when '<'
          string_start_pair '<', '>'
        when 'w'
          if peek_next_char == '('
            next_char
            next_char :STRING_ARRAY_START
          else
            @token.type = :"%"
          end
        when 'i'
          if peek_next_char == '('
            next_char
            next_char :SYMBOL_ARRAY_START
          else
            @token.type = :"%"
          end
        else
          @token.type = :"%"
        end
      when '(' then next_char :"("
      when ')' then next_char :")"
      when '{' then next_char :"{"
      when '}' then next_char :"}"
      when '['
        case next_char
        when ']'
          case next_char
          when '='
            next_char :"[]="
          when '?'
            next_char :"[]?"
          else
            @token.type = :"[]"
          end
        else
          @token.type = :"["
        end
      when ']' then next_char :"]"
      when ',' then next_char :","
      when '?' then next_char :"?"
      when ';' then next_char :";"
      when ':'
        char = next_char
        if char == ':'
          next_char :"::"
        elsif char.ident_start?
          start = current_pos
          while next_char.ident_part?
            # Nothing to do
          end
          if current_char == '!' || current_char == '?'
            next_char
          end
          @token.type = :SYMBOL
          @token.value = string_range(start)
        elsif char == '"'
          start = current_pos + 1
          count = 0

          while true
            char = next_char
            case char
            when '"'
              break
            when '\0'
              raise "unterminated quoted symbol"
            else
              count += 1
            end
          end

          @token.type = :SYMBOL
          @token.value = string_range(start)

          next_char
        else
          @token.type = :":"
        end
      when '~'
        next_char :"~"
      when '.'
        case next_char
        when '.'
          case next_char
          when '.'
            next_char :"..."
          else
            @token.type = :".."
          end
        else
          @token.type = :"."
        end
      when '&'
        case next_char
        when '&'
          case next_char
          when '='
            next_char :"&&="
          else
            @token.type = :"&&"
          end
        when '='
          next_char :"&="
        else
          @token.type = :"&"
        end
      when '|'
        case next_char
        when '|'
          case next_char
          when '='
            next_char :"||="
          else
            @token.type = :"||"
          end
        when '='
          next_char :"|="
        else
          @token.type = :"|"
        end
      when '^'
        case next_char
        when '='
          next_char :"^="
        else
          @token.type = :"^"
        end
      when '\''
        @token.type = :CHAR
        case char1 = next_char
        when '\\'
          case char2 = next_char
          when 'e'
            @token.value = '\e'
          when 'f'
            @token.value = '\f'
          when 'n'
            @token.value = '\n'
          when 'r'
            @token.value = '\r'
          when 't'
            @token.value = '\t'
          when 'v'
            @token.value = '\v'
          when 'x'
            value = consume_hex_escape
            @token.value = value.chr
          when '0', '1', '2', '3', '4', '5', '6', '7', '8'
            char_value = consume_octal_escape(char2)
            @token.value = char_value.chr
          else
            @token.value = char2
          end
        else
          @token.value = char1
        end
        if next_char != '\''
          raise "unterminated char literal", @line_number, @column_number
        end
        next_char
      when '"'
        next_char
        @token.type = :STRING_START
        @token.string_nest = '"'
        @token.string_end = '"'
        @token.string_open_count = 0
      when '0'
        case peek_next_char
        when 'x'
          scan_hex_number
        when 'b'
          scan_bin_number
        when '.'
          scan_number(start)
        else
          scan_octal_number
        end
      when '1', '2', '3', '4', '5', '6', '7', '8', '9'
        scan_number current_pos
      when '@'
        start = current_pos
        if next_char == ':'
          next_char :"@:"
        else
          class_var = false
          if current_char == '@'
            class_var = true
            next_char
          end
          if current_char.ident_start?
            while next_char.ident_part?
              # Nothing to do
            end
            @token.type = class_var ? :CLASS_VAR : :INSTANCE_VAR
            @token.value = string_range(start)
          else
            unknown_token
          end
        end
      when '$'
        start = current_pos
        next_char
        if current_char == '~'
          next_char
          @token.type = :GLOBAL
          @token.value = "$~"
        elsif current_char.digit?
          number = current_char - '0'
          while (char = next_char).digit?
            number *= 10
            number += char - '0'
          end
          @token.type = :GLOBAL_MATCH
          @token.value = number
        elsif current_char.ident_start?
          while next_char.ident_part?
            # Nothing to do
          end
          @token.type = :GLOBAL
          @token.value = string_range(start)
        else
          unknown_token
        end
      when 'a'
        case next_char
        when 'b'
          if next_char == 's' && next_char == 't' && next_char == 'r' && next_char == 'a' && next_char == 'c' && next_char == 't'
            return check_ident_or_keyword(:abstract, start)
          end
        when 'l'
          if next_char == 'i' && next_char == 'a' && next_char == 's'
            return check_ident_or_keyword(:alias, start)
          end
        when 's'
          return check_ident_or_keyword(:as, start)
        end
        scan_ident(start)
      when 'b'
        case next_char
        when 'e'
          if next_char == 'g' && next_char == 'i' && next_char == 'n'
            return check_ident_or_keyword(:begin, start)
          end
        when 'r'
          if next_char == 'e' && next_char == 'a' && next_char == 'k'
            return check_ident_or_keyword(:break, start)
          end
        end
        scan_ident(start)
      when 'c'
        case next_char
        when 'a'
          if next_char == 's' && next_char == 'e'
            return check_ident_or_keyword(:case, start)
          end
        when 'l'
          if next_char == 'a' && next_char == 's' && next_char == 's'
            return check_ident_or_keyword(:class, start)
          end
        end
        scan_ident(start)
      when 'd'
        case next_char
        when 'e'
          if next_char == 'f'
            return check_ident_or_keyword(:def, start)
          end
        when 'o' then return check_ident_or_keyword(:do, start)
        end
        scan_ident(start)
      when 'e'
        case next_char
        when 'l'
          case next_char
          when 's'
            case next_char
            when 'e' then return check_ident_or_keyword(:else, start)
            when 'i'
              if next_char == 'f'
                return check_ident_or_keyword(:elsif, start)
              end
            end
          end
        when 'n'
          case next_char
          when 'd'
            return check_ident_or_keyword(:end, start)
          when 's'
            if next_char == 'u' && next_char == 'r' && next_char == 'e'
              return check_ident_or_keyword(:ensure, start)
            end
          when 'u'
            if next_char == 'm'
              return check_ident_or_keyword(:enum, start)
            end
          end
        when 'x'
          if next_char == 't' && next_char == 'e' && next_char == 'n' && next_char == 'd'
            return check_ident_or_keyword(:extend, start)
          end
        end
        scan_ident(start)
      when 'f'
        case next_char
        when 'a'
          if next_char == 'l' && next_char == 's' && next_char == 'e'
            return check_ident_or_keyword(:false, start)
          end
        when 'u'
          if next_char == 'n'
            return check_ident_or_keyword(:fun, start)
          end
        end
        scan_ident(start)
      when 'i'
        case next_char
        when 'f'
          if peek_next_char == 'd'
            next_char
            if next_char == 'e' && next_char == 'f'
              return check_ident_or_keyword(:ifdef, start)
            end
          else
            return check_ident_or_keyword(:if, start)
          end
        when 'n'
          case next_char
          when 'c'
            if next_char == 'l' && next_char == 'u' && next_char == 'd' && next_char == 'e'
              return check_ident_or_keyword(:include, start)
            end
          when 's'
            if next_char == 't' && next_char == 'a' && next_char == 'n' && next_char == 'c' && next_char == 'e' && next_char == '_' && next_char == 's' && next_char == 'i' && next_char == 'z' && next_char == 'e' && next_char == 'o' && next_char == 'f'
              return check_ident_or_keyword(:instance_sizeof, start)
            end
          end
        when 's'
          if next_char == '_' && next_char == 'a' && next_char == '?'
            return check_ident_or_keyword(:is_a?, start)
          end
        end
        scan_ident(start)
      when 'l'
        case next_char
        when 'i'
          if next_char == 'b'
            return check_ident_or_keyword(:lib, start)
          end
        end
        scan_ident(start)
      when 'm'
        case next_char
        when 'a'
          if next_char == 'c' && next_char == 'r' && next_char == 'o'
            return check_ident_or_keyword(:macro, start)
          end
        when 'o'
          case next_char
          when 'd'
            if next_char == 'u' && next_char == 'l' && next_char == 'e'
              return check_ident_or_keyword(:module, start)
            end
          end
        end
        scan_ident(start)
      when 'n'
        case next_char
        when 'e'
          if next_char == 'x' && next_char == 't'
            return check_ident_or_keyword(:next, start)
          end
        when 'i'
          case next_char
          when 'l' then return check_ident_or_keyword(:nil, start)
          end
        end
        scan_ident(start)
      when 'o'
        case next_char
        when 'f'
            return check_ident_or_keyword(:of, start)
        when 'u'
          if next_char == 't'
            return check_ident_or_keyword(:out, start)
          end
        end
        scan_ident(start)
      when 'p'
        case next_char
        when 't'
          if next_char == 'r'
            return check_ident_or_keyword(:ptr, start)
          end
        when 'o'
          if next_char == 'i' && next_char == 'n' && next_char == 't' && next_char == 'e' && next_char == 'r' && next_char == 'o' && next_char == 'f'
            return check_ident_or_keyword(:pointerof, start)
          end
        end
        scan_ident(start)
      when 'r'
        case next_char
        when 'e'
          case next_char
          when 's'
            if next_char == 'c' && next_char == 'u' && next_char == 'e'
              return check_ident_or_keyword(:rescue, start)
            end
          when 't'
            if next_char == 'u' && next_char == 'r' && next_char == 'n'
              return check_ident_or_keyword(:return, start)
            end
          when 'q'
            if next_char == 'u' && next_char == 'i' && next_char == 'r' && next_char == 'e'
              return check_ident_or_keyword(:require, start)
            end
          end
        end
        scan_ident(start)
      when 's'
        case next_char
        when 'i'
          if next_char == 'z' && next_char == 'e' && next_char == 'o' && next_char == 'f'
            return check_ident_or_keyword(:sizeof, start)
          end
        when 't'
          if next_char == 'r' && next_char == 'u' && next_char == 'c' && next_char == 't'
            return check_ident_or_keyword(:struct, start)
          end
        end
        scan_ident(start)
      when 't'
        case next_char
        when 'h'
          if next_char == 'e' && next_char == 'n'
            return check_ident_or_keyword(:then, start)
          end
        when 'r'
          case next_char
          when 'u'
            if next_char == 'e'
              return check_ident_or_keyword(:true, start)
            end
          end
        when 'y'
          if next_char == 'p' && next_char == 'e'
            if peek_next_char == 'o'
              next_char
              if next_char == 'f'
                return check_ident_or_keyword(:typeof, start)
              end
            else
              return check_ident_or_keyword(:type, start)
            end
          end
        end
        scan_ident(start)
      when 'u'
        if next_char == 'n'
          case next_char
          when 'i'
            if next_char == 'o' && next_char == 'n'
              return check_ident_or_keyword(:union, start)
            end
          when 'l'
            if next_char == 'e' && next_char == 's' && next_char == 's'
              return check_ident_or_keyword(:unless, start)
            end
          end
        end
        scan_ident(start)
      when 'w'
        case next_char
        when 'h'
          case next_char
          when 'e'
            if next_char == 'n'
              return check_ident_or_keyword(:when, start)
            end
          when 'i'
            if next_char == 'l' && next_char == 'e'
              return check_ident_or_keyword(:while, start)
            end
          end
        end
        scan_ident(start)
      when 'y'
        if next_char == 'i' && next_char == 'e' && next_char == 'l' && next_char == 'd'
          return check_ident_or_keyword(:yield, start)
        end
        scan_ident(start)
      when '_'
        case next_char
        when '_'
          case next_char
          when 'D'
            if next_char == 'I' && next_char == 'R' next_char == '_' && next_char == '_'
              if peek_next_char.ident_part_or_end?
                scan_ident(start)
              else
                next_char
                filename = @filename
                @token.type = :STRING
                @token.value = filename.is_a?(String) ? File.dirname(filename) : "-"
                return @token
              end
            end
          when 'F'
            if next_char == 'I' && next_char == 'L' && next_char == 'E' && next_char == '_' && next_char == '_'
              if peek_next_char.ident_part_or_end?
                scan_ident(start)
              else
                next_char
                @token.type = :STRING
                @token.value = @filename
                return @token
              end
            end
          when 'L'
            if next_char == 'I' && next_char == 'N' && next_char == 'E' && next_char == '_' && next_char == '_'
              if peek_next_char.ident_part_or_end?
                scan_ident(start)
              else
                next_char
                @token.type = :INT
                @token.value = @line_number
                return @token
              end
            end
          end
        end
        scan_ident(start)
      else
        if 'A' <= current_char <= 'Z'
          start = current_pos
          while next_char.ident_part?
            # Nothing to do
          end
          @token.type = :CONST
          @token.value = string_range(start)
        elsif ('a' <= current_char <= 'z') || current_char == '_'
          next_char
          scan_ident(start)
        else
          unknown_token
        end
      end

      @token
    end

    def consume_newlines
      while true
        case current_char
        when '\n'
          next_char_no_column_increment
          @line_number += 1
        when '\r'
          if next_char_no_column_increment != '\n'
            raise "expected '\\n' after '\\r'"
          end
          @line_number += 1
        else
          break
        end
      end
    end

    def check_ident_or_keyword(symbol, start)
      if peek_next_char.ident_part_or_end?
        scan_ident(start)
      else
        next_char
        @token.type = :IDENT
        @token.value = symbol
      end
      @token
    end

    def scan_ident(start)
      while current_char.ident_part?
        next_char
      end
      case current_char
      when '!', '?'
        next_char
      end
      @token.type = :IDENT
      @token.value = string_range(start)
      @token
    end

    def scan_number(start)
      @token.type = :NUMBER

      has_underscore = false
      suffix_length = 0

      while true
        char = next_char
        if char.digit?
          # Nothing to do
        elsif char == '_'
          has_underscore = true
        else
          break
        end
      end

      case current_char
      when '.'
        if peek_next_char.digit?
          while true
            char = next_char
            if char.digit?
              # Nothing to do
            elsif char == '_'
              has_underscore = true
            else
              break
            end
          end

          if current_char == 'e' || current_char == 'E'
            next_char

            if current_char == '+' || current_char == '-'
              next_char
            end

            while true
              if current_char.digit?
                # Nothing to do
              elsif current_char == '_'
                has_underscore = true
              else
                break
              end
              next_char
            end
          end

          if current_char == 'f' || current_char == 'F'
            suffix_length = consume_float_suffix
          else
            @token.number_kind = :f64
          end
        else
          @token.number_kind = :i32
        end
      when 'e', 'E'
        next_char

        if current_char == '+' || current_char == '-'
          next_char
        end

        while true
          if current_char.digit?
            # Nothing to do
          elsif current_char == '_'
            has_underscore = true
          else
            break
          end
          next_char
        end

        if current_char == 'f' || current_char == 'F'
          suffix_length = consume_float_suffix
        else
          @token.number_kind = :f64
        end
      when 'f', 'F'
        suffix_length = consume_float_suffix
      when 'i'
        suffix_length = consume_int_suffix
      when 'u'
        suffix_length = consume_uint_suffix
      else
        @token.number_kind = :i32
      end

      string_value = string_range(start, current_pos - suffix_length)
      string_value = string_value.delete('_') if has_underscore
      @token.value = string_value
    end

    def scan_hex_number(multiplier = 1)
      @token.type = :NUMBER
      num = 0
      next_char

      while true
        char = next_char
        if char.digit?
          num = num * 16 + (char - '0')
        elsif ('a' <= char <= 'f')
          num = num * 16 + 10 + (char - 'a')
        elsif ('A' <= char <= 'F')
          num = num * 16 + 10 + (char - 'A')
        elsif char == '_'
        else
          break
        end
      end

      num *= multiplier
      @token.value = num.to_s

      consume_optional_int_suffix
    end

    def scan_octal_number(multiplier = 1)
      @token.type = :NUMBER
      num = 0

      while true
        char = next_char
        if '0' <= char <= '7'
          num = num * 8 + (char - '0')
        elsif char == '_'
        else
          break
        end
      end

      num *= multiplier
      @token.value = num.to_s

      consume_optional_int_suffix
    end

    def scan_bin_number(multiplier = 1)
      @token.type = :NUMBER
      num = 0
      next_char

      while true
        case next_char
        when '0'
          num *= 2
        when '1'
          num = num * 2 + 1
        when '_'
          # Nothing
        else
          break
        end
      end

      num *= multiplier
      @token.value = num.to_s

      consume_optional_int_suffix
    end

    def consume_optional_int_suffix
      case current_char
      when 'i'
        consume_int_suffix
      when 'u'
        consume_uint_suffix
      else
        @token.number_kind = :i32
      end
    end

    def consume_int_suffix
      case next_char
      when '8'
        next_char
        @token.number_kind = :i8
        2
      when '1'
        if next_char == '6'
          next_char
          @token.number_kind = :i16
          3
        else
          raise "invalid int suffix"
        end
      when '3'
        if next_char == '2'
          next_char
          @token.number_kind = :i32
          3
        else
          raise "invalid int suffix"
        end
      when '6'
        if next_char == '4'
          next_char
          @token.number_kind = :i64
          3
        else
          raise "invalid int suffix"
        end
      else
        raise "invalid int suffix"
      end
    end

    def consume_uint_suffix
      case next_char
      when '8'
        next_char
        @token.number_kind = :u8
        2
      when '1'
        if next_char == '6'
          next_char
          @token.number_kind = :u16
          3
        else
          raise "invalid uint suffix"
        end
      when '3'
        if next_char == '2'
          next_char
          @token.number_kind = :u32
          3
        else
          raise "invalid uint suffix"
        end
      when '6'
        if next_char == '4'
          next_char
          @token.number_kind = :u64
          3
        else
          raise "invalid uint suffix"
        end
      else
        raise "invalid uint suffix"
      end
    end

    def consume_float_suffix
      case next_char
      when '3'
        if next_char == '2'
          next_char
          @token.number_kind = :f32
          3
        else
          raise "invalid float suffix"
        end
      when '6'
        if next_char == '4'
          next_char
          @token.number_kind = :f64
          3
        else
          raise "invalid float suffix"
        end
      else
        raise "invalid float suffix"
      end
    end

    def next_string_token(string_nest, string_end, string_open_count)
      case current_char
      when '\0'
        raise "unterminated string literal", @line_number, @column_number
      when string_end
        next_char
        if string_open_count == 0
          @token.type = :STRING_END
        else
          @token.type = :STRING
          @token.value = string_end.to_s
          @token.string_open_count = string_open_count - 1
        end
      when string_nest
        next_char
        @token.type = :STRING
        @token.value = string_nest.to_s
        @token.string_open_count = string_open_count + 1
      when '\\'
        case char = next_char
        when 'n'
          string_token_escape_value "\n"
        when 'r'
          string_token_escape_value "\r"
        when 't'
          string_token_escape_value "\t"
        when 'v'
          string_token_escape_value "\v"
        when 'f'
          string_token_escape_value "\f"
        when 'e'
          string_token_escape_value "\e"
        when 'x'
          value = consume_hex_escape
          next_char
          @token.type = :STRING
          @token.value = value.chr.to_s
        when '0', '1', '2', '3', '4', '5', '6', '7', '8'
          char_value = consume_octal_escape(char)
          next_char
          @token.type = :STRING
          @token.value = char_value.chr.to_s
        else
          @token.type = :STRING
          @token.value = current_char.to_s
          next_char
        end
      when '#'
        if peek_next_char == '{'
          next_char
          next_char
          @token.type = :INTERPOLATION_START
        else
          next_char
          @token.type = :STRING
          @token.value = "#"
        end
      when '\n'
        next_char
        @column_number = 1
        @line_number += 1
        @token.type = :STRING
        @token.value = "\n"
      else
        start = current_pos
        count = 0
        while current_char != string_end &&
              current_char != string_nest &&
              current_char != '\0' &&
              current_char != '\\' &&
              current_char != '#' &&
              current_char != '\n'
          next_char
        end

        @token.type = :STRING
        @token.value = string_range(start)
      end

      @token
    end

    def consume_octal_escape(char)
      char_value = char - '0'
      count = 1
      while count <= 3 && '0' <= peek_next_char && peek_next_char <= '8'
        next_char
        char_value = char_value * 8 + (current_char - '0')
        count += 1
      end
      char_value
    end

    def consume_hex_escape
      after_x = next_char
      if '0' <= after_x <= '9'
        value = after_x - '0'
      elsif 'a' <= after_x <= 'f'
        value = 10 + (after_x - 'a')
      elsif 'A' <= after_x <= 'F'
        value = 10 + (after_x - 'A')
      else
        raise "invalid hex escape", @line_number, @column_number
      end

      after_x2 = peek_next_char
      if '0' <= after_x2 <= '9'
        value = 16 * value + (after_x2 - '0')
        next_char
      elsif 'a' <= after_x2 <= 'f'
        value = 16 * value + (10 + (after_x2 - 'a'))
        next_char
      elsif 'A' <= after_x2 <= 'F'
        value = 16 * value + (10 + (after_x2 - 'A'))
        next_char
      end

      value
    end

    def string_token_escape_value(value)
      next_char
      @token.type = :STRING
      @token.value = value
    end

    def string_start_pair(string_nest, string_end)
      next_char
      @token.type = :STRING_START
      @token.string_nest = string_nest
      @token.string_end = string_end
      @token.string_open_count = 0
    end

    def next_string_array_token
      while true
        if current_char == '\n'
          next_char
          @column_number = 1
          @line_number += 1
        elsif current_char.whitespace?
          next_char
        else
          break
        end
      end

      if current_char == ')'
        next_char
        @token.type = :STRING_ARRAY_END
        return @token
      end

      start = current_pos
      while !current_char.whitespace? && current_char != '\0' && current_char != ')'
        next_char
      end

      @token.type = :STRING
      @token.value = string_range(start)

      @token
    end

    def next_char_no_column_increment
      @reader.next_char
    end

    def next_char
      @column_number += 1
      next_char_no_column_increment
    end

    def next_char(token_type)
      next_char
      @token.type = token_type
    end

    def reset_token
      @token.value = nil
      @token.line_number = @line_number
      @token.column_number = @column_number
      @token.filename = @filename
      @token.location = nil
    end

    def next_comes_uppercase
      pos = current_pos
      while current_char.whitespace?
        next_char
      end
      comes_uppercase = 'A' <= current_char <= 'Z'
      @reader.pos = pos
      comes_uppercase
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

    def current_char
      @reader.current_char
    end

    def peek_next_char
      @reader.peek_next_char
    end

    def current_pos
      @reader.pos
    end

    def current_pos=(pos)
      @reader.pos = pos
    end

    def string
      @reader.string
    end

    def string_range(start_pos)
      string_range(start_pos, current_pos)
    end

    def string_range(start_pos, end_pos)
      @reader.string[start_pos, end_pos - start_pos]
    end

    def skip_space
      while @token.type == :SPACE
        next_token
      end
    end

    def skip_space_or_newline
      while (@token.type == :SPACE || @token.type == :NEWLINE)
        next_token
      end
    end

    def skip_statement_end
      while (@token.type == :SPACE || @token.type == :NEWLINE || @token.type == :";")
        next_token
      end
    end

    def unknown_token
      raise "unknown token: #{current_char.inspect}", @line_number, @column_number
    end

    def raise(message, line_number = @line_number, column_number = @column_number, filename = @filename)
      ::raise Crystal::SyntaxException.new(message, line_number, column_number, filename)
    end

    def raise(message, location : Location)
      raise message, location.line_number, location.column_number, location.filename
    end
  end
end
