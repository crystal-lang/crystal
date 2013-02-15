require "strscan"
require "token"

class Char
  def ident_start?
    alpha? || self == '_'
  end

  def ident_part?
    ident_start? || digit?
  end

  def ident_part_or_end?
    ident_part? || self == '?' || self == '!'
  end
end

module Crystal
  class Lexer
    def initialize(str)
      @buffer = str.cstr
      @token = Token.new
      @line_number = 1
      @column_number = 1
    end

    def filename=(filename)
      @filename = filename
    end

    def next_token
      reset_token

      # Skip comments
      if @buffer.value == '#'
        char = next_char
        while char != '\n' && char != '\0'
          char = next_char
        end
      end

      start = @buffer
      start_column = @column_number

      case @buffer.value
      when '\0'
        @token.type = :EOF
      when ' ', '\t'
        @token.type = :SPACE
        next_char
        while @buffer.value == ' ' || @buffer.value == '\t'
          @buffer += 1
          @column_number += 1
        end
      when '\n'
        @token.type = :NEWLINE
        next_char
        @line_number += 1
        @column_number = 1
        while @buffer.value == '\n'
          @buffer += 1
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
        when '@'
          if (@buffer + 1).value.ident_start?
            @token.type = :"!"
          else
            next_char :"!@"
          end
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
        case next_char
        when '='
          next_char :"+="
        when '@'
          if (@buffer + 1).value.ident_start?
            @token.type = :"+"
          else
            next_char :"+@"
          end
        when '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
          scan_number(@buffer - 1, 2)
        else
          @token.type = :"+"
        end
      when '-'
        case next_char
        when '='
          next_char :"-="
        when '@'
          if (@buffer + 1).value.ident_start?
            @token.type = :"-"
          else
            next_char :"-@"
          end
        when '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
          scan_number(@buffer - 1, 2)
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
        elsif char == ' ' || char == '\n' || char == '\t' || char == '\0' || char == ';'
          @token.type = :"/"
        else
          start = @buffer
          count = 1
          while next_char != '/'
            count += 1
          end
          @token.type = :REGEXP
          @token.value = String.from_cstr(start, count)
        end
      when '%'
        case next_char
        when '='
          next_char :"%="
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
          next_char :"[]"
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
          start = @buffer
          count = 1
          while next_char.ident_part?
            count += 1
          end
          if @buffer.value == '!' || @buffer.value == '?'
            next_char
            count += 1
          end
          @token.type = :SYMBOL
          @token.value = String.from_cstr(start, count)
        elsif char == '"'
          start = @buffer + 1
          count = 0
          while next_char != '"'
            count += 1
          end
          next_char
          @token.type = :SYMBOL
          @token.value = String.from_cstr(start, count)
        else
          @token.type = :":"
        end
      when '~'
        case next_char
        when '@'
          next_char :"~@"
        else
          @token.type = :"~"
        end
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
          when 'n'
            @token.value = '\n'
          when 't'
            @token.value = '\t'
          when '0'
            @token.value = '\0'
          else
            @token.value = char2
          end
        else
          @token.value = char1
        end
        if next_char != '\''
          raise "unterminated char literal"
        end
        next_char
      when '"'
        start = @buffer + 1
        count = 0
        while (char = next_char) != '"' && char != :EOF
          count += 1
        end
        if char != '"'
          raise "unterminated string literal"
        end
        next_char
        @token.type = :STRING
        @token.value = String.from_cstr(start, count)
      when '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
        scan_number @buffer, 1
      when '@'
        start = @buffer
        next_char
        if @buffer.value.ident_start?
          count = 2
          while next_char.ident_part?
            count += 1
          end
          @token.type = :INSTANCE_VAR
          @token.value = String.from_cstr(start, count)
        else
          raise "unknown token: #{@buffer.value}"
        end
      when '$'
        start = @buffer
        next_char
        if @buffer.value == '~'
          next_char
          @token.type = :GLOBAL
          @token.value = "$~"
        elsif @buffer.value.digit?
          number = @buffer.value - '0'
          while (char = next_char).digit?
            number *= 10
            number += char - '0'
          end
          @token.type = :GLOBAL_MATCH
          @token.value = number
        elsif @buffer.value.ident_start?
          count = 2
          while next_char.ident_part?
            count += 1
          end
          @token.type = :GLOBAL
          @token.value = String.from_cstr(start, count)
        else
          raise "unknown token: #{@buffer.value}"
        end
      when 'b'
        case next_char
        when 'e'
          if next_char == 'g' && next_char == 'i' && next_char == 'n'
            return check_ident_or_keyword(:begin, start, start_column)
          end
        when 'r'
          if next_char == 'e' && next_char == 'a' && next_char == 'k'
            return check_ident_or_keyword(:break, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'c'
        case next_char
        when 'a'
          if next_char == 's' && next_char == 'e'
            return check_ident_or_keyword(:case, start, start_column)
          end
        when 'l'
          if next_char == 'a' && next_char == 's' && next_char == 's'
            return check_ident_or_keyword(:class, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'd'
        case next_char
        when 'e'
          if next_char == 'f'
            return check_ident_or_keyword(:def, start, start_column)
          end
        when 'o' then return check_ident_or_keyword(:do, start, start_column)
        end
        scan_ident(start, start_column)
      when 'e'
        case next_char
        when 'l'
          case next_char
          when 's'
            case next_char
            when 'e' then return check_ident_or_keyword(:else, start, start_column)
            when 'i'
              if next_char == 'f'
                return check_ident_or_keyword(:elsif, start, start_column)
              end
            end
          end
        when 'n'
          if next_char == 'd'
            return check_ident_or_keyword(:end, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'f'
        case next_char
        when 'a'
          if next_char == 'l' && next_char == 's' && next_char == 'e'
            return check_ident_or_keyword(:false, start, start_column)
          end
        when 'u'
          if next_char == 'n'
            return check_ident_or_keyword(:fun, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'g'
        if next_char == 'e' && next_char == 'n' && next_char == 'e' && next_char == 'r' && next_char == 'i' && next_char == 'c'
          return check_ident_or_keyword(:generic, start, start_column)
        end
        scan_ident(start, start_column)
      when 'i'
        case next_char
        when 'f' then return check_ident_or_keyword(:if, start, start_column)
        when 'n'
          if next_char == 'c' && next_char == 'l' && next_char == 'u' && next_char == 'd' && next_char == 'e'
            return check_ident_or_keyword(:include, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'l'
        case next_char
        when 'i'
          if next_char == 'b'
            return check_ident_or_keyword(:lib, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'm'
        case next_char
        when 'a'
          if next_char == 'c' && next_char == 'r' && next_char == 'o'
            return check_ident_or_keyword(:macro, start, start_column)
          end
        when 'o'
          case next_char
          when 'd'
            if next_char == 'u' && next_char == 'l' && next_char == 'e'
              return check_ident_or_keyword(:module, start, start_column)
            end
          end
        end
        scan_ident(start, start_column)
      when 'n'
        case next_char
        when 'e'
          if next_char == 'x' && next_char == 't'
            return check_ident_or_keyword(:next, start, start_column)
          end
        when 'i'
          case next_char
          when 'l' then return check_ident_or_keyword(:nil, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'o'
        if next_char == 'u' && next_char == 't'
          return check_ident_or_keyword(:out, start, start_column)
        end
        scan_ident(start, start_column)
      when 'p'
        if next_char == 't' && next_char == 'r'
          return check_ident_or_keyword(:ptr, start, start_column)
        end
        scan_ident(start, start_column)
      when 'r'
        case next_char
        when 'e'
          case next_char
          when 't'
            if next_char == 'u' && next_char == 'r' && next_char == 'n'
              return check_ident_or_keyword(:return, start, start_column)
            end
          when 'q'
            if next_char == 'u' && next_char == 'i' && next_char == 'r' && next_char == 'e'
              return check_ident_or_keyword(:require, start, start_column)
            end
          end
        end
      when 's'
        if next_char == 't' && next_char == 'r' && next_char == 'u' && next_char == 'c' && next_char == 't'
          return check_ident_or_keyword(:struct, start, start_column)
        end
        scan_ident(start, start_column)
      when 't'
        case next_char
        when 'h'
          if next_char == 'e' && next_char == 'n'
            return check_ident_or_keyword(:then, start, start_column)
          end
        when 'r'
          case next_char
          when 'u'
            if next_char == 'e'
              return check_ident_or_keyword(:true, start, start_column)
            end
          end
        when 'y'
          if next_char == 'p' && next_char == 'e'
            return check_ident_or_keyword(:type, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'u'
        if next_char == 'n' && next_char == 'l' && next_char == 'e' && next_char == 's' && next_char == 's'
          return check_ident_or_keyword(:unless, start, start_column)
        end
        scan_ident(start, start_column)
      when 'w'
        case next_char
        when 'h'
          case next_char
          when 'e'
            if next_char == 'n'
              return check_ident_or_keyword(:when, start, start_column)
            end
          when 'i'
            if next_char == 'l' && next_char == 'e'
              return check_ident_or_keyword(:while, start, start_column)
            end
          end
        end
        scan_ident(start, start_column)
      when 'y'
        if next_char == 'i' && next_char == 'e' && next_char == 'l' && next_char == 'd'
          return check_ident_or_keyword(:yield, start, start_column)
        end
        scan_ident(start, start_column)
      when '_'
        case next_char
        when '_'
          case next_char
          when 'F'
            if next_char == 'I' && next_char == 'L' && next_char == 'E' && next_char == '_' && next_char == '_'
              if (@buffer + 1).value.ident_part_or_end?
                scan_ident(start, start_column)
              else
                @token.type = :STRING
                @token.value = @filename
                return @token
              end
            end
          when 'L'
            if next_char == 'I' && next_char == 'N' && next_char == 'E' && next_char == '_' && next_char == '_'
              if (@buffer + 1).value.ident_part_or_end?
                scan_ident(start, start_column)
              else
                @token.type = :INT
                @token.value = @line_number
                return @token
              end
            end
          end
        else
        end
        scan_ident(start, start_column)
      else
        if 'A' <= @buffer.value && @buffer.value <= 'Z'
          start = @buffer
          count = 1
          while next_char.ident_part?
            count += 1
          end
          @token.type = :CONST
          @token.value = String.from_cstr(start, count)
        elsif ('a' <= @buffer.value && @buffer.value <= 'z') || @buffer.value == '_'
          next_char
          scan_ident(start, start_column)
        else
          raise "unknown token: #{@buffer.value}"
        end
      end

      @token
    end

    def check_ident_or_keyword(symbol, start, start_column)
      if (@buffer + 1).value.ident_part_or_end?
        scan_ident(start, start_column)
      else
        next_char
        @token.type = :IDENT
        @token.value = symbol
      end
      @token
    end

    def scan_ident(start, start_column)
      while @buffer.value.ident_part?
        next_char
      end
      if @buffer.value == '!' || @buffer.value == '?'
        next_char
      end
      @token.type = :IDENT
      @token.value = String.from_cstr(start, @column_number - start_column)
      @token
    end

    def scan_number(start, count)
      while next_char.digit?
        count += 1
      end
      case @buffer.value
      when '.'
        if (@buffer + 1).value.digit?
          next_char
          count += 2
          while next_char.digit?
            count += 1
          end
          if @buffer.value == 'f' || @buffer.value == 'F'
            next_char
            @token.type = :FLOAT
          else
            @token.type = :DOUBLE
          end
        else
          @token.type = :INT
        end
      when 'f', 'F'
        next_char
        @token.type = :FLOAT
      when 'L'
        next_char
        @token.type = :LONG
      else
        @token.type = :INT
      end
      @token.value = String.from_cstr(start, count)
    end

    def next_char
      @buffer += 1
      @column_number += 1
      @buffer.value
    end

    def next_char(token_type)
      next_char
      @token.type = token_type
    end

    def reset_token
      @token.line_number = @line_number
      @token.column_number = @column_number
      @token.filename = @filename
      @token.value = nil
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
      next_token while @token.type == :SPACE
    end

    def skip_space_or_newline
      next_token while (@token.type == :SPACE || @token.type == :NEWLINE)
    end

    def skip_statement_end
      next_token while (@token.type == :SPACE || @token.type == :NEWLINE || @token.type == :";")
    end
  end
end
