require "lexer"
require "ast"
require "set"

module Crystal
  class Parser < Lexer
    def self.parse(str, def_vars = [Set(String).new])
      new(str, def_vars).parse
    end

    def initialize(str, def_vars = [Set(String).new])
      super(str)
      @def_vars = def_vars
      @last_call_has_parenthesis = false
      @yields = -1
    end

    def parse
      next_token_skip_statement_end

      expressions = parse_expressions

      check :EOF

      expressions
    end

    def parse_expressions
      exps = parse_expressions_as_array
      exps.length == 1 ? exps.first : Expressions.new(exps)
    end

    def parse_expressions_or_nil
      Expressions.from(parse_expressions_as_array)
    end

    def parse_expressions_as_array
      exps = [] of ASTNode
      while @token.type != :EOF && !is_end_token
        exps << parse_multi_expression
        skip_statement_end
      end
      exps
    end

    def parse_multi_expression
      location = @token.location

      exps = [] of ASTNode
      i = 0
      assign_index = -1
      exps << (last = parse_expression)
      while true
        case @token.type
        when :SPACE
          next_token
        when :","
          assign_index = i if assign_index == -1 && last.is_a?(Assign)
          i += 1

          next_token_skip_space_or_newline
          exps << (last = parse_expression)
        else
          break
        end
      end

      if exps.length == 1
        exps[0]
      else
        assign_index = i if assign_index == -1 && last.is_a?(Assign)

        if assign_index
          targets = exps[0 ... assign_index].map { |exp| to_lhs(exp) }

          if (assign = exps[assign_index]) && assign.is_a?(Assign)
            targets.push to_lhs(assign.target)

            values = [assign.value]
            values.concat exps[assign_index + 1 .. -1]
            if values.length != 1 && targets.length != values.length
              raise "Multiple assignment count mismatch", location.line_number, location.column_number
            end

            multi = MultiAssign.new(targets, values)
            multi.location = location
            multi
          else
            raise "Impossible"
          end
        else
          exps = Expressions.new exps
          exps.location = location
          exps
        end
      end
    end

    def to_lhs(exp)
      if exp.is_a?(Ident) && @def_vars.length > 1
        raise "dynamic constant assignment"
      end

      exp = Var.new(exp.name) if exp.is_a?(Call)
      push_var exp if exp.is_a?(Var)
      exp
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
            atomic = Unless.new(exp, atomic)
          when :while
            next_token_skip_statement_end
            exp = parse_op_assign
            atomic = While.new(exp, atomic, true)
          when :rescue
            next_token_skip_space
            rescue_body = parse_expression
            atomic = ExceptionHandler.new(atomic, [Rescue.new(rescue_body)] of Rescue)
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

            next_token_skip_space_or_newline

            # Constants need a new scope for their value
            push_def if atomic.is_a?(Ident)
            value = parse_op_assign
            pop_def if atomic.is_a?(Ident)

            push_var atomic

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
            assign = Assign.new(atomic, value)
            assign.location = location
            atomic = And.new(atomic, assign)
          when :"||="
            assign = Assign.new(atomic, value)
            assign.location = location
            atomic = Or.new(atomic, assign)
          else
            call = Call.new(atomic, method, [value] of ASTNode, nil, method_column_number)
            call.location = location
            atomic = Assign.new(atomic, call)
          end
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
    parse_operator :equality, :cmp, "Call.new left, method, [right] of ASTNode, nil, method_column_number", ":\"<\", :\"<=\", :\">\", :\">=\", :\"<=>\""
    parse_operator :cmp, :logical_or, "Call.new left, method, [right] of ASTNode, nil, method_column_number", ":\"==\", :\"!=\", :\"=~\", :\"===\""
    parse_operator :logical_or, :logical_and, "Call.new left, method, [right] of ASTNode, nil, method_column_number", ":\"|\", :\"^\""
    parse_operator :logical_and, :shift, "Call.new left, method, [right] of ASTNode, nil, method_column_number", ":\"&\""
    parse_operator :shift, :add_or_sub, "Call.new left, method, [right] of ASTNode, nil, method_column_number", ":\"<<\", :\">>\""

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
          left = Call.new left, method, [right] of ASTNode, nil, method_column_number
        when :NUMBER
          case @token.value.to_s[0]
          when '+'
            left = Call.new left, @token.value.to_s[0].to_s, [NumberLiteral.new(@token.value.to_s, @token.number_kind)] of ASTNode, nil, @token.column_number
            next_token_skip_space_or_newline
          when '-'
            left = Call.new left, @token.value.to_s[0].to_s, [NumberLiteral.new(@token.value.to_s[1, @token.value.to_s.length - 1], @token.number_kind)] of ASTNode, nil, @token.column_number
            next_token_skip_space_or_newline
          else
            return left
          end
        else
          return left
        end
      end
    end

    parse_operator :mul_or_div, :prefix, "Call.new left, method, [right] of ASTNode, nil, method_column_number", ":\"*\", :\"/\", :\"%\""

    def parse_prefix
      column_number = @token.column_number
      case @token.type
      when :"!"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "!@", [] of ASTNode, nil, column_number
      when :"+"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "+@", [] of ASTNode, nil, column_number
      when :"-"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "-@", [] of ASTNode, nil, column_number
      when :"~"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "~@", [] of ASTNode, nil, column_number
      else
        parse_pow
      end
    end

    parse_operator :pow, :atomic_with_method, "Call.new left, method, [right] of ASTNode, nil, method_column_number", ":\"**\""

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
              args = parse_args_space_consumed(false)
              atomic = Call.new(atomic, "#{name}=", (args || [] of ASTNode), nil, name_column_number)
              keep_processing = false
            when :"+=", :"-=", :"*=", :"/=", :"%=", :"|=", :"&=", :"^=", :"**=", :"<<=", :">>="
              # Rewrite 'f.x += value' as 'f.x=(f.x + value)'
              method = @token.type.to_s[0, @token.type.to_s.length - 1]
              next_token_skip_space
              value = parse_expression
              atomic = Call.new(atomic, "#{name}=", [Call.new(Call.new(atomic, name, [] of ASTNode, nil, name_column_number), method, [value] of ASTNode, nil, name_column_number)] of ASTNode, nil, name_column_number)
              keep_processing = false
            else
              args = parse_args_space_consumed
            end
          else
            args = parse_args
          end

          if keep_processing
            block = parse_block
            if block
              atomic = Call.new atomic, name, (args || [] of ASTNode), block, name_column_number
            else
              atomic = args ? (Call.new atomic, name, args, nil, name_column_number) : (Call.new atomic, name, [] of ASTNode, nil, name_column_number)
            end
          end

          atomic = check_special_call(atomic)
        when :"[]"
          column_number = @token.column_number
          next_token_skip_space
          atomic = Call.new atomic, "[]", [] of ASTNode, nil, column_number
          atomic.name_length = 0 if atomic.is_a?(Call)
          atomic
        when :"["
          column_number = @token.column_number
          next_token_skip_space_or_newline
          args = [] of ASTNode
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
          atomic = Call.new atomic, "[]", args, nil, column_number
          atomic.name_length = 0 if atomic.is_a?(Call)
          atomic
        else
          break
        end
      end

      atomic
    end

    def check_special_call(atomic)
      if atomic.is_a?(Call)
        if (atomic_obj = atomic.obj)
          case atomic.name
          when "ptr"
            if !(atomic_obj.is_a?(Var) || atomic_obj.is_a?(InstanceVar))
              raise "can only get 'ptr' of variable or instance variable"
            end
            if atomic.args.length != 0
              raise "wrong number of arguments for 'ptr' (#{atomic.args.length} for 0)"
            end
            if atomic.block
              raise "'ptr' can't receive a block"
            end
            atomic = PointerOf.new(atomic_obj)
          when "is_a?"
            if atomic.args.length != 1
              raise "wrong number of arguments for 'is_a?' (#{atomic.args.length} for 0)"
            end
            if !atomic.args[0].is_a?(Ident)
              raise "'is_a?' argument must be a Constant"
            end
            if atomic.block
              raise "'is_a?' can't receive a block"
            end
            atomic = IsA.new(atomic_obj, atomic.args[0])
          end
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
        line = @line_number
        column = @token.column_number

        next_token_skip_space
        if @token.keyword?(:of)
          next_token_skip_space_or_newline
          of = parse_type_var
          ArrayLiteral.new([] of ASTNode, of)
        else
          raise "for empty arrays use '[] of ElementType'"#, line, column
        end
      when :"["
        parse_array_literal
      when :"{"
        parse_hash_literal
      when :"::"
        parse_ident
      when :NUMBER
        node_and_next_token NumberLiteral.new(@token.value.to_s, @token.number_kind)
      when :CHAR
        node_and_next_token CharLiteral.new(@token.value.to_s)
      when :STRING, :STRING_START
        parse_string
      when :STRING_ARRAY_START
        parse_string_array
      when :SYMBOL
        node_and_next_token SymbolLiteral.new(@token.value.to_s)
      when :REGEXP
        node_and_next_token RegexpLiteral.new(@token.value.to_s)
      when :GLOBAL
        node_and_next_token Global.new(@token.value.to_s)
      when :GLOBAL_MATCH
        node_and_next_token Call.new(Global.new("$~"), "[]", [NumberLiteral.new(@token.value.to_s, :i32)] of ASTNode)
      when :IDENT
        case @token.value
        when :begin
          parse_begin
        when :nil
          node_and_next_token NilLiteral.new
        when :true
          node_and_next_token BoolLiteral.new(true)
        when :false
          node_and_next_token BoolLiteral.new(false)
        when :yield
          parse_yield
        when :abstract
          next_token_skip_space_or_newline
          check_ident :class
          parse_class_def true
        when :def
          parse_def
        when :macro
          parse_macro
        when :require
          parse_require
        when :case
          parse_case
        when :if
          parse_if
        when :unless
          parse_unless
        when :include
          parse_include
        when :class
          parse_class_def
        when :module
          parse_module_def
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
        else
          parse_var_or_call
        end
      when :CONST
        parse_ident
      when :INSTANCE_VAR
        @instance_vars.add @token.value.to_s if @instance_vars
        node_and_next_token InstanceVar.new(@token.value.to_s)
      when :"-@"
        next_token
        check :IDENT
        ivar_name = "@#{@token.value}"
        @instance_vars.add ivar_name if @instance_vars
        node_and_next_token Call.new(InstanceVar.new(ivar_name), "-@")
      else
        unexpected_token
      end
    end

    def parse_begin
      next_token_skip_statement_end
      exps = parse_expressions
      parse_exception_handler exps
    end

    def parse_exception_handler(exp)
      rescues = nil
      a_else = nil
      a_ensure = nil

      if @token.keyword?(:rescue)
        rescues = [] of Rescue
        while true
          rescues << parse_rescue
          break unless @token.keyword?(:rescue)
        end
      end

      if @token.keyword?(:else)
        unless rescues
          raise "'else' is useless without 'rescue'"
        end

        next_token_skip_statement_end
        a_else = parse_expressions_or_nil
        skip_statement_end
      end

      if @token.keyword?(:ensure)
        next_token_skip_statement_end
        a_ensure = parse_expressions_or_nil
        skip_statement_end
      end

      check_ident :end
      next_token_skip_space

      if rescues || a_ensure
        ExceptionHandler.new(exp, rescues, a_else, a_ensure)
      else
        exp
      end
    end

    def parse_rescue
      next_token_skip_space

      if @token.type == :CONST
        types = [] of ASTNode
        while true
          types << parse_ident
          if @token.type == :","
            next_token_skip_space
          else
            skip_space
            break
          end
        end
      end

      if @token.type == :"=>"
        next_token_skip_space_or_newline
        check :IDENT
        name = @token.value.to_s
        next_token_skip_space
      end

      if @token.type != :";" && @token.type != :NEWLINE
        unexpected_token @token.to_s, "expected ';' or newline"
      end

      next_token_skip_space_or_newline

      if @token.keyword?(:end)
        body = nil
      else
        body = parse_expressions_or_nil
        skip_statement_end
      end

      Rescue.new(body, types, name)
    end

    def parse_while
      location = @token.location

      next_token_skip_space_or_newline

      cond = parse_expression
      skip_statement_end

      body = parse_expressions_or_nil
      skip_statement_end

      check_ident :end
      next_token_skip_space

      node = While.new cond, body
      node.location = location
      node
    end

    def parse_class_def(is_abstract = false)
      location = @token.location

      next_token_skip_space_or_newline
      check :CONST

      name = @token.value
      name_column_number = @token.column_number
      next_token_skip_space

      type_vars = parse_type_vars

      superclass = nil

      if @token.type == :"<"
        next_token_skip_space_or_newline
        superclass = parse_ident
      end
      skip_statement_end

      body = parse_expressions_or_nil

      check_ident :end
      next_token_skip_space

      class_def = ClassDef.new name, body, superclass, type_vars, is_abstract, name_column_number
      class_def.location = location
      class_def
    end

    def parse_type_vars
      type_vars = nil
      if @token.type == :"("
        type_vars = [] of String

        next_token_skip_space_or_newline
        while @token.type != :")"
          check :CONST
          type_vars.push @token.value.to_s

          next_token_skip_space_or_newline
          if @token.type == :","
            next_token_skip_space_or_newline
          end
        end

        if type_vars.empty?
          raise "must specify at least one type var"
        end

        next_token_skip_space
      end
      type_vars
    end

    def parse_module_def
      location = @token.location

      next_token_skip_space_or_newline
      check :CONST

      name = @token.value
      name_column_number = @token.column_number
      next_token_skip_space

      type_vars = parse_type_vars
      skip_statement_end

      body = parse_expressions_or_nil

      check_ident :end
      next_token_skip_space

      module_def = ModuleDef.new name, body, type_vars, name_column_number
      module_def.location = location
      module_def
    end

    def parse_parenthesized_expression
      next_token_skip_space_or_newline

      if @token.type == :")"
        return node_and_next_token NilLiteral.new
      end

      exps = [] of ASTNode

      while true
        exps << parse_expression
        case @token.type
        when :")"
          next_token_skip_space
          break
        when :NEWLINE, :";"
          next_token_skip_space
        else
          unexpected_token
        end
      end

      unexpected_token "(" if @token.type == :"("

      case exps.length
      when 1
        exps[0]
      else
        Expressions.new exps
      end
    end

    def parse_string
      if @token.type == :STRING
        return node_and_next_token StringLiteral.new(@token.value.to_s)
      end

      string_nest = @token.string_nest
      string_end = @token.string_end
      string_open_count = @token.string_open_count

      check :STRING_START

      next_string_token(string_nest, string_end, string_open_count)
      string_open_count = @token.string_open_count

      pieces = [] of ASTNode | String
      has_interpolation = false

      while true
        case @token.type
        when :STRING
          pieces << @token.value.to_s

          next_string_token(string_nest, string_end, string_open_count)
          string_open_count = @token.string_open_count
        when :STRING_END
          next_token
          break
        when :EOF
          raise "Unterminated string literal"
        else
          has_interpolation = true

          next_token_skip_space_or_newline
          pieces << parse_expression

          if @token.type != :"}"
            raise "Unterminated string interpolation"
          end

          next_string_token(string_nest, string_end, string_open_count)
          string_open_count = @token.string_open_count
        end
      end

      if has_interpolation
        pieces = pieces.map do |piece|
          piece.is_a?(String) ? StringLiteral.new(piece) : piece
        end
        StringInterpolation.new(pieces)
      else
        StringLiteral.new pieces.join
      end
    end

    def parse_string_array
      strings = [] of StringLiteral

      next_string_array_token
      while true
        case @token.type
        when :STRING
          strings << StringLiteral.new(@token.value.to_s)
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

    def parse_array_literal
      next_token_skip_space_or_newline
      exps = [] of ASTNode
      while @token.type != :"]"
        exps << parse_expression
        skip_space_or_newline
        if @token.type == :","
          next_token_skip_space_or_newline
        end
      end
      next_token_skip_space

      of = nil
      if @token.keyword?(:of)
        next_token_skip_space_or_newline
        of = parse_type_var
      end

      ArrayLiteral.new exps, of
    end

    def parse_hash_literal
      column = @token.column_number
      line = @line_number

      next_token_skip_space_or_newline
      keys = [] of ASTNode
      values = [] of ASTNode
      while @token.type != :"}"
        if @token.type == :IDENT && @buffer.value == ':'
          keys << SymbolLiteral.new(@token.value.to_s)
          next_token
        else
          keys << parse_expression
          skip_space_or_newline
          check :"=>"
        end
        next_token_skip_space_or_newline
        values << parse_expression
        skip_space_or_newline
        if @token.type == :","
          next_token_skip_space_or_newline
        end
      end
      next_token_skip_space

      of_key = nil
      of_value = nil
      if @token.keyword?(:of)
        next_token_skip_space_or_newline
        of_key = parse_type_var
        check :"=>"
        next_token_skip_space_or_newline
        of_value = parse_type_var
      end

      if keys.length == 0 && !of_key
        raise "for empty hashes use '{} of KeyType => ValueType'"#, line, column
      end

      Crystal::HashLiteral.new keys, values, of_key, of_value
    end

    def parse_require
      next_token_skip_space
      check :STRING_START
      string_literal = parse_string

      if string_literal.is_a?(StringLiteral)
        string = string_literal.value
      else
        raise "Interpolation not allowed in require"
      end

      skip_space

      Crystal::Require.new string
    end

    def parse_case
      next_token_skip_space_or_newline
      cond = parse_expression
      skip_statement_end

      whens = [] of When
      a_else = nil

      while true
        case @token.type
        when :IDENT
          case @token.value
          when :when
            next_token_skip_space_or_newline
            when_conds = [] of ASTNode
            while true
              when_conds << parse_expression
              skip_space
              if @token.keyword?(:then)
                next_token_skip_space_or_newline
                break
              else
                case @token.type
                when :","
                  next_token_skip_space_or_newline
                when :NEWLINE
                  skip_space_or_newline
                  break
                when :";"
                  skip_statement_end
                  break
                else
                  unexpected_token @token.to_s, "expecting ',', ';' or '\n'"
                end
              end
            end

            when_body = parse_expressions
            skip_space_or_newline
            whens << When.new(when_conds, when_body)
          when :else
            if whens.length == 0
              unexpected_token @token.to_s, "expecting when"
            end
            next_token_skip_statement_end
            a_else = parse_expressions
            skip_statement_end
            check_ident :end
            next_token
            break
          when :end
            next_token
            break
          else
            unexpected_token @token.to_s, "expecting when, else or end"
          end
        else
          unexpected_token @token.to_s, "expecting when, else or end"
        end
      end

      Case.new(cond, whens, a_else)
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
      @instance_vars = Set(String).new
      a_def = parse_def_or_macro Def
      a_def.instance_vars = @instance_vars
      @instance_vars = nil
      a_def
    end

    def parse_macro
      parse_def_or_macro Crystal::Macro
    end

    def parse_def_or_macro(klass)
      push_def

      next_token_skip_space_or_newline
      check [:IDENT, :CONST, :"=", :"<<", :"<", :"<=", :"==", :"===", :"!=", :"=~", :">>", :">", :">=", :"+", :"-", :"*", :"/", :"%", :"+@", :"-@", :"~@", :"!@", :"&", :"|", :"^", :"**", :"[]", :"[]=", :"<=>"]

      receiver = nil
      @yields = -1
      name_column_number = @token.column_number

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

      args = [] of Arg

      if @token.type == :"."
        unless receiver
          if name
            receiver = Var.new name
          else
            raise "shouldn't reach this line"
          end
        end
        next_token_skip_space
        check [:IDENT, :"=", :"<<", :"<", :"<=", :"==", :"===", :"!=", :"=~", :">>", :">", :">=", :"+", :"-", :"*", :"/", :"%", :"+@", :"-@", :"~@", :"!@", :"&", :"|", :"^", :"**", :"[]", :"[]=", :"<=>"]
        name = @token.type == :IDENT ? @token.value.to_s : @token.type.to_s
        name_column_number = @token.column_number
        next_token_skip_space
      end

      case @token.type
      when :"("
        next_token_skip_space_or_newline
        while @token.type != :")"
          block_arg = parse_arg(args, true)
          if block_arg
            check :")"
            break
          end
        end
        next_token_skip_statement_end
      when :IDENT
        while @token.type != :NEWLINE && @token.type != :";"
          block_arg = parse_arg(args, false)
          if block_arg
            break
          end
        end
        next_token_skip_statement_end
      else
        skip_statement_end
      end

      if @token.keyword?(:end)
        body = nil
      else
        body = parse_expressions_or_nil
        body = parse_exception_handler body
      end

      next_token_skip_space

      pop_def

      node = klass.new name, args, body, receiver, block_arg, @yields
      node.name_column_number = name_column_number
      node
    end
    
    def parse_arg(args, parenthesis = false)
      if @token.type == :"&"
        next_token_skip_space_or_newline
        return parse_block_arg
      end

      check :IDENT
      arg_name = @token.value
      arg_location = @token.location

      default_value = nil
      type_restriction = nil

      if parenthesis
        next_token_skip_space_or_newline
      else
        next_token_skip_space
      end
      case @token.type
      when :"="
        next_token_skip_space_or_newline
        default_value = parse_expression
      when :":"
        next_token_skip_space_or_newline
        if @token.keyword?("self")
          type_restriction = SelfType.new
          next_token_skip_space
        else
          type_restriction = parse_type_var
        end
      end

      arg = Arg.new(arg_name, default_value, type_restriction)
      arg.location = arg_location
      args << arg
      push_var arg

      if @token.type == :","
        next_token_skip_space_or_newline
      end

      nil
    end

    def parse_block_arg
      check :IDENT
      name = @token.value
      name_location = @token.location

      next_token_skip_space_or_newline

      inputs = nil
      output = nil

      if @token.type == :":"
        next_token_skip_space_or_newline

        if @token.type == :CONST || @token.keyword?("self")
          inputs = [] of ASTNode
          while true
            if @token.keyword?("self")
              inputs << SelfType.new
              next_token
            else
              inputs << parse_ident
            end

            skip_space_or_newline
            if @token.type == :"->"
              break
            end
            check :","
            next_token_skip_space
          end
        end

        check :"->"
        next_token_skip_space_or_newline

        if @token.type == :CONST
          output = parse_ident
          skip_space_or_newline
        elsif @token.keyword?("self")
          output = SelfType.new
          next_token_skip_space_or_newline
        end
      end

      block_arg = BlockArg.new(name, inputs, output)
      block_arg.location = name_location
      block_arg
    end

    def parse_if(check_end = true)
      location = @token.location

      next_token_skip_space_or_newline

      cond = parse_expression
      skip_statement_end

      a_then = parse_expressions_or_nil
      skip_statement_end

      a_else = nil
      if @token.type == :IDENT
        case @token.value
        when :else
          next_token_skip_statement_end
          a_else = parse_expressions_or_nil
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

      node = Unless.new cond, a_then, a_else
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
        Call.new nil, name, (args || [] of ASTNode), block, name_column_number, @last_call_has_parenthesis
      else
        if args
          if is_var?(name) && args.length == 1 && (num = args[0]) && (num.is_a?(NumberLiteral) && num.has_sign)
            sign = num.value[0].to_s
            num.value = num.value[1, num.value.length - 1]
            Call.new(Var.new(name), sign, args)
          else
            Call.new(nil, name, args, nil, name_column_number, @last_call_has_parenthesis)
          end
        elsif is_var? name
          Var.new name
        else
          Call.new nil, name, [] of ASTNode, nil, name_column_number, @last_call_has_parenthesis
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
      block_args = [] of ASTNode
      block_body = nil

      next_token_skip_space
      if @token.type == :"|"
        next_token_skip_space_or_newline
        while @token.type != :"|"
          check :IDENT

          var = Var.new(@token.value.to_s)
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

      block_body = parse_expressions_or_nil

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
        args = [] of ASTNode
        next_token_skip_space_or_newline
        while @token.type != :")"
          if @token.keyword?(:out)
            next_token_skip_space_or_newline

            case @token.type
            when :IDENT
              var = Var.new(@token.value.to_s)
              var.out = true
              var.location = @token.location
              push_var var
              args << var
            when :INSTANCE_VAR
              ivar = InstanceVar.new(@token.value.to_s)
              ivar.out = true
              ivar.location = @token.location
              args << ivar

              @instance_vars.add @token.value.to_s if @instance_vars
            else
              raise "expecting variable or instance variable after out"
            end

            next_token_skip_space
          else
            args << parse_expression
          end

          skip_space_or_newline
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

    def parse_args_space_consumed(check_plus_and_minus = true)
      case @token.type
      when :CHAR, :STRING, :STRING_START, :STRING_ARRAY_START, :NUMBER, :IDENT, :SYMBOL, :INSTANCE_VAR, :CONST, :GLOBAL, :GLOBAL_MATCH, :REGEXP, :"(", :"!", :"[", :"[]", :"+", :"-"
        if check_plus_and_minus && (@token.type == :"+" || @token.type == :"-")
          return nil if @buffer.value.whitespace?
        end

        case @token.value
        when :if, :unless, :while
          nil
        else
          args = [] of ASTNode
          while @token.type != :NEWLINE && @token.type != :";" && @token.type != :EOF && @token.type != :")" && @token.type != :":" && !is_end_token
            if @token.keyword?(:out)
              next_token_skip_space_or_newline

              case @token.type
              when :IDENT
                var = Var.new(@token.value.to_s)
                var.out = true
                var.location = @token.location
                push_var var
                args << var
              when :INSTANCE_VAR
                ivar = InstanceVar.new(@token.value.to_s)
                ivar.out = true
                ivar.location = @token.location
                args << ivar

                @instance_vars.add @token.value.to_s if @instance_vars
              else
                raise "expecting variable or instance variable after out"
              end

              next_token
            else
              arg = parse_op_assign
              args << arg if arg.is_a?(ASTNode)
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

      names = [] of String
      global = false

      if @token.type == :"::"
        global = true
        next_token_skip_space_or_newline
      end

      check :CONST
      names << @token.value.to_s

      next_token
      while @token.type == :"::"
        next_token_skip_space_or_newline

        check :CONST
        names << @token.value.to_s

        next_token
      end

      const = Ident.new names, global
      const.location = location
      
      if @token.type == :"("
        next_token_skip_space_or_newline

        type_vars = [] of ASTNode
        while true
          type_vars.push parse_type_var

          case @token.type
          when :","
            next_token_skip_space_or_newline
          when :")"
            break
          else
            raise "expecting ',' or ')'"
          end
        end

        if type_vars.empty?
          raise "must specify at least one type var"
        end

        next_token_skip_space

        const = NewGenericClass.new const, type_vars
        const.location = location
      end

      const
    end

    def parse_type_var
      idents = [] of ASTNode
      while true
        ident = parse_ident
        idents.push ident

        skip_space

        if @token.type == :"?"
          idents.push Ident.new(["Nil"], true)
          next_token_skip_space_or_newline
        end

        if @token.type == :"|"
          next_token_skip_space_or_newline
        else
          break
        end
      end

      if idents.length == 1
        idents[0]
      else
        IdentUnion.new idents
      end
    end

    def parse_yield
      next_token

      args = parse_args

      @yields = 0 if @yields < 0
      if args
        if args.length > @yields
          @yields = args.length
        end
      end

      location = @token.location
      node = Yield.new(args || [] of ASTNode)
      node.location = location
      node
    end

    def parse_break
      next_token

      args = parse_args

      location = @token.location
      node = Break.new(args || [] of ASTNode)
      node.location = location
      node
    end

    def parse_return
      next_token

      args = parse_args

      location = @token.location
      node = Return.new(args || [] of ASTNode)
      node.location = location
      node
    end

    def parse_next
      next_token

      args = parse_args

      location = @token.location
      node = Next.new(args || [] of ASTNode)
      node.location = location
      node
    end

    def parse_lib
      next_token_skip_space_or_newline

      check :CONST
      name = @token.value.to_s
      name_column_number = @token.column_number
      next_token_skip_space

      if @token.type == :"("
        next_token_skip_space_or_newline

        string_literal = parse_string
        if string_literal.is_a?(StringLiteral)
          libname = string_literal.value
        else
          raise "Interpolation not allowed in lib name"
        end

        skip_space_or_newline
        check :")"
        next_token_skip_statement_end
      else
        skip_statement_end
      end

      body = parse_lib_body

      check_ident :end
      next_token_skip_space

      LibDef.new name, libname, body, name_column_number
    end

    def parse_lib_body
      expressions = [] of ASTNode
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
            exp = parse_struct_or_union StructDef
            exp.location = location
            expressions << exp
          when :union
            exp = parse_struct_or_union UnionDef
            exp.location = location
            expressions << exp
          when :enum
            exp = parse_enum
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
          check :"="
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

      check :IDENT
      name = @token.value.to_s

      next_token_skip_space_or_newline

      if @token.type == :"="
        next_token_skip_space_or_newline
        check [:IDENT, :CONST]
        real_name = @token.value.to_s
        next_token_skip_space_or_newline
      else
        real_name = name
      end

      args = [] of ASTNode
      varargs = false

      if @token.type == :"("
        next_token_skip_space_or_newline
        while @token.type != :")"
          if @token.type == :"..."
            varargs = true
            next_token_skip_space_or_newline
            check :")"
            break
          end

          check :IDENT
          arg_name = @token.value.to_s
          arg_location = @token.location

          next_token_skip_space_or_newline
          check :":"
          next_token_skip_space_or_newline

          arg_type = parse_ident
          pointer = parse_trailing_pointers

          skip_space_or_newline

          fun_def_arg = FunDefArg.new(arg_name, arg_type, pointer)
          fun_def_arg.location = arg_location
          args << fun_def_arg

          if @token.type == :","
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_statement_end
      end

      pointer = 0

      if @token.type == :":"
        next_token_skip_space_or_newline

        return_type = parse_ident

        pointer = parse_trailing_pointers

        skip_statement_end
      end

      FunDef.new name, args, return_type, pointer, varargs, real_name
    end

    def parse_type_def
      next_token_skip_space_or_newline

      check :CONST
      name = @token.value.to_s
      name_column_number = @token.column_number
      next_token_skip_space_or_newline

      check :":"
      next_token_skip_space_or_newline

      type = parse_ident
      pointer = parse_trailing_pointers

      skip_statement_end

      TypeDef.new name, type, pointer, name_column_number
    end

    def parse_struct_or_union(klass)
      next_token_skip_space_or_newline

      check :CONST
      name = @token.value.to_s
      next_token_skip_statement_end

      fields = parse_struct_or_union_fields

      check_ident :end

      next_token_skip_statement_end

      klass.new name, fields
    end

    def parse_struct_or_union_fields
      fields = [] of FunDefArg

      while true
        case @token.type
        when :IDENT
          case @token.value
          when :end
            break
          else
            names = [] of String
            names << @token.value.to_s

            next_token_skip_space_or_newline

            while @token.type == :","
              next_token_skip_space_or_newline
              check :IDENT
              names << @token.value.to_s
              next_token_skip_space_or_newline
            end

            check :":"
            next_token_skip_space_or_newline

            type = parse_ident
            pointer = parse_trailing_pointers

            skip_statement_end

            names.each do |name|
              fields << FunDefArg.new(name, type, pointer)
            end
          end
        else
          break
        end
      end

      fields
    end

    def parse_trailing_pointers
      pointer = 0
      while true
        case @token.type
        when :"*"
          pointer += 1
          next_token_skip_space_or_newline
        when :"**"
          pointer += 2
          next_token_skip_space_or_newline
        else
          break
        end
      end
      pointer
    end

    def parse_enum
      next_token_skip_space_or_newline

      check :CONST
      name = @token.value
      next_token_skip_statement_end

      constants = [] of Arg
      while !@token.keyword?(:end)
        check :CONST

        constant_name = @token.value
        next_token_skip_space
        if @token.type == :"="
          next_token_skip_space_or_newline
          check :NUMBER
          kind = @token.number_kind
          if kind == :f32 || kind == :f64
            raise "expecting integer constant"
          end
          constant_value = NumberLiteral.new(@token.value.to_s, kind)
          next_token_skip_statement_end
        else
          constant_value = nil
          skip_statement_end
        end

        if @token.type == :","
          next_token_skip_statement_end
        end

        constants << Arg.new(constant_name, constant_value)
      end

      check_ident :end
      next_token_skip_statement_end

      EnumDef.new name, constants
    end

    def node_and_next_token(node)
      next_token
      node
    end

    def is_end_token
      return true if @token.type == :"}" || @token.type == :"]"
      return false unless @token.type == :IDENT

      case @token.value
      when :do, :end, :else, :elsif, :when, :rescue, :ensure
        true
      else
        false
      end
    end

    def can_be_assigned?(node)
      node.is_a?(Var) ||
        node.is_a?(InstanceVar) ||
        node.is_a?(Ident) ||
        node.is_a?(Global) ||
        (node.is_a?(Call) && node.obj.nil? && node.args.length == 0 && node.block.nil?)
    end

    def push_def
      @def_vars.push(Set(String).new)
    end

    def pop_def
      @def_vars.pop
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

    def push_var(var : Arg)
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

    def unexpected_token(token = @token.to_s, msg = nil)
      if msg
        raise "unexpected token #{token} (#{msg})"
      else
        raise "unexpected token #{token}"
      end
    end

    def is_var?(name)
      name = name.to_s
      name == "self" || @def_vars.last.includes?(name)
    end
  end
end
