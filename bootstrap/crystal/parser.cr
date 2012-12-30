require "lexer"
require "ast"
require "set"

module Crystal
  class Parser < Lexer
    def self.parse(str, def_vars = [Set.new])
      new(str, def_vars).parse
    end

    def initialize(str, def_vars = [Set.new])
      super(str)
      @def_vars = def_vars
    end

    def parse
      next_token_skip_statement_end

      expressions = parse_expressions

      check :EOF

      expressions
    end

    def parse_expressions
      exps = []
      while @token.type != :EOF && !is_end_token
        exps << parse_expression
        skip_statement_end
      end
      Expressions.from exps
    end

    def parse_expression
      parse_atomic
    end

    def parse_atomic
      column_number = @token.column_number
      case @token.type
      when :IDENT
        case @token.value
        when "nil"
          node_and_next_token NilLiteral.new
        when "true"
          node_and_next_token BoolLiteral.new(true)
        when "false"
          node_and_next_token BoolLiteral.new(false)
        else
          raise "unexpected token #{@token}"
        end
      when :INT
        node_and_next_token IntLiteral.new(@token.value.to_s)
      when :LONG
        node_and_next_token LongLiteral.new(@token.value.to_s)
      when :FLOAT
        node_and_next_token FloatLiteral.new(@token.value.to_s)
      when :CHAR
        node_and_next_token CharLiteral.new(@token.value.to_i)
      else
        raise "unexpected token #{@token}"
      end
    end

    def node_and_next_token(node)
      next_token
      node
    end

    def is_end_token
      return true if @token.type == :TOKEN && (@token.value == "}" || @token.value == "]")
      return false unless @token.type == :IDENT

      case @token.value
      when "do", "end", "else", "elsif", "when"
        true
      else
        false
      end
    end

    def check(token_types : Array)
      raise "expecting any of these tokens: #{token_types.join ", "} (not '#{@token.to_s}')" unless token_types.any? { |type| @token.type == type }
    end

    def check(token_type)
      raise "expecting token '#{token_type}', not '#{@token.to_s}'" unless token_type == @token.type
    end
  end
end
