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
      parse_op_assign
    end

    def parse_op_assign
      parse_question_colon
    end

    def parse_question_colon
      parse_range
    end

    def parse_range
      parse_or
    end

    macro self.parse_operator(name, next_operator, operators)"
      def parse_#{name}
        location = @token.location

        left = parse_#{next_operator}
        while true
          left.location = location

          case @token.type
          when :SPACE
            next_token
          when :TOKEN
            case @token.value
            when #{operators}
              method = @token.value
              method_column_number = @token.column_number

              next_token_skip_space_or_newline
              right = parse_#{next_operator}
              left = Call.new left, method, [right], nil, method_column_number
            else
              return left
            end
          else
            return left
          end
        end
      end
    "end

    # parse_operator :or, :and, "\"||\""
    # parse_operator :and, :equality, "\"&&\""
    # parse_operator :equality, :cmp, "\"<\", \"<=\", \">\", \">=\", \"<=>\""
    # parse_operator :cmp, :logical_or, "\"==\", \"!=\", \"=~\", \"===\""
    # parse_operator :logical_or, :logical_and, "\"|\", \"^\""
    # parse_operator :logical_and, :shift, "\"&\""
    # parse_operator :shift, :add_or_sub, "\"<<\", \">>\""

    # parse_operator :or, :add_or_sub, "\"||\""

    def parse_or
      right = parse_add_or_sub
      left = parse_add_or_sub
      Call.new left, right, nil, nil, nil
    end

    def parse_add_or_sub
      parse_atomic
    end

    def parse_atomic
      column_number = @token.column_number
      case @token.type
      when :TOKEN
        case @token.value
        when "[]"
          next_token_skip_space
          ArrayLiteral.new
        when "["
          parse_array_literal
        else
          raise "unexpected token #{@token}"
        end
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
      when :STRING, :STRING_START
        parse_string
      when :SYMBOL
        node_and_next_token SymbolLiteral.new(@token.value.to_s)
      else
        raise "unexpected token #{@token}"
      end
    end

    def parse_string
      if @token.type == :STRING
        node_and_next_token StringLiteral.new(@token.value.to_s)
      end
    end

    def parse_array_literal
      next_token_skip_space_or_newline
      exps = []
      while !@token.token?("]")
        exps << parse_expression
        skip_space_or_newline
        if @token.token?(",")
          next_token_skip_space_or_newline
        end
      end
      next_token_skip_space
      ArrayLiteral.new exps
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
