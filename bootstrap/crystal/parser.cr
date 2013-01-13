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
      location = @token.location

      atomic = parse_question_colon

      while true
        atomic.location = location

        case @token.type
        when :SPACE
          next_token
        when :"="
          if atomic.is_a?(Call) && atomic.name == "[]"
            next_token_skip_space_or_newline

            atomic.name = "[]="
            atomic.name_length = 0
            atomic.args << parse_expression
          else
            break unless can_be_assigned?(atomic)

            # if atomic.is_a?(Ident)
            #   raise "can't reassign to constant"
            # end

            if atomic.is_a?(Call) && !@def_vars.last.includes?(atomic.name)
              raise "'#{@token.type}' before definition of '#{atomic.name}'"

              atomic = Var.new(atomic.name)
            end

            push_var atomic

            next_token_skip_space_or_newline

            value = parse_op_assign
            atomic = Assign.new(atomic, value)
          end
        else
          break
        end
      end

      atomic
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
          when #{operators}
            method = @token.type.to_s
            method_column_number = @token.column_number

            next_token_skip_space_or_newline
            right = parse_#{next_operator}
            left = Call.new left, method, [right], nil, method_column_number
          else
            return left
          end
        end
      end
    "end

    parse_operator :or, :and, ":\"||\""
    parse_operator :and, :equality, ":\"&&\""
    parse_operator :equality, :cmp, ":\"<\", :\"<=\", :\">\", :\">=\", :\"<=>\""
    parse_operator :cmp, :logical_or, ":\"==\", :\"!=\", :\"=~\", :\"===\""
    parse_operator :logical_or, :logical_and, ":\"|\", :\"^\""
    parse_operator :logical_and, :shift, ":\"&\""
    parse_operator :shift, :add_or_sub, ":\"<<\", :\">>\""

    def parse_add_or_sub
      location = @token.location

      left = parse_mul_or_div
      while true
        left.location = location
        case @token.type
        when :SPACE
          next_token
        when :"+", :"-"
          method = @token.type.to_s
          method_column_number = @token.column_number
          next_token_skip_space_or_newline
          right = parse_mul_or_div
          left = Call.new left, method, [right], nil, method_column_number
        when :INT, :LONG, :FLOAT, :DOUBLE
          type = case @token.type
                 when :INT then IntLiteral
                 when :LONG then LongLiteral
                 when :FLOAT then FloatLiteral
                 else DoubleLiteral
                 end
          case @token.value.to_s[0]
          when '+'
            left = Call.new left, @token.value.to_s[0].to_s, [type.new(@token.value.to_s)], nil, @token.column_number
            next_token_skip_space_or_newline
          when '-'
            left = Call.new left, @token.value.to_s[0].to_s, [type.new(@token.value.to_s[1, @token.value.to_s.length - 1])], nil, @token.column_number
            next_token_skip_space_or_newline
          else
            return left
          end
        else
          return left
        end
      end
    end

    parse_operator :mul_or_div, :pow, ":\"*\", :\"/\", :\"%\""
    parse_operator :pow, :atomic_with_method, ":\"**\""

    def parse_atomic_with_method
      parse_atomic
    end

    def parse_atomic
      column_number = @token.column_number
      case @token.type
      when :"("
        parse_parenthesized_expression
      when :"[]"
        next_token_skip_space
        ArrayLiteral.new []
      when :"["
        parse_array_literal
      when :"!"
        next_token_skip_space_or_newline
        Call.new parse_expression, "!@", [], nil, column_number
      when :IDENT
        case @token.value
        when :nil
          node_and_next_token NilLiteral.new
        when :true
          node_and_next_token BoolLiteral.new(true)
        when :false
          node_and_next_token BoolLiteral.new(false)
        else
          node_and_next_token Var.new(@token.value)
        end
      when :INT
        node_and_next_token IntLiteral.new(@token.value.to_s)
      when :LONG
        node_and_next_token LongLiteral.new(@token.value.to_s)
      when :FLOAT
        node_and_next_token FloatLiteral.new(@token.value.to_s)
      when :DOUBLE
        node_and_next_token DoubleLiteral.new(@token.value.to_s)
      when :CHAR
        node_and_next_token CharLiteral.new(@token.value.to_s)
      when :STRING, :STRING_START
        parse_string
      when :SYMBOL
        node_and_next_token SymbolLiteral.new(@token.value.to_s)
      else
        raise "unexpected token #{@token}"
      end
    end

    def parse_parenthesized_expression
      next_token_skip_space_or_newline
      exp = parse_expression

      check :")"
      next_token_skip_space

      raise "unexpected token: (" if @token.type == :"("
      exp
    end

    def parse_string
      if @token.type == :STRING
        node_and_next_token StringLiteral.new(@token.value.to_s)
      end
    end

    def parse_array_literal
      next_token_skip_space_or_newline
      exps = []
      while @token.type != :"]"
        exps << parse_expression
        skip_space_or_newline
        if @token.type == :","
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
      return true if @token.type == :"}" || @token.type == :"]"
      return false unless @token.type == :IDENT

      case @token.value
      when :do, :end, :else, :elsif, :when
        true
      else
        false
      end
    end

    def can_be_assigned?(node)
      node.is_a?(Var) ||
        # node.is_a?(InstanceVar) ||
        # node.is_a?(Ident) ||
        # node.is_a?(Global) ||
        (node.is_a?(Call) && node.obj.nil? && node.args.length == 0 && node.block.nil?)
    end

    def push_var(var : Var)
      @def_vars.last.add var.name.to_s
    end

    def push_var(node)
    end

    def check(token_types : Array)
      raise "expecting any of these tokens: #{token_types.join ", "} (not '#{@token.to_s}')" unless token_types.any? { |type| @token.type == type }
    end

    def check(token_type)
      raise "expecting token '#{token_type}', not '#{@token.to_s}'" unless token_type == @token.type
    end

    def check_token(value)
      raise "expecting token '#{value}', not '#{@token.to_s}'" unless @token.type == :TOKEN && @token.value == value
    end
  end
end
