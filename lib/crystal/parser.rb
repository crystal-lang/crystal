module Crystal
  class Parser < Lexer
    def self.parse(str)
      new(str).parse
    end

    def initialize(str)
      super
      next_token_skip_statement_end
    end

    def parse
      parse_expressions
    end

    def parse_expressions
      exps = []
      while @token.type != :EOF && !is_end_token
        exps << parse_expression
        skip_statement_end
      end
      Expressions.new exps
    end

    def parse_expression
      parse_primary_expression
    end

    def parse_primary_expression
      parse_modified_expression
    end

    def parse_modified_expression
      line_number = @token.line_number

      atomic = parse_op_assign

      while true
        atomic.line_number = line_number

        case @token.type
        when :SPACE
          next_token
        when :IDENT
          case @token.value
          when :if
            next_token_skip_statement_end
            exp = parse_op_assign
            atomic = If.new(exp, atomic)
          when :unless
            next_token_skip_statement_end
            exp = parse_op_assign
            atomic = If.new(exp, nil, atomic)
          when :while
            next_token_skip_statement_end
            exp = parse_op_assign
            atomic = While.new(exp, atomic)
          else
            break
          end
        else
          break
        end
      end

      atomic
    end

    def parse_op_assign
      line_number = @token.line_number

      atomic = parse_question_colon

      while true
        atomic.line_number = line_number

        case @token.type
        when :SPACE
          next_token
        when :'='
          if atomic.is_a?(Call) && atomic.name == :'[ ]'
            next_token_skip_space_or_newline

            atomic.name = :'[]='
            atomic.args << parse_expression
          else
            break unless atomic.is_a?(Ref)

            next_token_skip_space_or_newline

            value = parse_question_colon
            atomic = Assign.new(atomic, value)
          end
        when :'+=', :'-=', :'*=', :'/=', :'%=', :'|=', :'&=', :'^=', :'**=', :'<<=', :'>>='
          break unless atomic.is_a?(Ref)

          method = @token.type.to_s[0 .. -2].to_sym

          next_token_skip_space_or_newline

          value = parse_question_colon
          atomic = Assign.new(atomic, Call.new(atomic, method, [value]))
        else
          break
        end
      end

      atomic
    end

    def parse_question_colon
      cond = parse_or
      while @token.type == :'?'
        next_token_skip_space_or_newline
        true_val = parse_or
        check :':'
        next_token_skip_space_or_newline
        false_val = parse_or
        cond = If.new(cond, true_val, false_val)
      end
      cond
    end

    def self.parse_custom_operator(name, next_operator, node, *operators)
      class_eval %Q(
        def parse_#{name}
          line_number = @token.line_number

          left = parse_#{next_operator}
          while true
            left.line_number = line_number

            case @token.type
            when :SPACE
              next_token
            when #{operators.map{|x| ':"' + x.to_s + '"'}.join ', '}
              method = @token.type

              next_token_skip_space_or_newline
              right = parse_#{next_operator}
              left = #{node}
            else
              return left
            end
          end
        end
      )
    end

    def self.parse_operator(name, next_operator, *operators)
      parse_custom_operator name, next_operator, "Call.new left, method, [right]", *operators
    end

    parse_custom_operator :or, :and, "Or.new left, right", :"||"
    parse_custom_operator :and, :equality, "And.new left, right", :"&&"
    parse_operator :equality, :cmp, :<, :<=, :>, :>=
    parse_operator :cmp, :logical_or, :==, :"!="
    parse_operator :logical_or, :logical_and, :|, :^
    parse_operator :logical_and, :shift, :&
    parse_operator :shift, :add_or_sub, :<<, :>>

    def parse_add_or_sub
      line_number = @token.line_number

      left = parse_mul_or_div
      while true
        left.line_number = line_number
        case @token.type
        when :SPACE
          next_token
        when :+, :-
          method = @token.type
          next_token_skip_space_or_newline
          right = parse_mul_or_div
          left = Call.new left, method, [right]
        when :INT
          case @token.value[0]
          when '+', '-'
            left = Call.new left, @token.value[0].to_sym, [Int.new(@token.value)]
            next_token_skip_space_or_newline
          else
            return left
          end
        else
          return left
        end
      end
    end

    parse_operator :mul_or_div, :pow, :*, :/, :%
    parse_operator :pow, :atomic_with_method, :**

    def parse_atomic_with_method
      line_number = @token.line_number

      atomic = parse_atomic

      while true
        atomic.line_number = line_number

        case @token.type
        when :SPACE
          next_token
        when :'.'
          next_token_skip_space_or_newline
          check :IDENT, :+, :-, :*, :/, :%, :|, :&, :^, :**, :<<, :<, :<=, :==, :"!=", :>>, :>, :>=
          name = @token.type == :IDENT ? @token.value : @token.type
          next_token

          args = parse_args
          block = parse_block
          if block
            atomic = Call.new atomic, name, args, block
          else
            atomic = args ? (Call.new atomic, name, args) : (Call.new atomic, name)
          end
        when :[]
          next_token_skip_space
          atomic = Call.new atomic, :[]
        when :'['
          next_token_skip_space_or_newline
          args = []
          while true
            args << parse_expression
            case @token.type
            when :','
              next_token_skip_space_or_newline
              if @token.type == :']'
                next_token_skip_space
                break
              end
            when :']'
              next_token_skip_space
              break
            end
          end
          atomic = Call.new atomic, :'[ ]', args
        else
          break
        end
      end

      atomic
    end

    def parse_atomic
      case @token.type
      when :'('
        next_token_skip_space_or_newline
        exp = parse_expression
        check :')'
        next_token_skip_statement_end
        exp
      when :"!"
        next_token_skip_space_or_newline
        Not.new parse_expression
      when :+
        next_token_skip_space_or_newline
        Call.new parse_expression, :+@
      when :-
        next_token_skip_space_or_newline
        Call.new parse_expression, :-@
      when :~
        next_token_skip_space_or_newline
        Call.new parse_expression, :'~@'
      when :INT
        node_and_next_token Int.new(@token.value)
      when :FLOAT
        node_and_next_token Float.new(@token.value)
      when :CHAR
        node_and_next_token Char.new(@token.value)
      when :IDENT
        case @token.value
        when :begin
          parse_begin
        when :nil
          node_and_next_token Nil.new
        when :false
          node_and_next_token Bool.new(false)
        when :true
          node_and_next_token Bool.new(true)
        when :yield
          parse_yield
        when :class
          parse_class
        when :def
          parse_def
        when :if
          parse_if
        when :unless
          parse_unless
        when :while
          parse_while
        when :return
          parse_return
        when :next
          parse_next
        when :break
          parse_break
        else
          parse_ref_or_call
        end
      else
        raise_error "unexpected token: #{@token.to_s}"
      end
    end

    def parse_begin
      next_token_skip_statement_end
      exps = parse_expressions
      check_ident :end
      next_token_skip_statement_end
      exps
    end

    def parse_ref_or_call
      name = @token.value
      next_token

      args = parse_args

      block = parse_block

      if block
        Call.new nil, name, args, block
      else
        args ? Call.new(nil, name, args) : Ref.new(name)
      end
    end

    def parse_block
      if @token.type == :IDENT && @token.value == :do
        parse_block2 { check_ident :end }
      elsif @token.type == :'{'
        parse_block2 { check :'}' }
      end
    end

    def parse_block2
      block_args = []
      block_body = nil

      next_token_skip_space
      if @token.type == :|
        next_token_skip_space_or_newline
        while @token.type != :|
          check :IDENT
          block_args << Var.new(@token.value)
          next_token_skip_space_or_newline
          if @token.type == :','
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_statement_end
        block_body = parse_expressions
      else
        skip_statement_end
        block_body = parse_expressions
      end

      yield
      next_token_skip_statement_end

      Block.new(block_args, block_body)
    end

    def parse_yield
      next_token

      Yield.new parse_args
    end

    def parse_args
      case @token.type
      when :'{'
        nil
      when :"("
        args = []
        next_token_skip_space
        while @token.type != :")"
          args << parse_expression
          skip_space
          if @token.type == :","
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_space
        args
      when :SPACE
        next_token
        case @token.type
        when :CHAR, :INT, :FLOAT, :IDENT, :'(', :'!'
          case @token.value
          when :if, :unless, :while
            nil
          else
            args = []
            while @token.type != :NEWLINE && @token.type != :";" && @token.type != :EOF && @token.type != :')' && @token.type != :':' && !is_end_token
              args << parse_op_assign
              skip_space
              if @token.type == :","
                next_token_skip_space_or_newline
              else
                break
              end
            end
            args
          end
        else
          nil
        end
      else
        nil
      end
    end

    def parse_class
      line_number = @token.line_number

      next_token_skip_space_or_newline
      check :IDENT

      name = @token.value
      next_token_skip_space

      superclass = nil

      if @token.type == :<
        next_token_skip_space_or_newline
        check :IDENT
        superclass = @token.value
        next_token
      end
      skip_statement_end

      body = parse_expressions

      check_ident :end
      next_token_skip_statement_end

      class_def = ClassDef.new name, body, superclass
      class_def.line_number = line_number
      class_def
    end

    def parse_def
      next_token_skip_space_or_newline
      check :IDENT, :"=", :<<, :<, :<=, :==, :"!=", :>>, :>, :>=, :+, :-, :*, :/, :%, :+@, :-@, :'~@', :&, :|, :^, :**, :[]

      receiver = nil
      name = @token.type == :IDENT ? @token.value : @token.type
      args = []

      next_token_skip_space

      if @token.type == :'.'
        receiver = Ref.new name
        next_token_skip_space
        check :IDENT, :"=", :<<, :<, :<=, :==, :"!=", :>>, :>, :>=, :+, :-, :*, :/, :%, :+@, :-@, :'~@', :&, :|, :^, :**, :[]
        name = @token.type == :IDENT ? @token.value : @token.type
        next_token_skip_space
      end

      case @token.type
      when :'('
        next_token_skip_space_or_newline
        while @token.type != :')'
          check_ident
          args << Var.new(@token.value)
          next_token_skip_space_or_newline
          if @token.type == :','
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_statement_end
      when :IDENT
        while @token.type != :NEWLINE && @token.type != :";"
          check_ident
          args << Var.new(@token.value)
          next_token_skip_space
          if @token.type == :','
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_statement_end
      else
        skip_statement_end
      end

      if @token.type == :IDENT && @token.value == :end
        body = nil
      else
        body = parse_expressions
        skip_statement_end
        check_ident :end
      end

      next_token_skip_statement_end

      name = :'[ ]' if name == :[] && args && args.length > 0

      Def.new name, args, body, receiver
    end

    def parse_if(check_end = true)
      line_number = @token.line_number

      next_token_skip_space_or_newline

      cond = parse_expression
      skip_statement_end

      a_then = parse_expressions
      skip_statement_end

      a_else = nil
      if @token.type == :IDENT
        case @token.value
        when :else
          next_token_skip_statement_end
          a_else = parse_expressions
        when :elsif
          a_else = parse_if false
        end
      end

      if check_end
        check_ident :end
        next_token_skip_space
      end

      node = If.new cond, a_then, a_else
      node.line_number = line_number
      node
    end

    def parse_unless
      line_number = @token.line_number

      next_token_skip_space_or_newline

      cond = parse_expression
      skip_statement_end

      a_then = parse_expressions
      skip_statement_end

      a_else = nil
      if @token.type == :IDENT && @token.value == :else
        next_token_skip_statement_end
        a_else = parse_expressions
      end

      check_ident :end
      next_token_skip_statement_end

      node = If.new cond, a_else, a_then
      node.line_number = line_number
      node
    end

    def parse_while
      line_number = @token.line_number

      next_token_skip_space_or_newline

      cond = parse_expression
      skip_statement_end

      body = parse_expressions
      skip_statement_end

      check_ident :end
      next_token_skip_statement_end

      node = While.new cond, body
      node.line_number = line_number
      node
    end

    ['return', 'next', 'break'].each do |keyword|
      class_eval %Q(
        def parse_#{keyword}
          line_number = @token.line_number

          next_token_skip_space

          node = if @token.type == :EOF || @token.type == :NEWLINE || @token.type == :';' || @token.type == :'}' || @token.value == :if || @token.value == :unless || @token.value == :while || @token.value == :until
                   #{keyword.capitalize}.new
                 else
                   #{keyword.capitalize}.new parse_op_assign
                 end
          node.line_number = line_number
          node
        end
      )
    end

    def node_and_next_token(node)
      next_token
      node
    end

    private

    def check(*token_types)
      raise_error "expecting token #{token_types}" unless token_types.any?{|type| @token.type == type}
    end

    def check_ident(value = nil)
      if value
        raise_error "expecting token: #{value}" unless @token.type == :IDENT && @token.value == value
      else
        raise_error "unexpected token: #{@token.to_s}" unless @token.type == :IDENT && @token.value.is_a?(String)
      end
    end

    def is_end_token
      return true if @token.type == :'}' || @token.type == :']'
      return false unless @token.type == :IDENT

      case @token.value
      when :do, :end, :else, :elsif
        true
      else
        false
      end
    end
  end
end
