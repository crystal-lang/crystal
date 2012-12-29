require 'set'
require_relative 'lexer.rb'

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
            atomic = If.new(Call.new(exp, :"!@"), atomic)
          when :while
            next_token_skip_statement_end
            exp = parse_op_assign
            atomic = While.new(exp, atomic, true)
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
          if atomic.is_a?(Call) && atomic.name == :[]
            next_token_skip_space_or_newline

            atomic.name = :'[]='
            atomic.name_length = 0
            atomic.args << parse_expression
          else
            break unless can_be_assigned?(atomic)

            if atomic.is_a?(Ident) && @def_vars.length > 1
              raise "dynamic constant assignment"
            end

            atomic = Var.new(atomic.name) if atomic.is_a?(Call)
            push_var atomic if atomic.is_a?(Var)

            next_token_skip_space_or_newline

            value = parse_op_assign
            atomic = Assign.new(atomic, value)
          end
        when :'+=', :'-=', :'*=', :'/=', :'%=', :'|=', :'&=', :'^=', :'**=', :'<<=', :'>>=', :'||=', :'&&='
          break unless can_be_assigned?(atomic)

          if atomic.is_a?(Ident)
            raise "can't reassign to constant"
          end

          # Rewrite 'a += b' as 'a = a + b'

          if atomic.is_a?(Call) && !@def_vars.last.include?(atomic.name)
            raise "'#{@token.type}' before definition of '#{atomic.name}'"

            atomic = Var.new(atomic.name)
          end

          push_var atomic

          method = @token.type.to_s[0 .. -2].to_sym
          method_column_number = @token.column_number

          next_token_skip_space_or_newline

          value = parse_op_assign
          call = Call.new(atomic, method, [value], nil, method_column_number)
          call.location = location
          atomic = Assign.new(atomic, call)
        else
          break
        end
      end

      atomic
    end

    def parse_question_colon
      cond = parse_range
      while @token.type == :'?'
        next_token_skip_space_or_newline
        true_val = parse_range
        check :':'
        next_token_skip_space_or_newline
        false_val = parse_range
        cond = If.new(cond, true_val, false_val)
      end
      cond
    end

    def parse_range
      location = @token.location
      exp = parse_or
      while true
        exp.location = location

        case @token.type
        when :'..'
          next_token_skip_space_or_newline
          exp = RangeLiteral.new(exp, parse_or, false)
        when :'...'
          next_token_skip_space_or_newline
          exp = RangeLiteral.new(exp, parse_or, true)
        else
          return exp
        end
      end
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
    parse_operator :equality, :cmp, :<, :<=, :>, :>=, :'<=>'
    parse_operator :cmp, :logical_or, :==, :"!=", :=~, :'==='
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
        when :INT, :LONG, :FLOAT
          type = @token.type == :INT ? IntLiteral : (@token.type == :LONG ? LongLiteral : FloatLiteral)
          case @token.value[0]
          when '+'
            left = Call.new left, @token.value[0].to_sym, [type.new(@token.value)], nil, @token.column_number
            next_token_skip_space_or_newline
          when '-'
            left = Call.new left, @token.value[0].to_sym, [type.new(@token.value[1 .. -1])], nil, @token.column_number
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
          check :IDENT, :+, :-, :*, :/, :%, :|, :&, :^, :**, :<<, :<, :<=, :==, :"!=", :=~, :>>, :>, :>=, :'<=>', :'||', :'&&', :'==='
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
              atomic = Call.new(atomic, "#{name}=", args, nil, name_column_number)
              next
            when :'+=', :'-=', :'*=', :'/=', :'%=', :'|=', :'&=', :'^=', :'**=', :'<<=', :'>>='
              # Rewrite 'f.x += value' as 'f.x=(f.x + value)'
              method = @token.type.to_s[0 .. -2].to_sym
              next_token_skip_space
              value = parse_expression
              atomic = Call.new(atomic, "#{name}=", [Call.new(Call.new(atomic, name, [], nil, name_column_number), method, [value], nil, name_column_number)], nil, name_column_number)
              next
            else
              args = parse_args_space_consumed
            end
          else
            args = parse_args
          end

          check_maybe_recursive name

          block = parse_block
          if block
            atomic = Call.new atomic, name, args, block, name_column_number
          else
            atomic = args ? (Call.new atomic, name, args, nil, name_column_number) : (Call.new atomic, name, [], nil, name_column_number)
          end

          atomic = check_pointer_of(atomic)
        when :[]
          column_number = @token.column_number
          next_token_skip_space
          atomic = Call.new atomic, :[], [], nil, column_number
          atomic.name_length = 0
          atomic
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
          atomic = Call.new atomic, :[], args, nil, column_number
          atomic.name_length = 0
          atomic
        else
          break
        end
      end

      atomic
    end

    def check_pointer_of(atomic)
      if atomic.obj && atomic.name == :ptr
        if !(atomic.obj.is_a?(Var) || atomic.obj.is_a?(InstanceVar))
          raise "can only get 'ptr' of variable or instance variable"
        end
        if atomic.args.length != 0
          raise "wrong number of arguments for 'ptr' (#{atomic.args.length} for 0)"
        end
        if atomic.block
          raise "'ptr' can't receive a block"
        end
        atomic = PointerOf.new(atomic.obj)
      end
      atomic
    end

    def parse_atomic
      column_number = @token.column_number
      case @token.type
      when :'('
        parse_parenthesized_expression
      when :'[]'
        next_token_skip_space
        Crystal::ArrayLiteral.new
      when :'['
        parse_array_literal
      when :'{'
        parse_hash_literal
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
      when :'::'
        parse_ident
      when :INT
        node_and_next_token IntLiteral.new(@token.value)
      when :LONG
        node_and_next_token LongLiteral.new(@token.value)
      when :FLOAT
        node_and_next_token FloatLiteral.new(@token.value)
      when :CHAR
        node_and_next_token CharLiteral.new(@token.value)
      when :STRING, :STRING_START
        parse_string
      when :STRING_ARRAY_START
        parse_string_array
      when :SYMBOL
        node_and_next_token SymbolLiteral.new(@token.value)
      when :REGEXP
        node_and_next_token RegexpLiteral.new(@token.value)
      when :GLOBAL
        node_and_next_token Global.new(@token.value)
      when :GLOBAL_MATCH
        node_and_next_token Call.new(Global.new('$~'), :[], [IntLiteral.new(@token.value)])
      when :IDENT
        case @token.value
        when :begin
          parse_begin
        when :nil
          node_and_next_token NilLiteral.new
        when :false
          node_and_next_token BoolLiteral.new(false)
        when :true
          node_and_next_token BoolLiteral.new(true)
        when :yield
          parse_yield
        when :class
          parse_class_def
        when :module
          parse_module_def
        when :include
          parse_include
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
        when :lib
          parse_lib
        when :macro
          parse_macro
        when :require
          parse_require
        when :case
          parse_case
        else
          parse_var_or_call
        end
      when :CONST
        parse_ident
      when :INSTANCE_VAR
        node_and_next_token InstanceVar.new(@token.value)
      else
        raise "unexpected token: #{@token.to_s}"
      end
    end

    def parse_parenthesized_expression
      next_token_skip_space_or_newline
      exp = parse_expression

      check :')'
      next_token_skip_space

      raise "unexpected token: (" if @token.type == :'('
      exp
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
      Crystal::ArrayLiteral.new exps
    end

    def parse_hash_literal
      next_token_skip_space_or_newline
      key_values = []
      while @token.type != :'}'
        if @token.type == :IDENT && string[pos] == ':'
          key_values << SymbolLiteral.new(@token.value)
          next_token
        else
          key_values << parse_expression
          skip_space_or_newline
          check :'=>'
        end
        next_token_skip_space_or_newline
        key_values << parse_expression
        skip_space_or_newline
        if @token.type == :','
          next_token_skip_space_or_newline
        end
      end
      next_token_skip_space
      Crystal::HashLiteral.new key_values
    end

    def parse_require
      next_token_skip_space
      check :STRING
      string = StringLiteral.new(@token.value)
      next_token_skip_space
      Crystal::Require.new string
    end

    def parse_case
      next_token_skip_space_or_newline
      cond = parse_expression
      skip_statement_end

      whens = []
      a_else = nil

      while true
        case @token.type
        when :IDENT
          case @token.value
          when :when
            next_token_skip_space_or_newline
            when_conds = []
            while true
              when_conds << parse_expression
              skip_space
              case @token.type
              when :','
                next_token_skip_space_or_newline
              when :NEWLINE, :';'
                skip_statement_end
                break
              else
                raise "unexpected token: #{@token.to_s} (expecting ',', ';' or '\n')"
              end
            end

            when_body = parse_expressions
            skip_statement_end
            whens << When.new(when_conds, when_body)
          when :else
            if whens.length == 0
              raise "unexpected token: #{@token.to_s} (expecting when)"
            end
            next_token_skip_statement_end
            a_else = parse_expressions
            skip_statement_end
            check_ident :end
            next_token_skip_space_or_newline
            break
          when :end
            next_token_skip_statement_end
            break
          else
            raise "unexpected token: #{@token.to_s} (expecting when, else or end)"
          end
        else
          raise "unexpected token: #{@token.to_s} (expecting when, else or end)"
        end
      end

      Case.new(cond, whens, a_else)
    end

    def parse_ident
      location = @token.location

      names = []
      global = false

      if @token.type == :'::'
        global = true
        next_token_skip_space_or_newline
      end

      check :CONST
      names << @token.value

      next_token
      while @token.type == :'::'
        next_token_skip_space_or_newline

        check :CONST
        names << @token.value

        next_token
      end

      const = Ident.new names, global
      const.location = location
      const
    end

    def parse_begin
      next_token_skip_statement_end
      exps = parse_expressions
      check_ident :end
      next_token_skip_space
      exps
    end

    def parse_var_or_call
      name = @token.value
      name_column_number = @token.column_number
      next_token

      args = parse_args

      block = parse_block

      if block
        check_maybe_recursive name
        Call.new nil, name, args, block, name_column_number, @last_call_has_parenthesis
      else
        if args
          if is_var?(name) && args.length == 1 && (args[0].is_a?(IntLiteral) || args[0].is_a?(FloatLiteral) || args[0].is_a?(LongLiteral)) && args[0].has_sign
            if args[0].value < 0
              args[0].value = args[0].value.abs
              Call.new(Var.new(name), :-, args)
            else
              Call.new(Var.new(name), :+, args)
            end
          else
            check_maybe_recursive name
            Call.new(nil, name, args, nil, name_column_number, @last_call_has_parenthesis)
          end
        elsif is_var? name
          Var.new name
        else
          check_maybe_recursive name
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

      next_token_skip_space

      Block.new(block_args, block_body)
    end

    def parse_args
      case @token.type
      when :'{'
        @last_call_has_parenthesis = false
        nil
      when :"("
        args = []
        next_token_skip_space
        while @token.type != :")"
          if @token.type == :IDENT && @token.value == :out
            next_token_skip_space_or_newline

            case @token.type
            when :IDENT
              var = Var.new(@token.value)
              var.out = true
              var.location = @token.location
              push_var var
              args << var
            when :INSTANCE_VAR
              var = InstanceVar.new(@token.value)
              var.out = true
              var.location = @token.location
              args << var
            else
              raise "expecting variable or instance variable after out"
            end

            next_token_skip_space
          else
            args << parse_expression
          end

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
        @last_call_has_parenthesis = false
        parse_args_space_consumed
      else
        @last_call_has_parenthesis = false
        nil
      end
    end

    def parse_args_space_consumed
      case @token.type
      when :CHAR, :STRING, :STRING_START, :STRING_ARRAY_START, :INT, :LONG, :FLOAT, :IDENT, :SYMBOL, :INSTANCE_VAR, :CONST, :GLOBAL, :GLOBAL_MATCH, :REGEXP, :'(', :'!', :'[', :'[]'
        case @token.value
        when :if, :unless, :while
          nil
        else
          args = []
          while @token.type != :NEWLINE && @token.type != :";" && @token.type != :EOF && @token.type != :')' && @token.type != :':' && !is_end_token
            if @token.type == :IDENT && @token.value == :out
              next_token_skip_space_or_newline

              case @token.type
              when :IDENT
                var = Var.new(@token.value)
                var.out = true
                var.location = @token.location
                push_var var
                args << var
              when :INSTANCE_VAR
                var = InstanceVar.new(@token.value)
                var.out = true
                var.location = @token.location
                args << var
              else
                raise "expecting variable or instance variable after out"
              end

              next_token
            else
              args << parse_op_assign
            end

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

    def parse_class_def
      location = @token.location

      next_token_skip_space_or_newline
      check :CONST

      name = @token.value
      name_column_number = @token.column_number
      next_token_skip_space

      superclass = nil

      if @token.type == :<
        next_token_skip_space_or_newline
        superclass = parse_ident
      end
      skip_statement_end

      body = parse_expressions

      check_ident :end
      next_token_skip_space

      class_def = ClassDef.new name, body, superclass, name_column_number
      class_def.location = location
      class_def
    end

    def parse_module_def
      location = @token.location

      next_token_skip_space_or_newline
      check :CONST

      name = @token.value
      name_column_number = @token.column_number
      next_token_skip_statement_end

      body = parse_expressions

      check_ident :end
      next_token_skip_space

      module_def = ModuleDef.new name, body, name_column_number
      module_def.location = location
      module_def
    end

    def parse_include
      location = @token.location

      next_token_skip_space_or_newline

      name = parse_ident
      skip_statement_end

      inc = Include.new name
      inc.location = location
      inc
    end

    def parse_def
      next_token_skip_space_or_newline
      check :IDENT, :CONST, :"=", :<<, :<, :<=, :==, :===, :"!=", :=~, :>>, :>, :>=, :+, :-, :*, :/, :%, :+@, :-@, :'~@', :'!@', :&, :|, :^, :**, :[], :[]=, :'<=>', :'||', :'&&'

      receiver = nil
      @yields = false

      if @token.type == :CONST
        receiver = parse_ident
      elsif @token.type == :IDENT
        name = @token.value
        next_token
        if @token.type == :'='
          name = "#{name}="
          next_token_skip_space
        else
          skip_space
        end
      else
        name = @token.type
        next_token_skip_space
      end

      @def_name = name
      @maybe_recursive = false

      args = []

      if @token.type == :'.'
        receiver = Var.new name unless receiver
        next_token_skip_space
        check :IDENT, :"=", :<<, :<, :<=, :==, :===, :"!=", :>>, :>, :>=, :+, :-, :*, :/, :%, :+@, :-@, :'~@', :'!@', :&, :|, :^, :**, :[], :[]=, :'<=>'
        name = @token.type == :IDENT ? @token.value : @token.type
        next_token_skip_space
      end

      case @token.type
      when :'('
        next_token_skip_space_or_newline
        while @token.type != :')'
          check_ident
          arg_name = @token.value

          next_token_skip_space_or_newline
          case @token.type
          when :'='
            next_token_skip_space_or_newline
            default_value = parse_expression
          when :':'
            next_token_skip_space_or_newline
            if @token.type == :IDENT && @token.value == 'self'
              type_restriction = :self
              next_token_skip_space
            else
              type_restriction = parse_ident
            end
          else
            default_value = nil
            type_restriction = nil
          end

          args << Arg.new(arg_name, default_value, type_restriction)

          if @token.type == :','
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_statement_end
      when :IDENT
        while @token.type != :NEWLINE && @token.type != :";"
          check_ident
          arg_name = @token.value

          next_token_skip_space
          case @token.type
          when :'='
            next_token_skip_space_or_newline
            default_value = parse_expression
          when :':'
            next_token_skip_space_or_newline
            if @token.type == :IDENT && @token.value == 'self'
              type_restriction = :self
              next_token_skip_space
            else
              type_restriction = parse_ident
            end
          else
            default_value = nil
            type_restriction = nil
          end

          args << Arg.new(arg_name, default_value, type_restriction)

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

      next_token_skip_space

      a_def = Def.new name, args, body, receiver, @yields
      a_def.maybe_recursive = @maybe_recursive
      a_def
    end

    def parse_macro
      next_token_skip_space_or_newline
      check :IDENT, :CONST, :"=", :<<, :<, :<=, :==, :===, :"!=", :>>, :>, :>=, :+, :-, :*, :/, :%, :+@, :-@, :'~@', :&, :|, :^, :**, :[], :[]=, :'<=>'

      receiver = nil

      if @token.type == :CONST
        receiver = parse_ident
      elsif @token.type == :IDENT
        name = @token.value
        next_token
        if @token.type == :'='
          name = "#{name}="
          next_token_skip_space
        else
          skip_space
        end
      else
        name = @token.type
        next_token_skip_space
      end

      args = []

      if @token.type == :'.'
        receiver = Var.new name unless receiver
        next_token_skip_space
        check :IDENT, :"=", :<<, :<, :<=, :==, :"!=", :>>, :>, :>=, :+, :-, :*, :/, :%, :+@, :-@, :'~@', :&, :|, :^, :**, :[], :[]=, :'<=>'
        name = @token.type == :IDENT ? @token.value : @token.type
        next_token_skip_space
      end

      case @token.type
      when :'('
        next_token_skip_space_or_newline
        while @token.type != :')'
          check_ident
          arg_name = @token.value

          next_token_skip_space_or_newline
          if @token.type == :'='
            next_token_skip_space_or_newline
            default_value = parse_expression
          end

          args << Arg.new(arg_name, default_value)

          if @token.type == :','
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_statement_end
      when :IDENT
        while @token.type != :NEWLINE && @token.type != :";"
          check_ident
          arg_name = @token.value

          next_token_skip_space
          if @token.type == :'='
            next_token_skip_space_or_newline
            default_value = parse_expression
          end

          args << Arg.new(arg_name, default_value)

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

      next_token_skip_space

      Macro.new name, args, body, receiver
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
      next_token_skip_space

      node = If.new Call.new(cond, :"!@"), a_then, a_else
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
      next_token_skip_space

      node = While.new cond, body
      node.location = location
      node
    end

    ['return', 'next', 'break', 'yield'].each do |keyword|
      class_eval %Q(
        def parse_#{keyword}
          next_token

          #{keyword == 'yield' ? '@yields = true' : ''}

          args = parse_args

          location = @token.location
          node = #{keyword.capitalize}.new(args || [])
          node.location = location
          node
        end
      )
    end


    def parse_lib
      next_token_skip_space_or_newline

      check :CONST
      name = @token.value
      name_column_number = @token.column_number
      next_token_skip_space

      if @token.type == :'('
        next_token_skip_space_or_newline
        libname = parse_string.value # TODO disallow string interpolation? Use another syntax?
        skip_space_or_newline
        check :')'
        next_token_skip_statement_end
      else
        skip_statement_end
      end

      body = parse_lib_body

      check_ident :end
      next_token_skip_statement_end

      LibDef.new name, libname, body, name_column_number
    end

    def parse_lib_body
      expressions = []
      while true
        location = @token.location

        case @token.type
        when :IDENT
          case @token.value
          when :fun
            exp = parse_fun_def
            exp.location = location
            expressions << exp
          when :type
            exp = parse_type_def
            exp.location = location
            expressions << exp
          when :struct
            exp = parse_struct_def
            exp.location = location
            expressions << exp
          when :end
            break
          else
            break
          end
        when :CONST
          ident = parse_ident
          next_token_skip_space
          check :'='
          next_token_skip_space_or_newline
          value = parse_expression
          skip_statement_end
          expressions << Assign.new(ident, value)
        else
          break
        end
      end
      expressions
    end

    def parse_fun_def
      next_token_skip_space_or_newline

      check_ident
      name = @token.value

      next_token_skip_space_or_newline

      args = []

      if @token.type == :'('
        next_token_skip_space_or_newline
        while @token.type != :')'
          check_ident
          arg_name = @token.value

          next_token_skip_space_or_newline
          check :':'
          next_token_skip_space_or_newline

          out = false
          if @token.type == :IDENT && @token.value == :out
            out = true
            next_token_skip_space_or_newline
          end

          arg_type = parse_ident
          ptr = parse_trailing_pointers

          skip_space_or_newline
          args << FunDefArg.new(arg_name, arg_type, ptr, out)

          if @token.type == :','
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_statement_end
      end

      ptr = 0

      if @token.type == :':'
        next_token_skip_space_or_newline

        return_type = parse_ident

        ptr = parse_trailing_pointers

        skip_statement_end
      end

      FunDef.new name, args, return_type, ptr
    end

    def parse_type_def
      next_token_skip_space_or_newline

      check :CONST
      name = @token.value
      name_column_number = @token.column_number
      next_token_skip_space_or_newline

      check :':'
      next_token_skip_space_or_newline

      type = parse_ident
      ptr = parse_trailing_pointers

      skip_statement_end

      TypeDef.new name, type, ptr, name_column_number
    end

    def parse_struct_def
      next_token_skip_space_or_newline

      check :CONST
      name = @token.value
      next_token_skip_statement_end

      fields = parse_struct_def_fields

      check_ident :end

      next_token_skip_statement_end

      StructDef.new name, fields
    end

    def parse_struct_def_fields
      fields = []

      while true
        case @token.type
        when :IDENT
          case @token.value
          when :end
            break
          else
            name = @token.value
            next_token_skip_space_or_newline

            check :':'
            next_token_skip_space_or_newline

            type = parse_ident
            ptr = parse_trailing_pointers

            skip_statement_end

            fields << FunDefArg.new(name, type, ptr)
          end
        else
          break
        end
      end

      fields
    end

    def parse_trailing_pointers
      ptr = 0
      while true
        case @token.type
        when :*
          ptr += 1
          next_token_skip_space_or_newline
        when :**
          ptr += 2
          next_token_skip_space_or_newline
        else
          break
        end
      end
      ptr
    end

    def parse_string
      if @token.type == :STRING
        return node_and_next_token StringLiteral.new(@token.value)
      end

      check :STRING_START
      next_string_token

      pieces = []
      last_piece = nil
      last_piece_is_a_string = false
      has_interpolation = false

      while true
        case @token.type
        when :STRING
          if last_piece_is_a_string
            last_piece << @token.value
          else
            last_piece = @token.value
            last_piece_is_a_string = true
            pieces << last_piece
          end
          next_string_token
        when :STRING_END
          next_token
          break
        when :EOF
          raise "Unterminated string literal"
        else
          has_interpolation = true

          next_token_skip_space_or_newline
          pieces << parse_expression
          last_piece_is_a_string = false

          if @token.type != :'}'
            raise "Unterminated string interpolation"
          end

          next_string_token
        end
      end

      if has_interpolation
        node = nil
        pieces.each do |piece|
          if piece.is_a?(String)
            piece = StringLiteral.new piece
          else
            piece = Call.new(piece, 'to_s')
          end

          if node
            node = Call.new(node, :+, [piece])
          else
            node = piece
          end
        end
        node
      else
        StringLiteral.new pieces.join
      end
    end

    def parse_string_array
      strings = []

      next_string_array_token
      while true
        case @token.type
        when :STRING
          strings << StringLiteral.new(@token.value)
          next_string_array_token
        when :STRING_ARRAY_END
          next_token
          break
        when :EOF
          raise "Unterminated string array literal"
        end
      end

      ArrayLiteral.new strings
    end

    def node_and_next_token(node)
      next_token
      node
    end

    private

    def check(*token_types)
      if token_types.length == 1
        raise "expecting token '#{token_types[0]}', not '#{@token.to_s}'" unless token_types.any?{|type| @token.type == type}
      else
        raise "expecting any of these tokens: #{token_types.join ', '} (not '#{@token.to_s}')" unless token_types.any?{|type| @token.type == type}
      end
    end

    def check_ident(value = nil)
      if value
        raise "expecting identifier '#{value}', not '#{@token.to_s}'" unless @token.keyword?(value)
      else
        raise "expecting identifier, not '#{@token.to_s}'" unless @token.type == :IDENT && @token.value.is_a?(String)
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
        @def_vars.last.add var.name.to_s
      end
    end

    def is_var?(name)
      name = name.to_s
      name == 'self' || @def_vars.last.include?(name)
    end

    def can_be_assigned?(node)
      node.is_a?(Var) || node.is_a?(InstanceVar) || node.is_a?(Ident) || node.is_a?(Global) || (node.is_a?(Call) && node.obj.nil? && node.args.length == 0 && node.block.nil?)
    end

    def check_maybe_recursive(name)
      @maybe_recursive ||= @def_name == name
    end
  end

  def parse(string)
    Parser.parse string
  end
end
