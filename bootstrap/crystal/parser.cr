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
      @def_name = nil
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

            if atomic.is_a?(Ident) && @def_vars.length > 1
              raise "dynamic constant assignment"
            end

            atomic = Var.new(atomic.name) if atomic.is_a?(Call)

            push_var atomic

            next_token_skip_space_or_newline

            value = parse_op_assign
            atomic = Assign.new(atomic, value)
          end
        when :"+=", :"-=", :"*=", :"/=", :"%=", :"|=", :"&=", :"^=", :"**=", :"<<=", :">>=", :"||=", :"&&="
          break unless can_be_assigned?(atomic)

          if atomic.is_a?(Ident)
            raise "can't reassign to constant"
          end

          # Rewrite 'a += b' as 'a = a + b'

          if atomic.is_a?(Call) && !@def_vars.last.includes?(atomic.name)
            raise "'#{@token.type}' before definition of '#{atomic.name}'"

            atomic = Var.new(atomic.name)
          end

          push_var atomic

          method = @token.type.to_s[0, @token.type.to_s.length - 1]
          method_column_number = @token.column_number

          token_type = @token.type

          next_token_skip_space_or_newline

          value = parse_op_assign
          case token_type
          when :"&&="
            call = And.new(atomic, value)
          when :"||="
            call = Or.new(atomic, value)
          else
            call = Call.new(atomic, method, [value], nil, method_column_number)
          end
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
      while @token.type == :"?"
        next_token_skip_space_or_newline
        true_val = parse_range
        check :":"
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
        when :".."
          next_token_skip_space_or_newline
          exp = RangeLiteral.new(exp, parse_or, false)
        when :"..."
          next_token_skip_space_or_newline
          exp = RangeLiteral.new(exp, parse_or, true)
        else
          return exp
        end
      end
    end

    macro self.parse_operator(name, next_operator, node, operators)"
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
            left = #{node}
          else
            return left
          end
        end
      end
    "end

    parse_operator :or, :and, "Or.new left, right", ":\"||\""
    parse_operator :and, :equality, "And.new left, right", ":\"&&\""
    parse_operator :equality, :cmp, "Call.new left, method, [right], nil, method_column_number", ":\"<\", :\"<=\", :\">\", :\">=\", :\"<=>\""
    parse_operator :cmp, :logical_or, "Call.new left, method, [right], nil, method_column_number", ":\"==\", :\"!=\", :\"=~\", :\"===\""
    parse_operator :logical_or, :logical_and, "Call.new left, method, [right], nil, method_column_number", ":\"|\", :\"^\""
    parse_operator :logical_and, :shift, "Call.new left, method, [right], nil, method_column_number", ":\"&\""
    parse_operator :shift, :add_or_sub, "Call.new left, method, [right], nil, method_column_number", ":\"<<\", :\">>\""

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

    parse_operator :mul_or_div, :prefix, "Call.new left, method, [right], nil, method_column_number", ":\"*\", :\"/\", :\"%\""

    def parse_prefix
      column_number = @token.column_number
      case @token.type
      when :"!"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "!@", [], nil, column_number
      when :"+"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "+@", [], nil, column_number
      when :"-"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "-@", [], nil, column_number
      when :"~"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "~@", [], nil, column_number
      else
        parse_pow
      end
    end

    parse_operator :pow, :atomic_with_method, "Call.new left, method, [right], nil, method_column_number", ":\"**\""

    def parse_atomic_with_method
      location = @token.location

      atomic = parse_atomic

      while true
        atomic.location = location

        case @token.type
        when :SPACE
          next_token
        when :"."
          next_token_skip_space_or_newline
          check [:IDENT, :"+", :"-", :"*", :"/", :"%", :"|", :"&", :"^", :"**", :"<<", :"<", :"<=", :"==", :"!=", :"=~", :">>", :">", :">=", :"<=>", :"||", :"&&", :"==="]
          name = @token.type == :IDENT ? @token.value.to_s : @token.type.to_s
          name_column_number = @token.column_number
          next_token

          keep_processing = true

          if @token.type == :SPACE
            next_token
            case @token.type
            when :"="
              # Rewrite 'f.x = args' as f.x=(args)
              next_token_skip_space_or_newline
              args = parse_args_space_consumed(true)
              atomic = Call.new(atomic, "#{name}=", args, nil, name_column_number)
              keep_processing = false
            when :"+=", :"-=", :"*=", :"/=", :"%=", :"|=", :"&=", :"^=", :"**=", :"<<=", :">>="
              # Rewrite 'f.x += value' as 'f.x=(f.x + value)'
              method = @token.type.to_s[0, @token.type.to_s.length - 1]
              next_token_skip_space
              value = parse_expression
              atomic = Call.new(atomic, "#{name}=", [Call.new(Call.new(atomic, name, [], nil, name_column_number), method, [value], nil, name_column_number)], nil, name_column_number)
              keep_processing = false
            else
              args = parse_args_space_consumed
            end
          else
            args = parse_args
          end

          if keep_processing
            check_maybe_recursive name

            block = parse_block
            if block
              atomic = Call.new atomic, name, (args || []), block, name_column_number
            else
              atomic = args ? (Call.new atomic, name, args, nil, name_column_number) : (Call.new atomic, name, [], nil, name_column_number)
            end
          end
          # atomic = check_special_call(atomic)
        when :"[]"
          column_number = @token.column_number
          next_token_skip_space
          atomic = Call.new atomic, "[]", [], nil, column_number
          atomic.name_length = 0 if atomic.is_a?(Call)
          atomic
        when :"["
          column_number = @token.column_number
          next_token_skip_space_or_newline
          args = []
          while true
            args << parse_expression
            case @token.type
            when :","
              next_token_skip_space_or_newline
              if @token.type == :"]"
                next_token_skip_space
                break
              end
            when :"]"
              next_token_skip_space
              break
            end
          end
          atomic = Call.new atomic, :"[]", args, nil, column_number
          atomic.name_length = 0 if atomic.is_a?(Call)
          atomic
        else
          break
        end
      end

      atomic
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
      when :IDENT
        case @token.value
        when :nil
          node_and_next_token NilLiteral.new
        when :true
          node_and_next_token BoolLiteral.new(true)
        when :false
          node_and_next_token BoolLiteral.new(false)
        when :yield
          parse_yield
        when :def
          parse_def
        when :if
          parse_if
        when :unless
          parse_unless
        when :include
          parse_include
        when :generic
          next_token_skip_space_or_newline
          parse_class_def(true)
        when :class
          parse_class_def
        when :module
          parse_module_def
        when :while
          parse_while
        else
          parse_var_or_call
        end
      when :CONST
        parse_ident
      when :INSTANCE_VAR
        node_and_next_token InstanceVar.new(@token.value.to_s)
      else
        raise "unexpected token #{@token}"
      end
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

    def parse_class_def(is_generic = false)
      location = @token.location

      next_token_skip_space_or_newline
      check :CONST

      name = @token.value
      name_column_number = @token.column_number
      next_token_skip_space

      superclass = nil

      if @token.type == :"<"
        next_token_skip_space_or_newline
        superclass = parse_ident
      end
      skip_statement_end

      body = parse_expressions

      check_ident :end
      next_token_skip_space

      class_def = ClassDef.new name, body, superclass, is_generic, name_column_number
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

    def parse_include
      location = @token.location

      next_token_skip_space_or_newline

      name = parse_ident

      inc = Include.new name
      inc.location = location
      inc
    end

    def parse_def
      next_token_skip_space_or_newline
      check [:IDENT, :CONST, :"=", :"<<", :"<", :"<=", :"==", :"===", :"!=", :"=~", :">>", :">", :">=", :"+", :"-", :"*", :"/", :"%", :"+@", :"-@", :"~@", :"!@", :"&", :"|", :"^", :"**", :"[]", :"[]=", :"<=>"]

      receiver = nil
      @yields = false

      if @token.type == :CONST
        receiver = parse_ident
      elsif @token.type == :IDENT
        name = @token.value.to_s
        next_token
        if @token.type == :"="
          name = "#{name}="
          next_token_skip_space
        else
          skip_space
        end
      else
        name = @token.type.to_s
        next_token_skip_space
      end

      @def_name = name
      @maybe_recursive = false

      args = []

      if @token.type == :"."
        receiver = Var.new name unless receiver
        next_token_skip_space
        check [:IDENT, :"=", :"<<", :"<", :"<=", :"==", :"===", :"!=", :"=~", :">>", :">", :">=", :"+", :"-", :"*", :"/", :"%", :"+@", :"-@", :"~@", :"!@", :"&", :"|", :"^", :"**", :"[]", :"[]=", :"<=>"]
        name = @token.type == :IDENT ? @token.value.to_s : @token.type.to_s
        next_token_skip_space
      end

      case @token.type
      when :"("
        next_token_skip_space_or_newline
        while @token.type != :")"
          check :IDENT
          arg_name = @token.value.to_s

          next_token_skip_space_or_newline
          case @token.type
          when :"="
            next_token_skip_space_or_newline
            default_value = parse_expression
          when :":"
            next_token_skip_space_or_newline
            if @token.keyword?("self")
              type_restriction = SelfRestriction.new
              next_token_skip_space
            else
              type_restriction = parse_ident
            end
          else
            default_value = nil
            type_restriction = nil
          end

          args << Arg.new(arg_name, default_value, type_restriction)

          if @token.type == :","
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_statement_end
      when :IDENT
        while @token.type != :NEWLINE && @token.type != :";"
          check :IDENT
          arg_name = @token.value.to_s

          next_token_skip_space
          case @token.type
          when :"="
            next_token_skip_space_or_newline
            default_value = parse_expression
          when :":"
            next_token_skip_space_or_newline
            if @token.keyword?("self")
              type_restriction = SelfRestriction.new
              next_token_skip_space
            else
              type_restriction = parse_ident
            end
          else
            default_value = nil
            type_restriction = nil
          end

          args << Arg.new(arg_name, default_value, type_restriction)

          if @token.type == :","
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

      node = If.new Call.new(cond, "!@"), a_then, a_else
      node.location = location
      node
    end

    def parse_var_or_call
      name = @token.value.to_s
      name_column_number = @token.column_number
      next_token

      args = parse_args
      block = parse_block

      if block
        check_maybe_recursive name
        Call.new nil, name, (args || []), block, name_column_number, @last_call_has_parenthesis
      else
        if args
          if is_var?(name) && args.length == 1 && (num = args[0]) && (num.is_a?(NumberLiteral) && num.has_sign)
            # TODO: don't repeat this
            num = args[0]
            if num.is_a?(NumberLiteral)
              sign = num.value[0].to_s
              num.value = num.value[1, num.value.length - 1]
              Call.new(Var.new(name), sign, args)
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
      elsif @token.type == :"{"
        parse_block2 { check :"}" }
      end
    end

    def parse_block2
      block_args = []
      block_body = nil

      next_token_skip_space
      if @token.type == :"|"
        next_token_skip_space_or_newline
        while @token.type != :"|"
          check :IDENT

          var = Var.new(@token.value)
          var.location = @token.location
          block_args << var

          next_token_skip_space_or_newline
          if @token.type == :","
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_statement_end
      else
        skip_statement_end
      end

      push_vars block_args

      block_body = parse_expressions

      yield

      next_token_skip_space

      Block.new(block_args, block_body)
    end

    def parse_args
      case @token.type
      when :"{"
        @last_call_has_parenthesis = false
        nil
      when :"("
        args = []
        next_token_skip_space_or_newline
        while @token.type != :")"
          if @token.keyword?(:out)
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

    def parse_args_space_consumed(allow_plus_and_minus = false)
      case @token.type
      when :CHAR, :STRING, :STRING_START, :STRING_ARRAY_START, :INT, :LONG, :FLOAT, :DOUBLE, :IDENT, :SYMBOL, :INSTANCE_VAR, :CONST, :GLOBAL, :GLOBAL_MATCH, :REGEXP, :"(", :"!", :"[", :"[]", :"+", :"-"
        if !allow_plus_and_minus && (@token.type == :"+" || @token.type == :"-")
          return nil
        end

        case @token.value
        when :if, :unless, :while
          nil
        else
          args = []
          while @token.type != :NEWLINE && @token.type != :";" && @token.type != :EOF && @token.type != :")" && @token.type != :":" && !is_end_token
            if @token.keyword?(:out)
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

    def parse_ident
      location = @token.location

      names = []
      global = false

      if @token.type == :"::"
        global = true
        next_token_skip_space_or_newline
      end

      check :CONST
      names << @token.value

      next_token
      while @token.type == :"::"
        next_token_skip_space_or_newline

        check :CONST
        names << @token.value

        next_token
      end

      const = Ident.new names, global
      const.location = location
      const
    end

    def parse_yield
      next_token

      @yields = true

      args = parse_args

      location = @token.location
      node = Yield.new(args || [])
      node.location = location
      node
    end

    def parse_break
      next_token

      args = parse_args

      location = @token.location
      node = Break.new(args || [])
      node.location = location
      node
    end

    def parse_return
      next_token

      args = parse_args

      location = @token.location
      node = Return.new(args || [])
      node.location = location
      node
    end

    def parse_next
      next_token

      args = parse_args

      location = @token.location
      node = Next.new(args || [])
      node.location = location
      node
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

    def push_def(args)
      @def_vars.push(Set.new(args.map { |arg| arg.name }))
      ret = yield
      @def_vars.pop
      ret
    end

    def push_vars(vars)
      vars.each do |var|
        push_var var
      end
    end

    def push_var(var : Var)
      @def_vars.last.add var.name.to_s
    end

    def push_var(node)
      # Nothing
    end

    def check(token_types : Array)
      raise "expecting any of these tokens: #{token_types.join ", "} (not '#{@token.type.to_s}')" unless token_types.any? { |type| @token.type == type }
    end

    def check(token_type)
      raise "expecting token '#{token_type}', not '#{@token.to_s}'" unless token_type == @token.type
    end

    def check_token(value)
      raise "expecting token '#{value}', not '#{@token.to_s}'" unless @token.type == :TOKEN && @token.value == value
    end

    def check_ident(value)
      raise "expecting identifier '#{value}', not '#{@token.to_s}'" unless @token.keyword?(value)
    end

    def is_var?(name)
      name = name.to_s
      name == "self" || @def_vars.last.includes?(name)
    end

    def check_maybe_recursive(name)
      @maybe_recursive ||= @def_name == name
    end
  end
end
