require "./token"
require "../exception"
require "string_pool"

module Crystal
  class Lexer
    property? doc_enabled : Bool
    property? comments_enabled : Bool
    property? count_whitespace : Bool
    property? wants_raw : Bool
    property? slash_is_regex : Bool
    getter reader : Char::Reader
    getter token : Token
    property line_number : Int32
    property column_number : Int32
    @filename : String | VirtualFile | Nil
    @stacked_filename : String | VirtualFile | Nil
    @token_end_location : Location?
    @string_pool : StringPool

    def initialize(string, string_pool : StringPool? = nil)
      @reader = Char::Reader.new(string)
      @token = Token.new
      @line_number = 1
      @column_number = 1
      @filename = ""
      @wants_regex = true
      @doc_enabled = false
      @comments_enabled = false
      @count_whitespace = false
      @slash_is_regex = true
      @wants_raw = false
      @string_pool = string_pool || StringPool.new

      # When lexing macro tokens, when we encounter `#{` inside
      # a string we push the current delimiter here and reset
      # the current one to nil. The reason is, inside strings
      # we don't want to consider %foo a macro variable, but
      # we do want to do this inside interpolations.
      # We then count curly braces, with @macro_curly_count,
      # until we find the last `}` and then we pop from the stack
      # and get the original delimiter.
      @delimiter_state_stack = [] of Token::DelimiterState
      @macro_curly_count = 0

      @stacked = false
      @stacked_filename = ""
      @stacked_line_number = 1
      @stacked_column_number = 1
    end

    def filename=(filename)
      @filename = filename
    end

    def next_token
      reset_token

      # Skip comments
      while current_char == '#'
        start = current_pos

        # Check #<loc:...> pragma comment
        if next_char_no_column_increment == '<' &&
           next_char_no_column_increment == 'l' &&
           next_char_no_column_increment == 'o' &&
           next_char_no_column_increment == 'c' &&
           next_char_no_column_increment == ':'
          next_char_no_column_increment
          consume_loc_pragma
          start = current_pos
        else
          if @doc_enabled
            consume_doc
          elsif @comments_enabled
            return consume_comment(start)
          else
            skip_comment
          end
        end
      end

      start = current_pos

      reset_regex_flags = true

      case current_char
      when '\0'
        @token.type = :EOF
      when ' ', '\t'
        consume_whitespace
        reset_regex_flags = false
      when '\\'
        if next_char == '\n'
          incr_line_number
          @token.passed_backslash_newline = true
          consume_whitespace
          reset_regex_flags = false
        else
          unknown_token
        end
      when '\n'
        @token.type = :NEWLINE
        next_char
        incr_line_number
        reset_regex_flags = false
        consume_newlines
      when '\r'
        if next_char == '\n'
          next_char
          @token.type = :NEWLINE
          incr_line_number
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
        when '~'
          next_char :"!~"
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
            here = IO::Memory.new(20)
            has_single_quote = false
            found_closing_single_quote = false

            char = next_char
            if char == '\''
              has_single_quote = true
              char = next_char
            end

            unless ident_start?(char)
              raise "heredoc identifier starts with invalid character"
            end

            here << char
            while true
              char = next_char
              case
              when char == '\r'
                if peek_next_char == '\n'
                  next
                else
                  raise "expecting '\\n' after '\\r'"
                end
              when char == '\n'
                incr_line_number 0
                break
              when ident_part?(char)
                here << char
              when char == '\0'
                raise "unexpected EOF on heredoc identifier"
              else
                if char == '\'' && has_single_quote
                  found_closing_single_quote = true
                  peek = peek_next_char
                  if peek != '\r' && peek != '\n'
                    raise "expecting '\\n' or '\\r' after closing single quote"
                  end
                else
                  raise "invalid character #{char.inspect} for heredoc identifier"
                end
              end
            end

            if has_single_quote && !found_closing_single_quote
              raise "expecting closing single quote"
            end

            here = here.to_s
            delimited_pair :heredoc, here, here, start, allow_escapes: !has_single_quote
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
        @token.start = start
        case next_char
        when '='
          next_char :"+="
        when '0'
          scan_zero_number(start)
        when '1', '2', '3', '4', '5', '6', '7', '8', '9'
          scan_number(start)
        when '+'
          raise "postfix increment is not supported, use `exp += 1`"
        else
          @token.type = :"+"
        end
      when '-'
        @token.start = start
        case next_char
        when '='
          next_char :"-="
        when '>'
          next_char :"->"
        when '0'
          scan_zero_number start, negative: true
        when '1', '2', '3', '4', '5', '6', '7', '8', '9'
          scan_number start, negative: true
        when '-'
          raise "postfix decrement is not supported, use `exp -= 1`"
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
        line = @line_number
        column = @column_number
        char = next_char
        if !@slash_is_regex && char == '='
          next_char :"/="
        elsif @slash_is_regex
          @token.type = :DELIMITER_START
          @token.delimiter_state = Token::DelimiterState.new(:regex, '/', '/')
          @token.raw = "/"
        elsif char.ascii_whitespace? || char == '\0' || char == ';'
          @token.type = :"/"
        elsif @wants_regex
          @token.type = :DELIMITER_START
          @token.delimiter_state = Token::DelimiterState.new(:regex, '/', '/')
          @token.raw = "/"
        else
          @token.type = :"/"
        end
      when '%'
        case next_char
        when '='
          next_char :"%="
        when '(', '[', '{', '<', '|'
          delimited_pair :string, current_char, closing_char, start
        when 'i'
          case peek_next_char
          when '(', '{', '[', '<', '|'
            start_char = next_char
            next_char :SYMBOL_ARRAY_START
            @token.raw = "%i#{start_char}" if @wants_raw
            @token.delimiter_state = Token::DelimiterState.new(:symbol_array, start_char, closing_char(start_char))
          else
            @token.type = :"%"
          end
        when 'q'
          case peek_next_char
          when '(', '{', '[', '<', '|'
            next_char
            delimited_pair :string, current_char, closing_char, start, allow_escapes: false
          else
            @token.type = :"%"
          end
        when 'Q'
          case peek_next_char
          when '(', '{', '[', '<', '|'
            next_char
            delimited_pair :string, current_char, closing_char, start
          else
            @token.type = :"%"
          end
        when 'r'
          case next_char
          when '(', '[', '{', '<', '|'
            delimited_pair :regex, current_char, closing_char, start
          else
            raise "unknown %r char"
          end
        when 'x'
          case next_char
          when '(', '[', '{', '<', '|'
            delimited_pair :command, current_char, closing_char, start
          else
            raise "unknown %x char"
          end
        when 'w'
          case peek_next_char
          when '(', '{', '[', '<', '|'
            start_char = next_char
            next_char :STRING_ARRAY_START
            @token.raw = "%w#{start_char}" if @wants_raw
            @token.delimiter_state = Token::DelimiterState.new(:string_array, start_char, closing_char(start_char))
          else
            @token.type = :"%"
          end
        when '}'
          next_char :"%}"
        else
          @token.type = :"%"
        end
      when '(' then next_char :"("
      when ')' then next_char :")"
      when '{'
        char = next_char
        case char
        when '%'
          next_char :"{%"
        when '{'
          next_char :"{{"
        else
          @token.type = :"{"
        end
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
      when ';'
        reset_regex_flags = false
        next_char :";"
      when ':'
        char = next_char
        case char
        when ':'
          next_char :"::"
        when '+'
          next_char_and_symbol "+"
        when '-'
          next_char_and_symbol "-"
        when '*'
          if next_char == '*'
            next_char_and_symbol "**"
          else
            symbol "*"
          end
        when '/'
          next_char_and_symbol "/"
        when '='
          case next_char
          when '='
            if next_char == '='
              next_char_and_symbol "==="
            else
              symbol "=="
            end
          when '~'
            next_char_and_symbol "=~"
          else
            unknown_token
          end
        when '!'
          case next_char
          when '='
            next_char_and_symbol "!="
          when '~'
            next_char_and_symbol "!~"
          else
            symbol "!"
          end
        when '<'
          case next_char
          when '='
            if next_char == '>'
              next_char_and_symbol "<=>"
            else
              symbol "<="
            end
          when '<'
            next_char_and_symbol "<<"
          else
            symbol "<"
          end
        when '>'
          case next_char
          when '='
            next_char_and_symbol ">="
          when '>'
            next_char_and_symbol ">>"
          else
            symbol ">"
          end
        when '&'
          next_char_and_symbol "&"
        when '|'
          next_char_and_symbol "|"
        when '^'
          next_char_and_symbol "^"
        when '~'
          next_char_and_symbol "~"
        when '%'
          next_char_and_symbol "%"
        when '['
          if next_char == ']'
            case next_char
            when '='
              next_char_and_symbol "[]="
            when '?'
              next_char_and_symbol "[]?"
            else
              symbol "[]"
            end
          else
            unknown_token
          end
        when '"'
          line = @line_number
          column = @column_number
          start = current_pos + 1
          io = IO::Memory.new
          while true
            char = next_char
            case char
            when '\\'
              case char = next_char
              when 'b'
                io << "\u{8}"
              when 'n'
                io << "\n"
              when 'r'
                io << "\r"
              when 't'
                io << "\t"
              when 'v'
                io << "\v"
              when 'f'
                io << "\f"
              when 'e'
                io << "\e"
              when 'x'
                io.write_byte consume_string_hex_escape
              when 'u'
                io << consume_string_unicode_escape
              when '0', '1', '2', '3', '4', '5', '6', '7'
                io.write_byte consume_octal_escape(char)
              when '\n'
                incr_line_number nil
                io << "\n"
              when '\0'
                raise "unterminated quoted symbol", line, column
              else
                io << char
              end
            when '"'
              break
            when '\0'
              raise "unterminated quoted symbol", line, column
            else
              io << char
            end
          end

          @token.type = :SYMBOL
          @token.value = io.to_s
          next_char
          set_token_raw_from_start(start - 2)
        else
          if ident_start?(char)
            start = current_pos
            while ident_part?(next_char)
              # Nothing to do
            end
            if current_char == '!' || current_char == '?'
              next_char
            end
            @token.type = :SYMBOL
            @token.value = string_range_from_pool(start)
            set_token_raw_from_start(start - 1)
          else
            @token.type = :":"
          end
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
        start = current_pos
        line = @line_number
        column = @column_number
        @token.type = :CHAR
        case char1 = next_char
        when '\\'
          case char2 = next_char
          when '\\'
            @token.value = '\\'
          when '\''
            @token.value = '\''
          when 'b'
            @token.value = '\b'
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
          when 'u'
            value = consume_char_unicode_escape
            @token.value = value.chr
          when '0'
            @token.value = '\0'
          when '\0'
            raise "unterminated char literal", line, column
          else
            raise "invalid char escape sequence", line, column
          end
        when '\''
          raise "invalid empty char literal (did you mean '\\\''?)", line, column
        when '\0'
          raise "unterminated char literal", line, column
        else
          @token.value = char1
        end
        if next_char != '\''
          raise "unterminated char literal, use double quotes for strings", line, column
        end
        next_char
        set_token_raw_from_start(start)
      when '"', '`'
        delimiter = current_char
        next_char
        @token.type = :DELIMITER_START
        @token.delimiter_state = Token::DelimiterState.new(delimiter == '`' ? :command : :string, delimiter, delimiter)
        set_token_raw_from_start(start)
      when '0'
        scan_zero_number(start)
      when '1', '2', '3', '4', '5', '6', '7', '8', '9'
        scan_number current_pos
      when '@'
        start = current_pos
        case next_char
        when '['
          next_char :"@["
        else
          class_var = false
          if current_char == '@'
            class_var = true
            next_char
          end
          if ident_start?(current_char)
            while ident_part?(next_char)
              # Nothing to do
            end
            @token.type = class_var ? :CLASS_VAR : :INSTANCE_VAR
            @token.value = string_range_from_pool(start)
          else
            unknown_token
          end
        end
      when '$'
        start = current_pos
        next_char
        case current_char
        when '~'
          next_char
          @token.type = :"$~"
        when '?'
          next_char
          @token.type = :"$?"
        when .ascii_number?
          start = current_pos
          char = next_char
          if char == '0'
            char = next_char
          else
            while char.ascii_number?
              char = next_char
            end
            char = next_char if char == '?'
          end
          @token.type = :GLOBAL_MATCH_DATA_INDEX
          @token.value = string_range_from_pool(start)
        else
          if ident_start?(current_char)
            while ident_part?(next_char)
              # Nothing to do
            end
            @token.type = :GLOBAL
            @token.value = string_range_from_pool(start)
          else
            unknown_token
          end
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
          peek = peek_next_char
          case peek
          when 'm'
            next_char
            return check_ident_or_keyword(:asm, start)
          when '?'
            next_char
            next_char
            @token.type = :IDENT
            @token.value = :as?
            return @token
          else
            return check_ident_or_keyword(:as, start)
          end
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
        when 'o'
          if next_char == 'r'
            return check_ident_or_keyword(:for, start)
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
          return check_ident_or_keyword(:if, start)
        when 'n'
          if ident_part_or_end?(peek_next_char)
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
          else
            next_char
            @token.type = :IDENT
            @token.value = :in
            return @token
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
          when 'l'
            if peek_next_char == '?'
              next_char
              return check_ident_or_keyword(:nil?, start)
            else
              return check_ident_or_keyword(:nil, start)
            end
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
        when 'o'
          if next_char == 'i' && next_char == 'n' && next_char == 't' && next_char == 'e' && next_char == 'r' && next_char == 'o' && next_char == 'f'
            return check_ident_or_keyword(:pointerof, start)
          end
        when 'r'
          case next_char
          when 'i'
            if next_char == 'v' && next_char == 'a' && next_char == 't' && next_char == 'e'
              return check_ident_or_keyword(:private, start)
            end
          when 'o'
            if next_char == 't' && next_char == 'e' && next_char == 'c' && next_char == 't' && next_char == 'e' && next_char == 'd'
              return check_ident_or_keyword(:protected, start)
            end
          end
        end
        scan_ident(start)
      when 'r'
        case next_char
        when 'e'
          case next_char
          when 's'
            case next_char
            when 'c'
              if next_char == 'u' && next_char == 'e'
                return check_ident_or_keyword(:rescue, start)
              end
            when 'p'
              if next_char == 'o' && next_char == 'n' && next_char == 'd' && next_char == 's' && next_char == '_' && next_char == 't' && next_char == 'o' && next_char == '?'
                return check_ident_or_keyword(:responds_to?, start)
              end
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
        when 'e'
          if next_char == 'l'
            case next_char
            when 'e'
              if next_char == 'c' && next_char == 't'
                return check_ident_or_keyword(:select, start)
              end
            when 'f'
              return check_ident_or_keyword(:self, start)
            end
          end
        when 'i'
          if next_char == 'z' && next_char == 'e' && next_char == 'o' && next_char == 'f'
            return check_ident_or_keyword(:sizeof, start)
          end
        when 't'
          if next_char == 'r' && next_char == 'u' && next_char == 'c' && next_char == 't'
            return check_ident_or_keyword(:struct, start)
          end
        when 'u'
          if next_char == 'p' && next_char == 'e' && next_char == 'r'
            return check_ident_or_keyword(:super, start)
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
          if next_char == 'u' && next_char == 'e'
            return check_ident_or_keyword(:true, start)
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
            case next_char
            when 'o'
              if next_char == 'n'
                return check_ident_or_keyword(:union, start)
              end
            when 'n'
              if next_char == 'i' && next_char == 't' && next_char == 'i' && next_char == 'a' && next_char == 'l' && next_char == 'i' && next_char == 'z' && next_char == 'e' && next_char == 'd'
                return check_ident_or_keyword(:uninitialized, start)
              end
            end
          when 'l'
            if next_char == 'e' && next_char == 's' && next_char == 's'
              return check_ident_or_keyword(:unless, start)
            end
          when 't'
            if next_char == 'i' && next_char == 'l'
              return check_ident_or_keyword(:until, start)
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
        when 'i'
          if next_char == 't' && next_char == 'h'
            return check_ident_or_keyword(:with, start)
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
            if next_char == 'I' && next_char == 'R' && next_char == '_' && next_char == '_'
              if ident_part_or_end?(peek_next_char)
                scan_ident(start)
              else
                next_char
                @token.type = :__DIR__
                return @token
              end
            end
          when 'E'
            if next_char == 'N' && next_char == 'D' && next_char == '_' && next_char == 'L' && next_char == 'I' && next_char == 'N' && next_char == 'E' && next_char == '_' && next_char == '_'
              if ident_part_or_end?(peek_next_char)
                scan_ident(start)
              else
                next_char
                @token.type = :__END_LINE__
                return @token
              end
            end
          when 'F'
            if next_char == 'I' && next_char == 'L' && next_char == 'E' && next_char == '_' && next_char == '_'
              if ident_part_or_end?(peek_next_char)
                scan_ident(start)
              else
                next_char
                @token.type = :__FILE__
                return @token
              end
            end
          when 'L'
            if next_char == 'I' && next_char == 'N' && next_char == 'E' && next_char == '_' && next_char == '_'
              if ident_part_or_end?(peek_next_char)
                scan_ident(start)
              else
                next_char
                @token.type = :__LINE__
                return @token
              end
            end
          end
        else
          unless ident_part?(current_char)
            @token.type = :UNDERSCORE
            return @token
          end
        end

        scan_ident(start)
      else
        if current_char.ascii_uppercase?
          start = current_pos
          while ident_part?(next_char)
            # Nothing to do
          end
          @token.type = :CONST
          @token.value = string_range_from_pool(start)
        elsif current_char.ascii_lowercase? || current_char == '_' || current_char.ord > 0x9F
          next_char
          scan_ident(start)
        else
          unknown_token
        end
      end

      if reset_regex_flags
        @wants_regex = true
        @slash_is_regex = false
      end

      @token
    end

    def token_end_location
      @token_end_location ||= Location.new(@filename, @line_number, @column_number - 1)
    end

    def slash_is_regex!
      @slash_is_regex = true
    end

    def slash_is_not_regex!
      @slash_is_regex = false
    end

    def consume_comment(start_pos)
      skip_comment
      @token.type = :COMMENT
      @token.value = string_range(start_pos)
      @token
    end

    def consume_doc
      char = current_char
      start_pos = current_pos

      # Ignore first whitespace after comment, like in `# some doc`
      if char == ' '
        char = next_char
        start_pos = current_pos
      end

      while char != '\n' && char != '\0'
        char = next_char_no_column_increment
      end

      if doc_buffer = @token.doc_buffer
        doc_buffer << '\n'
      else
        @token.doc_buffer = doc_buffer = IO::Memory.new
      end

      doc_buffer.write slice_range(start_pos)
    end

    def skip_comment
      char = current_char
      while char != '\n' && char != '\0'
        char = next_char_no_column_increment
      end
    end

    def consume_whitespace
      start_pos = current_pos
      @token.type = :SPACE
      next_char
      while true
        case current_char
        when ' ', '\t'
          next_char
        when '\\'
          if next_char == '\n'
            next_char
            incr_line_number
            @token.passed_backslash_newline = true
          else
            unknown_token
          end
        else
          break
        end
      end
      if @count_whitespace
        @token.value = string_range(start_pos)
      end
    end

    def consume_newlines
      if @count_whitespace
        return
      end

      while true
        case current_char
        when '\n'
          next_char_no_column_increment
          incr_line_number nil
          @token.doc_buffer = nil
        when '\r'
          if next_char_no_column_increment != '\n'
            raise "expected '\\n' after '\\r'"
          end
          next_char_no_column_increment
          incr_line_number nil
          @token.doc_buffer = nil
        else
          break
        end
      end
    end

    def check_ident_or_keyword(symbol, start)
      if ident_part_or_end?(peek_next_char)
        scan_ident(start)
      else
        next_char
        @token.type = :IDENT
        @token.value = symbol
      end
      @token
    end

    def scan_ident(start)
      while ident_part?(current_char)
        next_char
      end
      if (current_char == '?' || current_char == '!') && peek_next_char != '='
        next_char
      end
      @token.type = :IDENT
      @token.value = string_range_from_pool(start)
      @token
    end

    def next_char_and_symbol(value)
      next_char
      symbol value
    end

    def symbol(value)
      @token.type = :SYMBOL
      @token.value = value
      @token.raw = ":#{value}" if @wants_raw
    end

    def scan_number(start, negative = false)
      @token.type = :NUMBER

      has_underscore = false
      is_integer = true
      has_suffix = true
      suffix_size = 0

      while true
        char = next_char
        if char.ascii_number?
          # Nothing to do
        elsif char == '_'
          has_underscore = true
        else
          break
        end
      end

      case current_char
      when '.'
        if peek_next_char.ascii_number?
          is_integer = false

          while true
            char = next_char
            if char.ascii_number?
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
              if current_char.ascii_number?
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
            suffix_size = consume_float_suffix
          else
            @token.number_kind = :f64
          end
        else
          @token.number_kind = :i32
          has_suffix = false
        end
      when 'e', 'E'
        is_integer = false
        next_char

        if current_char == '+' || current_char == '-'
          next_char
        end

        while true
          if current_char.ascii_number?
            # Nothing to do
          elsif current_char == '_'
            has_underscore = true
          else
            break
          end
          next_char
        end

        if current_char == 'f' || current_char == 'F'
          suffix_size = consume_float_suffix
        else
          @token.number_kind = :f64
        end
      when 'f', 'F'
        is_integer = false
        suffix_size = consume_float_suffix
      when 'i'
        suffix_size = consume_int_suffix
      when 'u'
        suffix_size = consume_uint_suffix
      else
        has_suffix = false
        @token.number_kind = :i32
      end

      end_pos = current_pos - suffix_size

      if end_pos - start == 1
        # For numbers such as 0, 1, 2, 3, etc., we use a string from the poll
        string_value = string_range_from_pool(start, end_pos)
      else
        string_value = string_range(start, end_pos)
      end
      string_value = string_value.delete('_') if has_underscore

      if is_integer
        num_size = string_value.size
        num_size -= 1 if negative

        if has_suffix
          check_integer_literal_fits_in_size string_value, num_size, negative, start
        else
          deduce_integer_kind string_value, num_size, negative, start
        end
      end

      @token.value = string_value
      set_token_raw_from_start(start)
    end

    macro gen_check_int_fits_in_size(type, method, size)
      if num_size >= {{size}}
        int_value = absolute_integer_value(string_value, negative)
        max = {{type}}::MAX.{{method}}
        max += 1 if negative

        if int_value > max
          raise "#{string_value} doesn't fit in an {{type}}", @token, (current_pos - start)
        end
      end
    end

    macro gen_check_uint_fits_in_size(type, size)
      if negative
        raise "Invalid negative value #{string_value} for {{type}}"
      end

      if num_size >= {{size}}
        int_value = absolute_integer_value(string_value, negative)
        if int_value > {{type}}::MAX
          raise "#{string_value} doesn't fit in an {{type}}", @token, (current_pos - start)
        end
      end
    end

    def check_integer_literal_fits_in_size(string_value, num_size, negative, start)
      case @token.number_kind
      when :i8
        gen_check_int_fits_in_size Int8, to_u8, 3
      when :u8
        gen_check_uint_fits_in_size UInt8, 3
      when :i16
        gen_check_int_fits_in_size Int16, to_u16, 5
      when :u16
        gen_check_uint_fits_in_size UInt16, 5
      when :i32
        gen_check_int_fits_in_size Int32, to_u32, 10
      when :u32
        gen_check_uint_fits_in_size UInt32, 10
      when :i64
        gen_check_int_fits_in_size Int64, to_u64, 19
      when :u64
        if negative
          raise "Invalid negative value #{string_value} for UInt64"
        end

        check_value_fits_in_uint64 string_value, num_size, start
      end
    end

    def deduce_integer_kind(string_value, num_size, negative, start)
      check_value_fits_in_uint64 string_value, num_size, start

      if num_size >= 10
        int_value = absolute_integer_value(string_value, negative)

        int64max = Int64::MAX.to_u64
        int64max += 1 if negative

        int32max = Int32::MAX.to_u32
        int32max += 1 if negative

        if int_value > int64max
          @token.number_kind = :u64
        elsif int_value > int32max
          @token.number_kind = :i64
        end
      end
    end

    def absolute_integer_value(string_value, negative)
      if negative
        string_value[1..-1].to_u64
      else
        string_value.to_u64
      end
    end

    def check_value_fits_in_uint64(string_value, num_size, start)
      if num_size > 20
        raise_value_doesnt_fit_in_uint64 string_value, start
      end

      if num_size == 20
        i = 0
        "18446744073709551615".each_byte do |byte|
          string_byte = string_value.byte_at(i)
          if string_byte > byte
            raise_value_doesnt_fit_in_uint64 string_value, start
          elsif string_byte < byte
            break
          end
          i += 1
        end
      end
    end

    def raise_value_doesnt_fit_in_uint64(string_value, start)
      raise "#{string_value} doesn't fit in an UInt64", @token, (current_pos - start)
    end

    def scan_zero_number(start, negative = false)
      case peek_next_char
      when 'x'
        scan_hex_number(start, negative)
      when 'o'
        scan_octal_number(start, negative)
      when 'b'
        scan_bin_number(start, negative)
      when '.'
        scan_number(start)
      when 'i'
        @token.type = :NUMBER
        @token.value = "0"
        next_char
        consume_int_suffix
        set_token_raw_from_start(start)
      when 'f'
        @token.type = :NUMBER
        @token.value = "0"
        next_char
        consume_float_suffix
        set_token_raw_from_start(start)
      when 'u'
        @token.type = :NUMBER
        @token.value = "0"
        next_char
        consume_uint_suffix
        set_token_raw_from_start(start)
      when '_'
        case peek_next_char
        when 'i'
          @token.type = :NUMBER
          @token.value = "0"
          next_char
          consume_int_suffix
          set_token_raw_from_start(start)
        when 'f'
          @token.type = :NUMBER
          @token.value = "0"
          next_char
          consume_float_suffix
        when 'u'
          @token.type = :NUMBER
          @token.value = "0"
          next_char
          consume_uint_suffix
        else
          scan_number(start)
        end
      else
        if next_char.ascii_number?
          raise "octal constants should be prefixed with 0o"
        else
          finish_scan_prefixed_number 0_u64, false, start
        end
      end
    end

    def scan_bin_number(start, negative)
      next_char

      num = 0_u64
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

      finish_scan_prefixed_number num, negative, start
    end

    def scan_octal_number(start, negative)
      next_char

      num = 0_u64

      while true
        char = next_char
        if '0' <= char <= '7'
          num = num * 8 + (char - '0')
        elsif char == '_'
        else
          break
        end
      end

      finish_scan_prefixed_number num, negative, start
    end

    def scan_hex_number(start, negative = false)
      next_char

      num = 0_u64
      while true
        char = next_char
        if char == '_'
        else
          hex_value = char_to_hex(char) { nil }
          if hex_value
            num = num * 16 + hex_value
          else
            break
          end
        end
      end

      finish_scan_prefixed_number num, negative, start
    end

    def finish_scan_prefixed_number(num, negative, start)
      if negative
        string_value = (num.to_i64 * -1).to_s
      else
        string_value = num.to_s
      end

      name_size = string_value.size
      name_size -= 1 if negative

      case current_char
      when 'i'
        consume_int_suffix
        check_integer_literal_fits_in_size string_value, name_size, negative, start
      when 'u'
        consume_uint_suffix
        check_integer_literal_fits_in_size string_value, name_size, negative, start
      else
        @token.number_kind = :i32
        deduce_integer_kind string_value, name_size, negative, start
      end

      first_byte = @reader.string.byte_at(start)
      if first_byte === '+'
        string_value = "+#{string_value}"
      elsif first_byte === '-' && num == 0
        string_value = "-0"
      end

      @token.type = :NUMBER
      @token.value = string_value
      set_token_raw_from_start(start)
    end

    def consume_int_suffix
      case next_char
      when '8'
        next_char
        @token.number_kind = :i8
        2
      when '1'
        case next_char
        when '2'
          if next_char == '8'
            next_char
            @token.number_kind = :i128
            4
          else
            raise "invalid int suffix"
          end
        when '6'
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
        case next_char
        when '2'
          if next_char == '8'
            next_char
            @token.number_kind = :u128
            4
          else
            raise "invalid uint suffix"
          end
        when '6'
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

    def next_string_token(delimiter_state)
      @token.line_number = @line_number

      start = current_pos
      string_end = delimiter_state.end
      string_nest = delimiter_state.nest
      string_open_count = delimiter_state.open_count

      case current_char
      when '\0'
        raise_unterminated_quoted string_end
      when string_end
        next_char
        if string_open_count == 0
          @token.type = :DELIMITER_END
        else
          @token.type = :STRING
          @token.value = string_end.to_s
          @token.delimiter_state = @token.delimiter_state.with_open_count_delta(-1)
        end
      when string_nest
        next_char
        @token.type = :STRING
        @token.value = string_nest.to_s
        @token.delimiter_state = @token.delimiter_state.with_open_count_delta(+1)
      when '\\'
        if delimiter_state.allow_escapes
          if delimiter_state.kind == :regex
            char = next_char
            next_char
            @token.type = :STRING
            if string_end == '/' && char == '/'
              @token.value = "/"
            else
              @token.value = "\\#{char}"
            end
          else
            case char = next_char
            when 'b'
              string_token_escape_value "\u{8}"
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
              value = consume_string_hex_escape
              next_char
              @token.type = :STRING
              @token.value = String.new(1) do |buffer|
                buffer[0] = value
                {1, 0}
              end
            when 'u'
              value = consume_string_unicode_escape
              next_char
              @token.type = :STRING
              @token.value = value
            when '0', '1', '2', '3', '4', '5', '6', '7'
              value = consume_octal_escape(char)
              next_char
              @token.type = :STRING
              @token.value = String.new(1) do |buffer|
                buffer[0] = value
                {1, 0}
              end
            when '\n'
              incr_line_number
              @token.line_number = @line_number

              # Skip until the next non-whitespace char
              while true
                char = next_char
                case char
                when '\0'
                  raise_unterminated_quoted string_end
                when '\n'
                  incr_line_number
                  @token.line_number = @line_number
                when .ascii_whitespace?
                  # Continue
                else
                  break
                end
              end
              next_string_token delimiter_state
            else
              @token.type = :STRING
              @token.value = current_char.to_s
              next_char
            end
          end
        else
          @token.type = :STRING
          @token.value = current_char.to_s
          next_char
        end
      when '#'
        if delimiter_state.allow_escapes
          if peek_next_char == '{'
            next_char
            next_char
            @token.type = :INTERPOLATION_START
          else
            next_char
            @token.type = :STRING
            @token.value = "#"
          end
        else
          next_char
          @token.type = :STRING
          @token.value = "#"
        end
      when '\r', '\n'
        is_slash_r = current_char == '\r'
        if is_slash_r
          if next_char != '\n'
            raise "expecting '\\n' after '\\r'"
          end
        end

        next_char
        incr_line_number 1
        @token.line_number = @line_number
        @token.column_number = @column_number

        if delimiter_state.kind == :heredoc
          string_end = string_end.to_s
          old_pos = current_pos
          old_column = @column_number

          while current_char == ' ' || current_char == '\t'
            next_char
          end

          indent = @column_number - 1

          if string_end.starts_with?(current_char)
            reached_end = false

            string_end.each_char do |c|
              unless c == current_char
                reached_end = false
                break
              end
              next_char
              reached_end = true
            end

            if reached_end &&
               (current_char == '\n' || current_char == '\0' ||
               (current_char == '\r' && peek_next_char == '\n' && next_char) ||
               !ident_part?(current_char))
              @token.type = :DELIMITER_END
              @token.delimiter_state = @token.delimiter_state.with_heredoc_indent(indent)
            else
              @reader.pos = old_pos
              @column_number = old_column
              @token.column_number = @column_number
              next_string_token delimiter_state
              @token.value = (is_slash_r ? "\r\n" : '\n') + @token.value.to_s
            end
          else
            @reader.pos = old_pos
            @column_number = old_column
            @token.column_number = @column_number
            @token.type = :STRING
            @token.value = is_slash_r ? "\r\n" : "\n"
          end
        else
          @token.type = :STRING
          @token.value = is_slash_r ? "\r\n" : "\n"
        end
      else
        while current_char != string_end &&
              current_char != string_nest &&
              current_char != '\0' &&
              current_char != '\\' &&
              current_char != '#' &&
              current_char != '\r' &&
              current_char != '\n'
          next_char
        end

        @token.type = :STRING
        @token.value = string_range(start)
      end

      set_token_raw_from_start(start)

      @token
    end

    def raise_unterminated_quoted(string_end)
      msg = case string_end
            when '`'    then "unterminated command"
            when '/'    then "unterminated regular expression"
            when String then "unterminated heredoc"
            else             "unterminated string literal"
            end
      raise msg, @line_number, @column_number
    end

    def next_macro_token(macro_state, skip_whitespace)
      nest = macro_state.nest
      control_nest = macro_state.control_nest
      whitespace = macro_state.whitespace
      delimiter_state = macro_state.delimiter_state
      beginning_of_line = macro_state.beginning_of_line
      comment = macro_state.comment
      yields = false

      if skip_whitespace
        skip_macro_whitespace
      end

      @token.location = nil
      @token.line_number = @line_number
      @token.column_number = @column_number

      start = current_pos

      if current_char == '\0'
        @token.type = :EOF
        return @token
      end

      if current_char == '\\' && peek_next_char == '{'
        beginning_of_line = false
        next_char
        start = current_pos
        if next_char == '%'
          while (char = next_char).ascii_whitespace?
          end

          case char
          when 'e'
            if next_char == 'n' && next_char == 'd' && !ident_part_or_end?(peek_next_char)
              next_char
              nest -= 1
            end
          when 'f'
            if next_char == 'o' && next_char == 'r' && !ident_part_or_end?(peek_next_char)
              next_char
              nest += 1
            end
          when 'i'
            if next_char == 'f' && !ident_part_or_end?(peek_next_char)
              next_char
              nest += 1
            end
          end
        end

        @token.type = :MACRO_LITERAL
        @token.value = string_range(start)
        @token.macro_state = Token::MacroState.new(whitespace, nest, control_nest, delimiter_state, beginning_of_line, yields, comment)
        set_token_raw_from_start(start)
        return @token
      end

      if current_char == '\\' && peek_next_char == '%'
        beginning_of_line = false
        next_char
        next_char
        @token.type = :MACRO_LITERAL
        @token.value = "%"
        @token.macro_state = Token::MacroState.new(whitespace, nest, control_nest, delimiter_state, beginning_of_line, yields, comment)
        @token.raw = "%"
        return @token
      end

      if current_char == '{'
        case next_char
        when '{'
          beginning_of_line = false
          next_char
          @token.type = :MACRO_EXPRESSION_START
          @token.macro_state = Token::MacroState.new(whitespace, nest, control_nest, delimiter_state, beginning_of_line, yields, comment)
          return @token
        when '%'
          beginning_of_line = false
          next_char
          @token.type = :MACRO_CONTROL_START
          @token.macro_state = Token::MacroState.new(whitespace, nest, control_nest, delimiter_state, beginning_of_line, yields, comment)
          return @token
        else
          # Make sure to decrease the '}' count if inside an interpolation
          @macro_curly_count += 1 if @macro_curly_count > 0
        end
      end

      if comment || (!delimiter_state && current_char == '#')
        comment = true
        char = current_char
        char = next_char if current_char == '#'
        while true
          case char
          when '\n'
            comment = false
            beginning_of_line = true
            whitespace = true
            next_char
            incr_line_number
            @token.line_number = @line_number
            @token.column_number = @column_number
            break
          when '{'
            break
          when '\0'
            raise "unterminated macro"
          end
          char = next_char
        end
        @token.type = :MACRO_LITERAL
        @token.value = string_range(start)
        @token.macro_state = Token::MacroState.new(whitespace, nest, control_nest, delimiter_state, beginning_of_line, yields, comment)
        set_token_raw_from_start(start)
        return @token
      end

      if !delimiter_state && current_char == '%' && ident_start?(peek_next_char)
        char = next_char
        if char == 'q' && (peek = peek_next_char) && {'(', '<', '[', '{'}.includes?(peek)
          next_char
          delimiter_state = Token::DelimiterState.new(:string, char, closing_char, 1)
        else
          start = current_pos
          while ident_part?(char)
            char = next_char
          end
          beginning_of_line = false
          @token.type = :MACRO_VAR
          @token.value = string_range_from_pool(start)
          @token.macro_state = Token::MacroState.new(whitespace, nest, control_nest, delimiter_state, beginning_of_line, yields, comment)
          return @token
        end
      end

      if !delimiter_state && current_char == 'e' && next_char == 'n'
        beginning_of_line = false
        case next_char
        when 'd'
          if whitespace && !ident_part_or_end?(peek_next_char)
            if nest == 0 && control_nest == 0
              next_char
              @token.type = :MACRO_END
              @token.macro_state = Token::MacroState.default
              return @token
            else
              nest -= 1
              whitespace = current_char.ascii_whitespace?
              next_char
            end
          end
        when 'u'
          if !delimiter_state && whitespace && next_char == 'm' && !ident_part_or_end?(next_char)
            char = current_char
            nest += 1
            whitespace = true
          end
        end
      end

      char = current_char

      until char == '{' || char == '\0' || (char == '\\' && ((peek = peek_next_char) == '{' || peek == '%')) || (whitespace && !delimiter_state && char == 'e')
        case char
        when '\n'
          incr_line_number 0
          whitespace = true
          beginning_of_line = true
        when '\\'
          char = next_char
          if delimiter_state
            if char == '"'
              char = next_char
            end
            whitespace = false
          else
            whitespace = false
          end
          next
        when '\'', '"'
          if delimiter_state
            delimiter_state = nil if delimiter_state.end == char
          else
            delimiter_state = Token::DelimiterState.new(:string, char, char)
          end
          whitespace = false
        when '%'
          case char = peek_next_char
          when '(', '[', '<', '{'
            next_char
            delimiter_state = Token::DelimiterState.new(:string, char, closing_char, 1)
          else
            whitespace = false
            break if !delimiter_state && ident_start?(char)
          end
        when '#'
          if delimiter_state
            # If it's "#{..." we don't want "#{{{" to parse it as "# {{ {", but as "#{ {{"
            # (macro expression inside a string interpolation)
            if peek_next_char == '{'
              char = next_char

              # We should now consider things that follow as crystal expressions,
              # so we reset the delimiter state but save it in a stack
              @macro_curly_count += 1
              @delimiter_state_stack.push delimiter_state
              delimiter_state = nil
            end
            whitespace = false
          else
            break
          end
        when '}'
          if delimiter_state && delimiter_state.end == '}'
            delimiter_state = delimiter_state.with_open_count_delta(-1)
            if delimiter_state.open_count == 0
              delimiter_state = nil
            end
          elsif @macro_curly_count > 0
            # Once we find the final '}' that closes the interpolation,
            # we are back inside the delimiter
            if @macro_curly_count == 1
              delimiter_state = @delimiter_state_stack.pop
            end
            @macro_curly_count -= 1
          end
        else
          if !delimiter_state && whitespace && lookahead { char == 'y' && next_char == 'i' && next_char == 'e' && next_char == 'l' && next_char == 'd' && !ident_part_or_end?(peek_next_char) }
            yields = true
            char = current_char
            whitespace = true
            beginning_of_line = false
          elsif !delimiter_state && whitespace && (keyword = lookahead { check_macro_opening_keyword(beginning_of_line) })
            char = current_char

            nest += 1 unless keyword == :abstract_def
            whitespace = true
            beginning_of_line = false
            next
          else
            char = current_char

            if delimiter_state
              case char
              when delimiter_state.nest
                delimiter_state = delimiter_state.with_open_count_delta(+1)
              when delimiter_state.end
                delimiter_state = delimiter_state.with_open_count_delta(-1)
                if delimiter_state.open_count == 0
                  delimiter_state = nil
                end
              end
            end

            # If an assignment comes, we accept if/unless/while/until as nesting
            if char == '=' && peek_next_char.ascii_whitespace?
              whitespace = false
              beginning_of_line = true
            else
              whitespace = char.ascii_whitespace? || char == ';' || char == '(' || char == '[' || char == '{'
              if beginning_of_line && !whitespace
                beginning_of_line = false
              end
            end
          end
        end
        char = next_char
      end

      @token.type = :MACRO_LITERAL
      @token.value = string_range(start)
      @token.macro_state = Token::MacroState.new(whitespace, nest, control_nest, delimiter_state, beginning_of_line, yields, comment)
      set_token_raw_from_start(start)

      @token
    end

    def lookahead
      old_pos = @reader.pos
      old_line_number, old_column_number = @line_number, @column_number

      result = yield
      unless result
        @reader.pos = old_pos
        @line_number, @column_number = old_line_number, old_column_number
      end
      result
    end

    def skip_macro_whitespace
      start = current_pos
      while current_char.ascii_whitespace?
        whitespace = true
        if current_char == '\n'
          incr_line_number 0
          beginning_of_line = true
        end
        next_char
      end
      if @wants_raw
        string_range(start)
      else
        ""
      end
    end

    def check_macro_opening_keyword(beginning_of_line)
      case char = current_char
      when 'a'
        if next_char == 'b' && next_char == 's' && next_char == 't' && next_char == 'r' && next_char == 'a' && next_char == 'c' && next_char == 't' && next_char.whitespace?
          case next_char
          when 'd'
            next_char == 'e' && next_char == 'f' && peek_not_ident_part_or_end_next_char && :abstract_def
          when 'c'
            next_char == 'l' && next_char == 'a' && next_char == 's' && next_char == 's' && peek_not_ident_part_or_end_next_char && :abstract_class
          when 's'
            next_char == 't' && next_char == 'r' && next_char == 'u' && next_char == 'c' && next_char == 't' && peek_not_ident_part_or_end_next_char && :abstract_struct
          end
        end
      when 'b'
        next_char == 'e' && next_char == 'g' && next_char == 'i' && next_char == 'n' && peek_not_ident_part_or_end_next_char && :begin
      when 'c'
        (char = next_char) && (
          (char == 'a' && next_char == 's' && next_char == 'e' && peek_not_ident_part_or_end_next_char && :case) ||
            (char == 'l' && next_char == 'a' && next_char == 's' && next_char == 's' && peek_not_ident_part_or_end_next_char && :class)
        )
      when 'd'
        (char = next_char) &&
          ((char == 'o' && peek_not_ident_part_or_end_next_char && :do) ||
            (char == 'e' && next_char == 'f' && peek_not_ident_part_or_end_next_char && :def))
      when 'f'
        next_char == 'u' && next_char == 'n' && peek_not_ident_part_or_end_next_char && :fun
      when 'i'
        beginning_of_line && next_char == 'f' &&
          (char = next_char) && (!ident_part_or_end?(char) && :if)
      when 'l'
        next_char == 'i' && next_char == 'b' && peek_not_ident_part_or_end_next_char && :lib
      when 'm'
        (char = next_char) && (
          (char == 'a' && next_char == 'c' && next_char == 'r' && next_char == 'o' && peek_not_ident_part_or_end_next_char && :macro) ||
            (char == 'o' && next_char == 'd' && next_char == 'u' && next_char == 'l' && next_char == 'e' && peek_not_ident_part_or_end_next_char && :module)
        )
      when 's'
        next_char == 't' && next_char == 'r' && next_char == 'u' && next_char == 'c' && next_char == 't' && !ident_part_or_end?(peek_next_char) && next_char && :struct
      when 'u'
        next_char == 'n' && (char = next_char) && (
          (char == 'i' && next_char == 'o' && next_char == 'n' && peek_not_ident_part_or_end_next_char && :union) ||
            (beginning_of_line && char == 'l' && next_char == 'e' && next_char == 's' && next_char == 's' && peek_not_ident_part_or_end_next_char && :unless) ||
            (beginning_of_line && char == 't' && next_char == 'i' && next_char == 'l' && peek_not_ident_part_or_end_next_char && :until)
        )
      when 'w'
        beginning_of_line && next_char == 'h' && next_char == 'i' && next_char == 'l' && next_char == 'e' && peek_not_ident_part_or_end_next_char && :while
      else
        false
      end
    end

    def consume_octal_escape(char)
      value = char - '0'
      count = 1
      while count <= 3 && '0' <= peek_next_char < '8'
        next_char
        value = value * 8 + (current_char - '0')
        count += 1
      end
      if value >= 256
        raise "octal value too big"
      end
      value.to_u8
    end

    def consume_char_unicode_escape
      char = peek_next_char
      if char == '{'
        next_char
        consume_braced_unicode_escape
      else
        consume_non_braced_unicode_escape
      end
    end

    def consume_string_hex_escape
      char = next_char
      high = char.to_i?(16)
      raise "invalid hex escape" unless high

      char = next_char
      low = char.to_i?(16)
      raise "invalid hex escape" unless low

      ((high << 4) | low).to_u8
    end

    def consume_string_unicode_escape
      char = peek_next_char
      if char == '{'
        next_char
        consume_string_unicode_brace_escape
      else
        consume_non_braced_unicode_escape.chr.to_s
      end
    end

    def consume_string_unicode_brace_escape
      String.build do |str|
        while true
          str << consume_braced_unicode_escape(allow_spaces: true).chr
          break unless current_char == ' '
        end
      end
    end

    def consume_non_braced_unicode_escape
      codepoint = 0
      4.times do
        hex_value = char_to_hex(next_char) { expected_hexacimal_character_in_unicode_escape }
        codepoint = 16 * codepoint + hex_value
      end
      codepoint
    end

    def consume_braced_unicode_escape(allow_spaces = false)
      codepoint = 0
      found_curly = false
      found_space = false
      found_digit = false
      char = '\0'

      6.times do
        char = next_char
        case char
        when '}'
          found_curly = true
          break
        when ' '
          if allow_spaces
            found_space = true
            break
          else
            expected_hexacimal_character_in_unicode_escape
          end
        else
          hex_value = char_to_hex(char) { expected_hexacimal_character_in_unicode_escape }
          codepoint = 16 * codepoint + hex_value
          found_digit = true
        end
      end

      if !found_digit
        expected_hexacimal_character_in_unicode_escape
      elsif codepoint > 0x10FFFF
        raise "invalid unicode codepoint (too large)"
      end

      unless found_space
        unless found_curly
          char = next_char
        end

        unless char == '}'
          raise "expected '}' to close unicode escape"
        end
      end

      codepoint
    end

    def expected_hexacimal_character_in_unicode_escape
      raise "expected hexadecimal character in unicode escape"
    end

    def string_token_escape_value(value)
      next_char
      @token.type = :STRING
      @token.value = value
    end

    def delimited_pair(kind, string_nest, string_end, start, allow_escapes = true)
      next_char
      @token.type = :DELIMITER_START
      @token.delimiter_state = Token::DelimiterState.new(kind, string_nest, string_end, allow_escapes)
      set_token_raw_from_start(start)
    end

    def next_string_array_token
      while true
        if current_char == '\n'
          next_char
          incr_line_number 1
        elsif current_char.ascii_whitespace?
          next_char
        else
          break
        end
      end

      if current_char == @token.delimiter_state.end
        @token.raw = current_char.to_s if @wants_raw
        next_char
        @token.type = :STRING_ARRAY_END
        return @token
      end

      start = current_pos
      while !current_char.ascii_whitespace? && current_char != '\0' && current_char != @token.delimiter_state.end
        next_char
      end

      @token.type = :STRING
      @token.value = string_range(start)
      set_token_raw_from_start(start)

      @token
    end

    def char_to_hex(char)
      if '0' <= char <= '9'
        char - '0'
      elsif 'a' <= char <= 'f'
        10 + (char - 'a')
      elsif 'A' <= char <= 'F'
        10 + (char - 'A')
      else
        yield
      end
    end

    def consume_loc_pragma
      case current_char
      when '"'
        # skip '"'
        next_char_no_column_increment

        filename_pos = current_pos

        while true
          case current_char
          when '"'
            break
          when '\0'
            raise "unexpected end of file in loc pragma"
          else
            next_char_no_column_increment
          end
        end

        incr_column_number (current_pos - filename_pos) + 7 # == "#<loc:\"".size
        filename = string_range(filename_pos)

        # skip '"'
        next_char

        unless current_char == ','
          raise "expected ',' in loc pragma after filename"
        end
        next_char

        line_number = 0
        while true
          case current_char
          when '0'..'9'
            line_number = 10 * line_number + (current_char - '0').to_i
          when ','
            next_char
            break
          else
            raise "expected digit or ',' in loc pragma for line number"
          end
          next_char
        end

        column_number = 0
        while true
          case current_char
          when '0'..'9'
            column_number = 10 * column_number + (current_char - '0').to_i
          when '>'
            next_char
            break
          else
            raise "expected digit or '>' in loc pragma for column_number number"
          end
          next_char
        end

        @token.filename = @filename = filename
        @token.line_number = @line_number = line_number
        @token.column_number = @column_number = column_number
      when 'p'
        # skip 'p'
        next_char_no_column_increment

        case current_char
        when 'o'
          unless next_char_no_column_increment == 'p' &&
                 next_char_no_column_increment == '>'
            raise %(expected #<loc:push>, #<loc:pop> or #<loc:"...">)
          end

          # skip '>'
          next_char_no_column_increment

          incr_column_number 10 # == "#<loc:pop>".size

          pop_location
        when 'u'
          unless next_char_no_column_increment == 's' &&
                 next_char_no_column_increment == 'h' &&
                 next_char_no_column_increment == '>'
            raise %(expected #<loc:push>, #<loc:pop> or #<loc:"...">)
          end

          # skip '>'
          next_char_no_column_increment

          incr_column_number 11 # == "#<loc:push>".size

          @token.line_number = @line_number
          @token.column_number = @column_number
          push_location
        else
          raise %(expected #<loc:push>, #<loc:pop> or #<loc:"...">)
        end
      else
        raise %(expected #<loc:push>, #<loc:pop> or #<loc:"...">)
      end
    end

    def pop_location
      if @stacked
        @stacked = false
        @token.filename = @filename = @stacked_filename
        @token.line_number = @line_number = @stacked_line_number
        @token.column_number = @column_number = @stacked_column_number
      end
    end

    def push_location
      unless @stacked
        @stacked = true
        @stacked_filename, @stacked_line_number, @stacked_column_number = @filename, @line_number, @column_number
      end
    end

    def incr_column_number(d = 1)
      @column_number += d
      @stacked_column_number += d if @stacked
    end

    def incr_line_number(column_number = 1)
      @line_number += 1
      @column_number = column_number if column_number
      if @stacked
        @stacked_line_number += 1
        @stacked_column_number = column_number if column_number
      end
    end

    def next_char_no_column_increment
      char = @reader.next_char
      if error = @reader.error
        ::raise InvalidByteSequenceError.new("Unexpected byte 0x#{error.to_s(16)} at position #{@reader.pos}, malformed UTF-8")
      end
      char
    end

    def next_char
      incr_column_number
      next_char_no_column_increment
    end

    def next_char_check_line
      char = next_char_no_column_increment
      if char == '\n'
        incr_line_number
      else
        incr_column_number = 1
      end
      char
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
      @token.passed_backslash_newline = false
      @token.doc_buffer = nil unless @token.type == :SPACE || @token.type == :NEWLINE
      @token_end_location = nil
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
      @reader.string.byte_slice(start_pos, end_pos - start_pos)
    end

    def string_range_from_pool(start_pos)
      string_range_from_pool(start_pos, current_pos)
    end

    def string_range_from_pool(start_pos, end_pos)
      @string_pool.get slice_range(start_pos, end_pos)
    end

    def slice_range(start_pos)
      slice_range(start_pos, current_pos)
    end

    def slice_range(start_pos, end_pos)
      Slice.new(@reader.string.to_unsafe + start_pos, end_pos - start_pos)
    end

    def ident_start?(char)
      char.ascii_letter? || char == '_' || char.ord > 0x9F
    end

    def ident_part?(char)
      ident_start?(char) || char.ascii_number?
    end

    def ident_part_or_end?(char)
      ident_part?(char) || char == '?' || char == '!'
    end

    def peek_not_ident_part_or_end_next_char
      !ident_part_or_end?(peek_next_char) && next_char
    end

    def closing_char(char = current_char)
      case char
      when '<' then '>'
      when '(' then ')'
      when '[' then ']'
      when '{' then '}'
      else          char
      end
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

    def set_token_raw_from_start(start)
      @token.raw = string_range(start) if @wants_raw
    end

    def raise(message, line_number = @line_number, column_number = @column_number, filename = @filename)
      ::raise Crystal::SyntaxException.new(message, line_number, column_number, filename)
    end

    def raise(message, token : Token, size = nil)
      ::raise Crystal::SyntaxException.new(message, token.line_number, token.column_number, token.filename, size)
    end

    def raise(message, location : Location)
      raise message, location.line_number, location.column_number, location.filename
    end
  end
end
