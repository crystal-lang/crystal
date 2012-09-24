require 'set'

module Crystal
  class Parser < Lexer
    def self.parse(str)
      new(str).parse
    end

    def initialize(str)
      super
      @def_vars = []
      @def_vars.push Set.new
      next_token_skip_statement_end
    end

    def parse
      exps = parse_expressions
      exps.source_code = string
      exps
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
      location = @token.location

      atomic = parse_op_assign

      while true
        atomic.location = location

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
      location = @token.location

      atomic = parse_question_colon

      while true
        atomic.location = location

        case @token.type
        when :SPACE
          next_token
        when :'='
          if atomic.is_a?(Call) && atomic.name == :'[ ]'
            next_token_skip_space_or_newline

            atomic.name = :'[]='
            atomic.args << parse_expression
          else
            break unless can_be_assigned?(atomic)

            atomic = Var.new(atomic.name) if atomic.is_a?(Call)
            push_var atomic

            next_token_skip_space_or_newline

            value = parse_op_assign
            atomic = Assign.new(atomic, value)
          end
        when :'+=', :'-=', :'*=', :'/=', :'%=', :'|=', :'&=', :'^=', :'**=', :'<<=', :'>>='
          break unless can_be_assigned?(atomic)

          # Rewrite 'a += b' as 'a = a + b'

          atomic = Var.new(atomic.name) if atomic.is_a?(Call)
          push_var atomic

          method = @token.type.to_s[0 .. -2].to_sym
          method_column_number = @token.column_number

          next_token_skip_space_or_newline

          value = parse_op_assign
          atomic = Assign.new(atomic, Call.new(atomic, method, [value], nil, method_column_number))
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

    def self.parse_operator(name, next_operator, *operators)
      class_eval %Q(
        def parse_#{name}
          location = @token.location

          left = parse_#{next_operator}
          while true
            left.location = location

            case @token.type
            when :SPACE
              next_token
            when #{operators.map{|x| ':"' + x.to_s + '"'}.join ', '}
              method = @token.type
              method_column_number = @token.column_number

              next_token_skip_space_or_newline
              right = parse_#{next_operator}
              left = Call.new left, method, [right], nil, method_column_number
            else
              return left
            end
          end
        end
      )
    end

    parse_operator :or, :and, :'||'
    parse_operator :and, :equality, :'&&'
    parse_operator :equality, :cmp, :<, :<=, :>, :>=
    parse_operator :cmp, :logical_or, :==, :"!="
    parse_operator :logical_or, :logical_and, :|, :^
    parse_operator :logical_and, :shift, :&
    parse_operator :shift, :add_or_sub, :<<, :>>

    def parse_add_or_sub
      location = @token.location

      left = parse_mul_or_div
      while true
        left.location = location
        case @token.type
        when :SPACE
          next_token
        when :+, :-
          method = @token.type
          method_column_number = @token.column_number
          next_token_skip_space_or_newline
          right = parse_mul_or_div
          left = Call.new left, method, [right], nil, method_column_number
        when :INT
          case @token.value[0]
          when '+'
            left = Call.new left, @token.value[0].to_sym, [Int.new(@token.value)], nil, @token.column_number
            next_token_skip_space_or_newline
          when '-'
            left = Call.new left, @token.value[0].to_sym, [Int.new(@token.value[1 .. -1])], nil, @token.column_number
            next_token_skip_space_or_newline
          else
            return left
          end
        when :FLOAT
          case @token.value[0]
          when '+'
            left = Call.new left, @token.value[0].to_sym, [Float.new(@token.value)], nil, @token.column_number
            next_token_skip_space_or_newline
          when '-'
            left = Call.new left, @token.value[0].to_sym, [Float.new(@token.value[1 .. -1])], nil, @token.column_number
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
      location = @token.location

      atomic = parse_atomic

      while true
        atomic.location = location

        case @token.type
        when :SPACE
          next_token
        when :'.'
          next_token_skip_space_or_newline
          check :IDENT, :+, :-, :*, :/, :%, :|, :&, :^, :**, :<<, :<, :<=, :==, :"!=", :>>, :>, :>=
          name = @token.type == :IDENT ? @token.value : @token.type
          name_column_number = @token.column_number
          next_token

          if @token.type == :SPACE
            next_token
            case @token.type
            when :'='
              # Rewrite 'f.x = args' as f.x=(args)
              next_token_skip_space_or_newline
              args = parse_args_space_consumed
              atomic = Call.new(atomic, "#{name}=", args)
              next
            when :'+=', :'-=', :'*=', :'/=', :'%=', :'|=', :'&=', :'^=', :'**=', :'<<=', :'>>='
              # Rewrite 'f.x += value' as 'f.x=(f.x + value)'
              method = @token.type.to_s[0 .. -2].to_sym
              next_token_skip_space
              value = parse_expression
              atomic = Call.new(atomic, "#{name}=", [Call.new(Call.new(atomic, name), method, [value])])
              next
            else
              args = parse_args_space_consumed
            end
          else
            args = parse_args
          end

          block = parse_block
          if block
            atomic = Call.new atomic, name, args, block, name_column_number
          else
            atomic = args ? (Call.new atomic, name, args, nil, name_column_number) : (Call.new atomic, name, [], nil, name_column_number)
          end
        when :[]
          column_number = @token.column_number
          next_token_skip_space
          atomic = Call.new atomic, :[], [], nil, column_number
        when :'['
          column_number = @token.column_number
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
          atomic = Call.new atomic, :'[ ]', args, nil, column_number
        else
          break
        end
      end

      atomic
    end

    def parse_atomic
      column_number = @token.column_number
      case @token.type
      when :'('
        next_token_skip_space_or_newline
        exp = parse_expression
        check :')'
        next_token_skip_statement_end
        raise_error "unexpected token: (" if @token.type == :'('
        exp
      when :'[]'
        next_token_skip_space
        Crystal::Array.new
      when :'['
        next_token_skip_space_or_newline
        exps = []
        while @token.type != :"]"
          exps << parse_expression
          skip_space
          if @token.type == :","
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_space
        Crystal::Array.new exps
      when :'!'
        next_token_skip_space_or_newline
        Call.new parse_expression, :'!@', [], nil, column_number
      when :+
        next_token_skip_space_or_newline
        Call.new parse_expression, :+@, [], nil, column_number
      when :-
        next_token_skip_space_or_newline
        Call.new parse_expression, :-@, [], nil, column_number
      when :~
        next_token_skip_space_or_newline
        Call.new parse_expression, :'~@', [], nil, column_number
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
          parse_var_or_call
        end
      when :CONST
        node_and_next_token Const.new(@token.value)
      when :INSTANCE_VAR
        node_and_next_token InstanceVar.new(@token.value)
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

    def parse_var_or_call
      name = @token.value
      name_column_number = @token.column_number
      next_token

      args = parse_args

      block = parse_block

      if block
        Call.new nil, name, args, block, name_column_number, @last_call_has_parenthesis
      else
        if args
          if is_var?(name) && args.length == 1 && (args[0].is_a?(Int) || args[0].is_a?(Float)) && args[0].has_sign
            if args[0].value < 0
              args[0].value = args[0].value.abs
              Call.new(Var.new(name), :-, args)
            else
              Call.new(Var.new(name), :+, args)
            end
          else
            Call.new(nil, name, args, nil, name_column_number, @last_call_has_parenthesis)
          end
        elsif is_var? name
          Var.new name
        else
          Call.new nil, name, [], nil, name_column_number, @last_call_has_parenthesis
        end
      end
    end

    def parse_block
      if @token.keyword?(:do)
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
      else
        skip_statement_end
      end

      push_var *block_args

      block_body = parse_expressions

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
        @last_call_has_parenthesis = true
        args
      when :SPACE
        next_token
        parse_args_space_consumed
      else
        nil
      end
    end

    def parse_args_space_consumed
      case @token.type
      when :CHAR, :INT, :FLOAT, :IDENT, :CONST, :'(', :'!'
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
    end

    def parse_class
      location = @token.location

      next_token_skip_space_or_newline
      check :CONST

      name = @token.value
      next_token_skip_space

      superclass = nil

      if @token.type == :<
        next_token_skip_space_or_newline
        check :CONST
        superclass = @token.value
        next_token
      end
      skip_statement_end

      body = parse_expressions

      check_ident :end
      next_token_skip_statement_end

      class_def = ClassDef.new name, body, superclass
      class_def.location = location
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
        receiver = Var.new name
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

      if @token.keyword?(:end)
        body = nil
      else
        body = push_def(args) { parse_expressions }
        skip_statement_end
        check_ident :end
      end

      next_token_skip_statement_end

      name = :'[ ]' if name == :[] && args && args.length > 0

      Def.new name, args, body, receiver
    end

    def parse_if(check_end = true)
      location = @token.location

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
      node.location = location
      node
    end

    def parse_unless
      location = @token.location

      next_token_skip_space_or_newline

      cond = parse_expression
      skip_statement_end

      a_then = parse_expressions
      skip_statement_end

      a_else = nil
      if @token.keyword?(:else)
        next_token_skip_statement_end
        a_else = parse_expressions
      end

      check_ident :end
      next_token_skip_statement_end

      node = If.new cond, a_else, a_then
      node.location = location
      node
    end

    def parse_while
      location = @token.location

      next_token_skip_space_or_newline

      cond = parse_expression
      skip_statement_end

      body = parse_expressions
      skip_statement_end

      check_ident :end
      next_token_skip_statement_end

      node = While.new cond, body
      node.location = location
      node
    end

    ['return', 'next', 'break', 'yield'].each do |keyword|
      class_eval %Q(
        def parse_#{keyword}
          next_token

          args = parse_args

          location = @token.location
          node = #{keyword.capitalize}.new(args || [])
          node.location = location
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
        raise_error "expecting token: #{value}" unless @token.keyword?(value)
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

    def push_def(args)
      @def_vars.push(Set.new args.map(&:name))
      ret = yield
      @def_vars.pop
      ret
    end

    def push_var(*vars)
      vars.each do |var|
        @def_vars.last.add var.name
      end
    end

    def is_var?(name)
      name == 'self' || @def_vars.last.include?(name)
    end

    def can_be_assigned?(node)
      node.is_a?(Var) || node.is_a?(InstanceVar) || (node.is_a?(Call) && node.obj.nil? && node.args.length == 0 && node.block.nil?)
    end
  end

  def parse(string)
    Parser.parse string
  end
end
