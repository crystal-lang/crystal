require 'strscan'

module Crystal
  class Lexer < StringScanner
    def initialize(str)
      super
      @token = Token.new
      @line_number = 1
    end

    def next_token
      @token.value = nil
      @token.line_number = @line_number

      if @incremented_columns
        @token.column_number += @incremented_columns
      else
        @token.column_number = 1
      end

      if eos?
        @token.type = :EOF
      elsif scan /\n/
        @token.type = :NEWLINE
        @line_number += 1
        @incremented_columns = nil
      elsif scan /[^\S\n]+/
        @token.type = :SPACE
      elsif scan /;+/
        @token.type = :";"
      elsif match = scan(/(\+|-)?\d+\.\d+/)
        @token.type = :FLOAT
        @token.value = match
      elsif match = scan(/(\+|-)?\d+/)
        if scan(/L/)
          @token.type = :LONG
          @token.value = match
        else
          @token.type = :INT
          @token.value = match
        end
      elsif match = scan(/'\\n'/)
        @token.type = :CHAR
        @token.value = ?\n.ord
      elsif match = scan(/'\\t'/)
        @token.type = :CHAR
        @token.value = ?\t.ord
      elsif match = scan(/'\\0'/)
        @token.type = :CHAR
        @token.value = ?\0.ord
      elsif match = scan(/'.'/)
        @token.type = :CHAR
        @token.value = match[1 .. -2].ord
      elsif match = scan(/".*?"/)
        @token.type = :STRING
        @token.value = match[1 .. -2]
      elsif match = scan(/:[a-zA-Z_][a-zA-Z_0-9]*/)
        @token.type = :SYMBOL
        @token.value = match[1 .. -1]
      elsif match = scan(%r(!=|!|==|=|<<=|<<|<=|<|>>=|>>|>=|>|\+@|\+=|\+|-@|-=|-|\*=|\*\*=|\*\*|\*|/=|%=|&=|\|=|\^=|/|\(|\)|,|\.|&&|&|\|\||\||\{|\}|\?|:|%|\^|~@|~|\[\]\=|\[\]|\[|\]))
        @token.type = match.to_sym
      elsif match = scan(/(def|do|elsif|else|end|if|true|false|class|while|nil|yield|return|unless|next|break|begin|lib|fun)((\?|!)|\b)/)
        @token.type = :IDENT
        @token.value = match.end_with?('?') || match.end_with?('!') ? match : match.to_sym
      elsif match = scan(/[A-Z][a-zA-Z_0-9]*/)
        @token.type = :CONST
        @token.value = match
      elsif match = scan(/[a-zA-Z_][a-zA-Z_0-9]*(\?|!)?/)
        @token.type = :IDENT
        @token.value = match
      elsif match = scan(/@[a-zA-Z_][a-zA-Z_0-9]*/)
        @token.type = :INSTANCE_VAR
        @token.value = match
      elsif scan /#/
        if scan /.*\n/
          @token.type = :NEWLINE
          @line_number += 1
          @incremented_columns = nil
        else
          scan /.*/
          @token.type = :EOF
        end
      else
        raise "unknown token: #{rest}"
      end

      @token
    end

    def scan(regex)
      if (match = super)
        @incremented_columns = match.length
      end
      match
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

    def raise(message)
      Kernel::raise Crystal::SyntaxException.new(message, @line_number, @token.column_number)
    end
  end
end
