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
        when :TOKEN
          break
          # case @token.value
          # when "="
          #   if is_hash_indexer?(atomic)
          #     next_token_skip_space_or_newline

          #     make_hash_setter(atomic)
          #   else
          #     break unless can_be_assigned?(atomic)

          #     check_dynamic_constant_assignment(atomic)

          #     atomic = make_var_from_call(atomic)
          #     push_var atomic

          #     next_token_skip_space_or_newline

          #     value = parse_op_assign
          #     atomic = Assign.new(atomic, value)
          #   end
          # else
            # break
          # end
        # else
        #   break
        end
      end

      atomic
    end

    def is_hash_indexer?(node : Call)
      node.name == "[]"
    end

    def is_hash_indexer?(node)
      false
    end

    # def check_dynamic_constant_assignment(atomic : Ident)
    #   raise "dynamic constant assignment" if @def_vars.length > 1
    # end

    def check_dynamic_constant_assignment(atomic)
    end

    def make_hash_setter(node : Call)
      node.name = "[]="
      node.name_length = 0
      node.args << parse_expression
    end

    def make_hash_setter(node)
      nil
    end

    def make_var_from_call(node : Call)
      Var.new(node.name)
    end

    def make_var_from_call(node)
      node
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

    parse_operator :or, :and, "\"||\""
    parse_operator :and, :equality, "\"&&\""
    parse_operator :equality, :cmp, "\"<\", \"<=\", \">\", \">=\", \"<=>\""
    parse_operator :cmp, :logical_or, "\"==\", \"!=\", \"=~\", \"===\""
    parse_operator :logical_or, :logical_and, "\"|\", \"^\""
    parse_operator :logical_and, :shift, "\"&\""
    parse_operator :shift, :add_or_sub, "\"<<\", \">>\""

    # def parse_or
    #   right = parse_add_or_sub
    #   left = parse_add_or_sub
    #   Call.new left, right, nil, nil, nil
    # end

    def parse_add_or_sub
      location = @token.location

      left = parse_mul_or_div
      while true
        left.location = location
        case @token.type
        when :SPACE
          next_token
        when :TOKEN
          case @token.value
          when "+", "-"
            method = @token.value
            method_column_number = @token.column_number
            next_token_skip_space_or_newline
            right = parse_mul_or_div
            left = Call.new left, method, [right], nil, method_column_number
          else
            return left
          end
        when :INT
          case @token.value.to_s[0]
          when '+'
            left = Call.new left, @token.value.to_s[0].to_s, [IntLiteral.new(@token.value.to_s)], nil, @token.column_number
            next_token_skip_space_or_newline
          when '-'
            left = Call.new left, @token.value.to_s[0].to_s, [IntLiteral.new(@token.value.to_s[1, @token.value.to_s.length - 1])], nil, @token.column_number
            next_token_skip_space_or_newline
          else
            return left
          end
        when :LONG
          case @token.value.to_s[0]
          when '+'
            left = Call.new left, @token.value.to_s[0].to_s, [LongLiteral.new(@token.value.to_s)], nil, @token.column_number
            next_token_skip_space_or_newline
          when '-'
            left = Call.new left, @token.value.to_s[0].to_s, [LongLiteral.new(@token.value.to_s[1, @token.value.to_s.length - 1])], nil, @token.column_number
            next_token_skip_space_or_newline
          else
            return left
          end
        when :FLOAT
          case @token.value.to_s[0]
          when '+'
            left = Call.new left, @token.value.to_s[0].to_s, [FloatLiteral.new(@token.value.to_s)], nil, @token.column_number
            next_token_skip_space_or_newline
          when '-'
            left = Call.new left, @token.value.to_s[0].to_s, [FloatLiteral.new(@token.value.to_s[1, @token.value.to_s.length - 1])], nil, @token.column_number
            next_token_skip_space_or_newline
          else
            return left
          end
        else
          return left
        end
      end
    end

    parse_operator :mul_or_div, :pow, "\"*\", \"/\", \"%\""
    parse_operator :pow, :atomic_with_method, "\"**\""

    def parse_atomic_with_method
      parse_atomic
    end

    def parse_atomic
      column_number = @token.column_number
      case @token.type
      when :TOKEN
        case @token.value
        when "("
          parse_parenthesized_expression
        when "[]"
          next_token_skip_space
          ArrayLiteral.new
        when "["
          parse_array_literal
        when "!"
          next_token_skip_space_or_newline
          Call.new parse_expression, "!@", [], nil, column_number
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

    def parse_parenthesized_expression
      next_token_skip_space_or_newline
      exp = parse_expression

      check_token ")"
      next_token_skip_space

      raise "unexpected token: (" if @token.token?("(")
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

    def can_be_assigned?(node : Var)
      true
    end

    # def can_be_assigned?(node : InstanceVar)
    #   true
    # end

    # def can_be_assigned?(node : Ident)
    #   true
    # end

    # def can_be_assigned?(node : Global)
    #   true
    # end

    def can_be_assigned?(node : Call)
      node.obj.nil? && node.args.length == 0 && node.block.nil?
    end

    def can_be_assigned?(node)
      false
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
