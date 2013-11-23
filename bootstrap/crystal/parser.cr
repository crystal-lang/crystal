require "lexer"
require "ast"
require "set"

module Crystal
  class Parser < Lexer
    def self.parse(str, def_vars = [Set(String).new])
      new(str, def_vars).parse
    end

    def initialize(str, @def_vars = [Set(String).new])
      super(str)
      @last_call_has_parenthesis = false
      @yields = nil
    end

    def parse
      next_token_skip_statement_end

      expressions = parse_expressions

      check :EOF

      expressions
    end

    def parse_expressions
      exps = [] of ASTNode
      while @token.type != :EOF && !is_end_token
        exps << parse_multi_expression
        skip_statement_end
      end
      Expressions.from(exps)
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
              raise "Multiple assignment count mismatch", location
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

            if atomic.is_a?(Var) && atomic.name == "self"
              raise "can't change the value of self", location
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

          if atomic.is_a?(Call) && atomic.name != "[]" !@def_vars.last.includes?(atomic.name)
            raise "'#{@token.type}' before definition of '#{atomic.name}'"

            atomic = Var.new(atomic.name)
          end

          push_var atomic

          method = @token.type.to_s[0, @token.type.to_s.length - 1]
          method_column_number = @token.column_number

          token_type = @token.type

          next_token_skip_space_or_newline

          value = parse_op_assign

          if atomic.is_a?(Call) && atomic.name == "[]"
            obj = atomic.obj
            atomic_clone = atomic.clone

            case token_type
            when :"&&="
              atomic.args.push value
              assign = Call.new(obj, "[]=", atomic.args, nil, nil, false, method_column_number)
              assign.location = location
              atomic = And.new(atomic_clone, assign)
            when :"||="
              atomic.args.push value
              assign = Call.new(obj, "[]=", atomic.args, nil, nil, false, method_column_number)
              assign.location = location
              fetch = atomic_clone
              fetch.name = "[]?"
              atomic = Or.new(fetch, assign)
            else
              call = Call.new(atomic_clone, method, [value] of ASTNode, nil, nil, false, method_column_number)
              call.location = location
              atomic.args.push call
              atomic = Call.new(obj, "[]=", atomic.args, nil, nil, false, method_column_number)
            end
          else
            case token_type
            when :"&&="
              assign = Assign.new(atomic, value)
              assign.location = location
              atomic = And.new(atomic.clone, assign)
            when :"||="
              assign = Assign.new(atomic, value)
              assign.location = location
              atomic = Or.new(atomic.clone, assign)
            else
              call = Call.new(atomic, method, [value] of ASTNode, nil, nil, false, method_column_number)
              call.location = location
              atomic = Assign.new(atomic.clone, call)
            end
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

    macro self.parse_cmp_operator(name, next_operator, operators)"
      def parse_#{name}
        location = @token.location

        left = parse_#{next_operator}
        last_left = nil
        last_right = nil
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

            if last_right && last_left
              left = Call.new last_right, method, [right] of ASTNode, nil, nil, false, method_column_number
              left = And.new(last_left, left)
            else
              left = Call.new left, method, [right] of ASTNode, nil, nil, false, method_column_number
            end

            last_right = right
            last_left = left
          else
            return left
          end
        end
      end
    "end

    parse_operator :or, :and, "Or.new left, right", ":\"||\""
    parse_operator :and, :equality, "And.new left, right", ":\"&&\""
    parse_cmp_operator :equality, :cmp, ":\"<\", :\"<=\", :\">\", :\">=\", :\"<=>\""
    parse_cmp_operator :cmp, :logical_or, ":\"==\", :\"!=\", :\"=~\", :\"===\""
    parse_operator :logical_or, :logical_and, "Call.new left, method, [right] of ASTNode, nil, nil, false, method_column_number", ":\"|\", :\"^\""
    parse_operator :logical_and, :shift, "Call.new left, method, [right] of ASTNode, nil, nil, false, method_column_number", ":\"&\""
    parse_operator :shift, :add_or_sub, "Call.new left, method, [right] of ASTNode, nil, nil, false, method_column_number", ":\"<<\", :\">>\""

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
          left = Call.new left, method, [right] of ASTNode, nil, nil, false, method_column_number
        when :NUMBER
          case @token.value.to_s[0]
          when '+'
            left = Call.new left, @token.value.to_s[0].to_s, [NumberLiteral.new(@token.value.to_s, @token.number_kind)] of ASTNode, nil, nil, false, @token.column_number
            next_token_skip_space_or_newline
          when '-'
            left = Call.new left, @token.value.to_s[0].to_s, [NumberLiteral.new(@token.value.to_s[1, @token.value.to_s.length - 1], @token.number_kind)] of ASTNode, nil, nil, false, @token.column_number
            next_token_skip_space_or_newline
          else
            return left
          end
        else
          return left
        end
      end
    end

    parse_operator :mul_or_div, :prefix, "Call.new left, method, [right] of ASTNode, nil, nil, false, method_column_number", ":\"*\", :\"/\", :\"%\""

    def parse_prefix
      column_number = @token.column_number
      case @token.type
      when :"!"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "!@", [] of ASTNode, nil, nil, false, column_number
      when :"+"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "+@", [] of ASTNode, nil, nil, false, column_number
      when :"-"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "-@", [] of ASTNode, nil, nil, false, column_number
      when :"~"
        next_token_skip_space_or_newline
        Call.new parse_prefix, "~@", [] of ASTNode, nil, nil, false, column_number
      else
        parse_pow
      end
    end

    parse_operator :pow, :atomic_with_method, "Call.new left, method, [right] of ASTNode, nil, nil, false, method_column_number", ":\"**\""

    AtomicWithMethodCheck = [:IDENT, :"+", :"-", :"*", :"/", :"%", :"|", :"&", :"^", :"**", :"<<", :"<", :"<=", :"==", :"!=", :"=~", :">>", :">", :">=", :"<=>", :"||", :"&&", :"==="]

    def parse_atomic_with_method
      location = @token.location
      atomic = parse_atomic
      parse_atomic_method_suffix atomic, location
    end

    def parse_atomic_method_suffix(atomic, location)
      # This line is needed until we fix a bug in the codegen
      atomic = atomic
      while true
        atomic.location = location

        case @token.type
        when :SPACE
          next_token
        when :"."
          next_token_skip_space_or_newline
          check AtomicWithMethodCheck
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
              call_args = parse_call_args_space_consumed(false, true)
              args = call_args.args if call_args

              atomic = Call.new(atomic, "#{name}=", (args || [] of ASTNode), nil, nil, false, name_column_number)
              keep_processing = false
            when :"+=", :"-=", :"*=", :"/=", :"%=", :"|=", :"&=", :"^=", :"**=", :"<<=", :">>="
              # Rewrite 'f.x += value' as 'f.x=(f.x + value)'
              method = @token.type.to_s[0, @token.type.to_s.length - 1]
              next_token_skip_space
              value = parse_expression
              atomic = Call.new(atomic, "#{name}=", [Call.new(Call.new(atomic, name, [] of ASTNode, nil, nil, false, name_column_number), method, [value] of ASTNode, nil, nil, false, name_column_number)] of ASTNode, nil, nil, false, name_column_number)
              keep_processing = false
            else
              call_args = parse_call_args_space_consumed
              if call_args
                args = call_args.args
                block = call_args.block
              end
            end
          else
            call_args = parse_call_args
            if call_args
              args = call_args.args
              block = call_args.block
            end
          end

          if keep_processing
            block = parse_block(block)
            if block
              atomic = Call.new atomic, name, (args || [] of ASTNode), block, nil, false, name_column_number
            else
              atomic = args ? (Call.new atomic, name, args, nil, nil, false, name_column_number) : (Call.new atomic, name, [] of ASTNode, nil, nil, false, name_column_number)
            end
          end

          atomic = check_special_call(atomic)
        when :"[]"
          column_number = @token.column_number
          next_token_skip_space
          atomic = Call.new atomic, "[]", [] of ASTNode, nil, nil, false, column_number
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

          if @token.type == :"?"
            method_name = "[]?"
            next_token_skip_space
          else
            method_name = "[]"
            skip_space
          end

          atomic = Call.new atomic, method_name, args, nil, nil, false, column_number
          atomic.name_length = 0 if atomic.is_a?(Call)
          atomic
        else
          break
        end
      end

      atomic
    end

    def check_special_call(atomic)
      if atomic.is_a?(Call) && (atomic_obj = atomic.obj)
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
            raise "wrong number of arguments for 'is_a?' (#{atomic.args.length} for 1)"
          end
          if !atomic.args[0].is_a?(Ident)
            raise "'is_a?' argument must be a Constant"
          end
          if atomic.block
            raise "'is_a?' can't receive a block"
          end
          atomic = IsA.new(atomic_obj, atomic.args[0])
        when "responds_to?"
          if atomic.args.length != 1
            raise "wrong number of arguments for 'responds_to?' (#{atomic.args.length} for 1)"
          end
          arg = atomic.args[0]
          unless arg.is_a?(SymbolLiteral)
            raise "'responds_to?' argument must be a Symbol literal"
          end
          if atomic.block
            raise "'responds_to?' can't receive a block"
          end
          atomic = RespondsTo.new(atomic_obj, arg)
        when "yield"
          if atomic.block
            raise "'yield' can't receive a block"
          end
          yields = (@yields ||= 1)
          if atomic.args && atomic.args.length > yields
            @yields = atomic.args.length
          end
          atomic = Yield.new(atomic.args, atomic.obj)
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
          of = parse_single_type
          ArrayLiteral.new([] of ASTNode, of)
        else
          raise "for empty arrays use '[] of ElementType'"#, line, column
        end
      when :"["
        parse_array_literal
      when :"{"
        parse_hash_literal
      when :"::"
        parse_ident_or_global_call
      when :"->"
        parse_fun_literal
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
        when :fun
          parse_fun_def(true)
        else
          parse_var_or_call
        end
      when :CONST
        parse_ident
      when :INSTANCE_VAR
        @instance_vars.add @token.value.to_s if @instance_vars
        node_and_next_token InstanceVar.new(@token.value.to_s)
      when :CLASS_VAR
        node_and_next_token ClassVar.new(@token.value.to_s)
      when :"-@"
        next_token
        case @token.type
        when :IDENT
          ivar_name = "@#{@token.value}"
          @instance_vars.add ivar_name if @instance_vars
          node_and_next_token Call.new(InstanceVar.new(ivar_name), "-@")
        when :INSTANCE_VAR
          class_var_name = "@#{@token.value}"
          node_and_next_token Call.new(ClassVar.new(class_var_name), "-@")
        else
          unexpected_token "-@"
        end
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
        found_catch_all = false
        while true
          location = @token.location
          a_rescue = parse_rescue
          if a_rescue.types
            if found_catch_all
              raise "specific rescue must come before catch-all rescue", location
            end
          else
            if found_catch_all
              raise "catch-all rescue can only be specified once", location
            end
            found_catch_all = true
          end
          rescues << a_rescue
          break unless @token.keyword?(:rescue)
        end
      end

      if @token.keyword?(:else)
        unless rescues
          raise "'else' is useless without 'rescue'"
        end

        next_token_skip_statement_end
        a_else = parse_expressions
        skip_statement_end
      end

      if @token.keyword?(:ensure)
        next_token_skip_statement_end
        a_ensure = parse_expressions
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

    SemicolonOrNewLine = [:";", :NEWLINE]

    def parse_rescue
      next_token_skip_space

      case @token.type
      when :IDENT
        name = @token.value.to_s

        if @def_vars.last.includes?(name)
          raise "exception variable '#{name}' shadows local variable '#{name}'"
        end

        push_var_name name
        next_token_skip_space

        if @token.type == :":"
          next_token_skip_space_or_newline

          check :CONST

          types = parse_rescue_types
        end
      when :CONST
        types = parse_rescue_types
      end

      check SemicolonOrNewLine

      next_token_skip_space_or_newline

      if @token.keyword?(:end)
        body = nil
      else
        body = parse_expressions
        skip_statement_end
      end

      @def_vars.last.delete name if name

      Rescue.new(body, types, name)
    end

    def parse_rescue_types
      types = [] of ASTNode
      while true
        types << parse_ident
        skip_space
        if @token.type == :"|"
          next_token_skip_space
        else
          skip_space
          break
        end
      end
      types
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

    def parse_call_block_arg(args, check_paren)
      next_token_skip_space

      if @token.type == :"."
        obj = Var.new("#arg0")
        next_token_skip_space

        location = @token.location

        if @token.type == :"["
          call = parse_atomic_method_suffix obj, location
        else
          call = parse_var_or_call(false, true)

          if call.is_a?(Call)
            call.obj = obj
          else
            raise "Bug: #{call} should be a call"
          end

          call = parse_atomic_method_suffix call, location
        end

        block = Block.new([Var.new("#arg0")], call)
      else
        block_arg = parse_expression
      end

      if check_paren
        check :")"
        next_token_skip_space
      else
        skip_space
      end

      return CallArgs.new args, block, block_arg
    end

    def parse_class_def(is_abstract = false)
      location = @token.location

      next_token_skip_space_or_newline
      name_column_number = @token.column_number
      name = parse_ident(false)
      skip_space

      type_vars = parse_type_vars

      superclass = nil

      if @token.type == :"<"
        next_token_skip_space_or_newline
        superclass = parse_ident
      end
      skip_statement_end

      body = parse_expressions

      check_ident :end
      next_token_skip_space

      raise "Bug: ClassDef name can only be an Ident" unless name.is_a?(Ident)

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

      name_column_number = @token.column_number
      name = parse_ident(false)
      skip_space

      type_vars = parse_type_vars
      skip_statement_end

      body = parse_expressions

      check_ident :end
      next_token_skip_space

      raise "Bug: ModuleDef name can only be an Ident" unless name.is_a?(Ident)

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

    def parse_fun_literal
      next_token_skip_space_or_newline

      unless @token.type == :"{" || @token.type == :"(" || @token.keyword?(:do)
        return parse_fun_pointer
      end

      args = [] of Arg
      if @token.type == :"("
        next_token_skip_space_or_newline
        while @token.type != :")"
          args << parse_fun_literal_arg
        end
        next_token_skip_space_or_newline
      end

      current_vars = @def_vars.last.dup
      push_def current_vars
      push_vars args

      if @token.keyword?(:do)
        next_token_skip_statement_end
        body = parse_expressions
        check_ident :"end"
      elsif @token.type == :"{"
        next_token_skip_statement_end
        body = parse_expressions
        check :"}"
      else
        unexpected_token
      end

      pop_def

      next_token_skip_space

      FunLiteral.new(Def.new("->", args, body))
    end

    def parse_fun_literal_arg
      check :IDENT
      name = @token.value.to_s

      if @def_vars.last.includes?(name)
        raise "function argument '#{name}' shadows local variable '#{name}'"
      end

      next_token_skip_space_or_newline

      check :":"
      next_token_skip_space_or_newline

      type = parse_single_type

      if @token.type == :","
        next_token_skip_space_or_newline
      end

      Arg.new(name, nil, type)
    end

    def parse_fun_pointer
      location = @token.location

      case @token.type
      when :IDENT
        name = @token.value.to_s
        next_token_skip_space
        if @token.type == :"."
          next_token_skip_space
          check :IDENT
          if name != "self" && !@def_vars.last.includes?(name)
            raise "undefined variable '#{name}'", location.line_number, location.column_number
          end
          obj = Var.new(name)
          name = @token.value.to_s
          next_token_skip_space
        end
      when :CONST
        obj = parse_ident
        check :"."
        next_token_skip_space
        check :IDENT
        name = @token.value.to_s
        next_token_skip_space
      else
        unexpected_token
      end

      if @token.type == :"."
        unexpected_token
      end

      if @token.type == :"("
        next_token_skip_space
        types = parse_types
        check :")"
        next_token_skip_space
      else
        types = [] of ASTNode
      end

      FunPointer.new(obj, name.not_nil!, types)
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
      strings = [] of ASTNode

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
        of = parse_single_type
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
        of_key = parse_single_type
        check :"=>"
        next_token_skip_space_or_newline
        of_value = parse_single_type
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

      raise "Bug: string is nil" unless string

      skip_space

      if @token.keyword?(:if)
        next_token_skip_space
        cond = parse_require_or
      end

      Crystal::Require.new string, cond
    end

    parse_operator :require_or, :require_and, "Or.new left, right", ":\"||\""
    parse_operator :require_and, :require_atomic, "And.new left, right", ":\"&&\""

    def parse_require_atomic
      case @token.type
      when :"("
        next_token_skip_space
        if @token.type == :")"
          raise "unexpected token: #{@token}"
        end

        atomic = parse_require_or
        skip_space

        check :")"
        next_token_skip_space

        return atomic
      when :"!"
        next_token_skip_space
        return Not.new(parse_require_atomic)
      when :IDENT
        str = @token.to_s
        next_token_skip_space
        return Var.new(str)
      else
        raise "unexpected token: #{@token}"
      end
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
      @calls_super = false
      @uses_block_arg = false
      @block_arg_name = nil
      a_def = parse_def_or_macro Def
      a_def.instance_vars = @instance_vars
      a_def.calls_super = @calls_super
      a_def.uses_block_arg = @uses_block_arg
      @instance_vars = nil
      @calls_super = false
      @uses_block_arg = false
      @block_arg_name = nil
      a_def
    end

    def parse_macro
      parse_def_or_macro Crystal::Macro
    end

    DefOrMacroCheck1 = [:IDENT, :CONST, :"=", :"<<", :"<", :"<=", :"==", :"===", :"!=", :"=~", :">>", :">", :">=", :"+", :"-", :"*", :"/", :"%", :"+@", :"-@", :"~@", :"!@", :"&", :"|", :"^", :"**", :"[]", :"[]=", :"<=>", :"[]?"]
    DefOrMacroCheck2 = [:IDENT, :"=", :"<<", :"<", :"<=", :"==", :"===", :"!=", :"=~", :">>", :">", :">=", :"+", :"-", :"*", :"/", :"%", :"+@", :"-@", :"~@", :"!@", :"&", :"|", :"^", :"**", :"[]", :"[]=", :"<=>"]

    def parse_def_or_macro(klass)
      push_def

      next_token

      case @buffer.value
      when '%'
        @buffer += 1
        @token.type = :"%"
        @token.column_number += 1
      when '/'
        @buffer += 1
        @token.type = :"/"
        @token.column_number += 1
      else
        skip_space_or_newline
        check DefOrMacroCheck1
      end

      receiver = nil
      @yields = nil
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
      ivar_assigns = [] of ASTNode

      if @token.type == :"."
        unless receiver
          if name
            receiver = Var.new name
          else
            raise "shouldn't reach this line"
          end
        end
        next_token_skip_space
        check DefOrMacroCheck2
        name = @token.type == :IDENT ? @token.value.to_s : @token.type.to_s
        name_column_number = @token.column_number
        next_token_skip_space
      else
        if receiver
          unexpected_token
        else
          raise "shouldn't reach this line" unless name
        end
        name ||= "" # TODO: this is to satisfy the compiler, fix
      end

      case @token.type
      when :"("
        next_token_skip_space_or_newline
        while @token.type != :")"
          block_arg = parse_arg(args, ivar_assigns, true)
          if block_arg
            if inputs = block_arg.type_spec.inputs
              @yields = inputs.length
            else
              @yields = 0
            end
            check :")"
            break
          end
        end
        next_token_skip_statement_end
      when :IDENT
        while @token.type != :NEWLINE && @token.type != :";"
          block_arg = parse_arg(args, ivar_assigns, false)
          if block_arg
            if inputs = block_arg.type_spec.inputs
              @yields = inputs.length
            else
              @yields = 0
            end
            break
          end
        end
        next_token_skip_statement_end
      else
        skip_statement_end
      end

      if @token.keyword?(:end)
        body = Expressions.from(ivar_assigns)
      else
        body = parse_expressions
        if ivar_assigns.length > 0
          exps = [] of ASTNode
          exps.concat ivar_assigns
          if body.is_a?(Expressions)
            exps.concat body.expressions
          else
            exps.push body
          end
          body = Expressions.from exps
        end
        body = parse_exception_handler body
      end

      next_token_skip_space

      pop_def

      node = klass.new name, args, body, receiver, block_arg, @yields
      node.name_column_number = name_column_number
      node
    end

    def parse_arg(args, ivar_assigns, parenthesis = false)
      if @token.type == :"&"
        next_token_skip_space_or_newline
        return parse_block_arg
      end

      case @token.type
      when :IDENT
        arg_name = @token.value.to_s
        arg_location = @token.location
      when :INSTANCE_VAR
        arg_name = @token.value.to_s[1 .. -1]
        arg_location = @token.location
        ivar = InstanceVar.new(@token.value.to_s)
        ivar.location = arg_location
        var = Var.new(arg_name)
        var.location = arg_location
        assign = Assign.new(ivar, var)
        assign.location = arg_location
        if ivar_assigns
          ivar_assigns.push assign
        else
          raise "can't use @instance_variable here"
        end
        @instance_vars.add ivar.name if @instance_vars
      else
        raise "unexpected token: #{@token}"
      end

      default_value = nil
      type_restriction = nil

      if parenthesis
        next_token_skip_space_or_newline
      else
        next_token_skip_space
      end

      if @token.type == :"="
        next_token_skip_space_or_newline
        default_value = parse_expression
        skip_space
      end

      if @token.type == :":"
        next_token_skip_space_or_newline
        location = @token.location
        type_restriction = parse_single_type
      end

      raise "Bug: arg_name is nil" unless arg_name

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
      name = @token.value.to_s
      name_location = @token.location

      next_token_skip_space_or_newline

      inputs = nil
      output = nil

      if @token.type == :":"
        next_token_skip_space_or_newline

        location = @token.location

        type_spec = parse_single_type
        unless type_spec.is_a?(FunTypeSpec)
          raise "expected block argument type to be a function", location
        end
      else
        type_spec = FunTypeSpec.new
      end

      block_arg = BlockArg.new(name, type_spec)
      block_arg.location = name_location

      push_var block_arg

      @block_arg_name = block_arg.name

      block_arg
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

      node = Unless.new cond, a_then, a_else
      node.location = location
      node
    end

    def parse_var_or_call(global = false, force_call = false)
      name = @token.value.to_s
      name_column_number = @token.column_number

      if force_call && !@token.value
        name = @token.type.to_s
      end

      next_token

      @calls_super = true if name == "super"

      call_args = parse_call_args
      if call_args
        args = call_args.args
        block = call_args.block
        block_arg = call_args.block_arg
      end

      block = parse_block(block)

      if block || block_arg || global
        Call.new nil, name, (args || [] of ASTNode), block, block_arg, global, name_column_number, @last_call_has_parenthesis
      else
        if args
          if (!force_call && is_var?(name)) && args.length == 1 && (num = args[0]) && (num.is_a?(NumberLiteral) && num.has_sign)
            sign = num.value[0].to_s
            num.value = num.value[1, num.value.length - 1]
            Call.new(Var.new(name), sign, args)
          else
            Call.new(nil, name, args, nil, block_arg, global, name_column_number, @last_call_has_parenthesis)
          end
        else
          if @token.type == :"::"
            if is_var? name
              raise "variable '#{name}' is already declared"
            end

            next_token_skip_space_or_newline
            declared_type = parse_ident
            declare_var = DeclareVar.new(name, declared_type)
            push_var declare_var
            declare_var
          elsif (!force_call && is_var?(name))
            if @block_arg_name && !@uses_block_arg && name == @block_arg_name
              @uses_block_arg = true
            end
            Var.new name
          else
            Call.new nil, name, [] of ASTNode, nil, block_arg, global, name_column_number, @last_call_has_parenthesis
          end
        end
      end
    end

    def parse_block(block)
      if @token.keyword?(:do)
        raise "block already specified with &" if block
        parse_block2 { check_ident :end }
      elsif @token.type == :"{"
        raise "block already specified with &" if block
        parse_block2 { check :"}" }
      else
        block
      end
    end

    def parse_block2
      block_args = [] of Var
      block_body = nil

      next_token_skip_space
      if @token.type == :"|"
        next_token_skip_space_or_newline
        while @token.type != :"|"
          check :IDENT

          var = Var.new(@token.value.to_s)
          var.location = @token.location
          if @def_vars.last.includes?(var.name)
            raise "block argument '#{var.name}' shadows local variable '#{var.name}'"
          end

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

      current_vars = @def_vars.last.dup
      push_def current_vars
      push_vars block_args

      block_body = parse_expressions

      pop_def

      yield

      next_token_skip_space

      Block.new(block_args, block_body)
    end

    class CallArgs
      getter :args
      getter :block
      getter :block_arg

      def initialize(@args, @block = nil, @block_arg = nil)
      end
    end

    def parse_call_args
      case @token.type
      when :"{"
        @last_call_has_parenthesis = false
        nil
      when :"("
        args = [] of ASTNode
        next_token_skip_space_or_newline
        while @token.type != :")"
          if @token.type == :"&"
            unless @buffer.value.whitespace?
              return parse_call_block_arg(args, true)
            end
          end

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
        CallArgs.new args
      when :SPACE
        next_token
        @last_call_has_parenthesis = false
        parse_call_args_space_consumed
      else
        @last_call_has_parenthesis = false
        nil
      end
    end

    def parse_call_args_space_consumed(check_plus_and_minus = true, allow_curly = false)
      case @token.type
      when :"&"
        return nil if @buffer.value.whitespace?
      when :"+", :"-"
        if check_plus_and_minus
          return nil if @buffer.value.whitespace?
        end
      when :"{"
        return nil unless allow_curly
      when :CHAR, :STRING, :STRING_START, :STRING_ARRAY_START, :NUMBER, :IDENT, :SYMBOL, :INSTANCE_VAR, :CLASS_VAR, :CONST, :GLOBAL, :GLOBAL_MATCH, :REGEXP, :"(", :"!", :"[", :"[]", :"+", :"-", :"&", :"->"
        # Nothing
      else
        return nil
      end

      case @token.value
      when :if, :unless, :while
        return nil
      end

      args = [] of ASTNode
      while @token.type != :NEWLINE && @token.type != :";" && @token.type != :EOF && @token.type != :")" && @token.type != :":" && !is_end_token
        if @token.type == :"&"
          unless @buffer.value.whitespace?
            return parse_call_block_arg(args, false)
          end
        end

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
      CallArgs.new args
    end

    def parse_ident_or_global_call
      location = @token.location
      next_token_skip_space_or_newline

      case @token.type
      when :IDENT
        parse_var_or_call(true)
      when :CONST
        parse_ident_after_colons(location, true, true)
      else
        unexpected_token
      end
    end

    def parse_ident(allow_type_vars = true)
      location = @token.location

      global = false

      if @token.type == :"::"
        global = true
        next_token_skip_space_or_newline
      end

      check :CONST
      parse_ident_after_colons(location, global, allow_type_vars)
    end

    def parse_ident_after_colons(location, global, allow_type_vars)
      start_line = location.line_number
      start_column = location.column_number

      names = [] of String
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

      token_location = @token.location
      if token_location && token_location.line_number == start_line
        const.name_length = token_location.column_number - start_column
      end

      if allow_type_vars && @token.type == :"("
        next_token_skip_space

        types = parse_types
        if types.empty?
          raise "must specify at least one type var"
        end

        check :")"
        next_token_skip_space

        const = NewGenericClass.new const, types
        const.location = location
      end

      const
    end

    def parse_types
      type = parse_type
      case type
      when Array
        type
      when ASTNode
        [type] of ASTNode
      else
        raise "Bug"
      end
    end

    def parse_single_type
      location = @token.location
      type = parse_type
      case type
      when Array
        raise "unexpected ',' in type (use parenthesis to disambiguate)", location
      when ASTNode
        type
      else
        raise "Bug"
      end
    end

    def parse_type
      location = @token.location

      if @token.type == :"->"
        input_types = nil
      else
        input_types = parse_type_union
        input_types = [input_types] unless input_types.is_a?(Array)
        if @token.type == :"," && next_comes_uppercase
          while @token.type == :"," && next_comes_uppercase
            next_token_skip_space_or_newline
            type_union = parse_type_union
            if type_union.is_a?(Array)
              input_types.concat type_union
            else
              input_types << type_union
            end
          end
        end
      end

      if @token.type == :"->"
        next_token_skip_space
        case @token.type
        when :",", :")"
          return_type = nil
        when :NEWLINE
          skip_space_or_newline
          return_type = nil
        else
          type_union = parse_type_union
          if type_union.is_a?(Array)
            raise "can't return more than more type", location.line_number, location.column_number
          else
            return_type = type_union
          end
        end
        type = FunTypeSpec.new(input_types, return_type)
        type.location = location
        type
      else
        input_types = input_types.not_nil!
        if input_types.length == 1
          input_types.first
        else
          input_types
        end
      end
    end

    def parse_type_union
      types = [] of ASTNode
      parse_type_with_suffix(types)
      if @token.type == :"|"
        while @token.type == :"|"
          next_token_skip_space_or_newline
          parse_type_with_suffix(types)
        end

        if types.length == 1
          types.first
        else
          IdentUnion.new types
        end
      elsif types.length == 1
        types.first
      else
        types
      end
    end

    def parse_type_with_suffix(types)
      if @token.keyword?("self")
        type = SelfType.new
        next_token_skip_space
        types << type
        return
      end

      if @token.type == :"("
        next_token_skip_space_or_newline
        type = parse_type
        check :")"
        next_token_skip_space
        case type
        when Array
          types.concat type
        when ASTNode
          types << type
        else
          raise "Bug"
        end
        return
      end

      type = parse_ident

      skip_space

      while true
        case @token.type
        when :"?"
          type = IdentUnion.new([type, Ident.new(["Nil"], true)] of ASTNode)
          next_token_skip_space_or_newline
        when :"*"
          type = make_pointer_type(type)
          next_token_skip_space_or_newline
        when :"**"
          type = make_pointer_type(make_pointer_type(type))
          next_token_skip_space_or_newline
        else
          break
        end
      end

      types << type
    end

    def make_pointer_type(node)
      NewGenericClass.new(Ident.new(["Pointer"], true), [node] of ASTNode)
    end

    def parse_yield
      next_token

      call_args = parse_call_args
      args = call_args.args if call_args

      yields = (@yields ||= 0)
      if args && args.length > yields
        @yields = args.length
      end

      location = @token.location
      node = Yield.new(args || [] of ASTNode)
      node.location = location
      node
    end

    def parse_break
      next_token

      call_args = parse_call_args
      args = call_args.args if call_args

      location = @token.location
      node = Break.new(args || [] of ASTNode)
      node.location = location
      node
    end

    def parse_return
      next_token

      call_args = parse_call_args
      args = call_args.args if call_args

      location = @token.location
      node = Return.new(args || [] of ASTNode)
      node.location = location
      node
    end

    def parse_next
      next_token

      call_args = parse_call_args
      args = call_args.args if call_args

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
        when :GLOBAL
          name = @token.value.to_s[1 .. -1]
          next_token_skip_space_or_newline
          check :":"
          next_token_skip_space_or_newline
          type = parse_single_type
          skip_statement_end
          expressions << ExternalVar.new(name, type)
        else
          break
        end
      end
      expressions
    end

    IdentOrConst = [:IDENT, :CONST]

    def parse_fun_def(require_body = false)
      push_def if require_body

      next_token_skip_space_or_newline

      check :IDENT
      name = @token.value.to_s

      next_token_skip_space_or_newline

      if @token.type == :"="
        next_token_skip_space_or_newline
        check IdentOrConst
        real_name = @token.value.to_s
        next_token_skip_space_or_newline
      else
        real_name = name
      end

      args = [] of Arg
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

          if @token.type == :IDENT
            arg_name = @token.value.to_s
            arg_location = @token.location

            next_token_skip_space_or_newline
            check :":"
            next_token_skip_space_or_newline

            arg_type = parse_single_type

            skip_space_or_newline

            arg = Arg.new(arg_name, nil, arg_type)
            arg.location = arg_location
            args << arg

            push_var_name arg_name if require_body
          else
            arg_types = parse_types
            arg_types.each do |arg_type_2|
              arg2 = Arg.new("?", nil, arg_type_2)
              arg2.location = arg_type_2.location
              args << arg2
            end
          end

          if @token.type == :","
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_statement_end
      end

      if @token.type == :":"
        next_token_skip_space_or_newline
        return_type = parse_single_type
      end

      skip_statement_end

      if require_body
        if @token.keyword?(:end)
          body = Nop.new
        else
          body = parse_expressions
          body = parse_exception_handler body
        end

        next_token_skip_space
      else
        body = nil
      end

      pop_def if require_body

      FunDef.new name, args, return_type, varargs, body, real_name
    end

    def parse_type_def
      next_token_skip_space_or_newline

      check :CONST
      name = @token.value.to_s
      name_column_number = @token.column_number
      next_token_skip_space_or_newline

      check :":"
      next_token_skip_space_or_newline

      type = parse_single_type

      skip_statement_end

      TypeDef.new name, type, name_column_number
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
      fields = [] of Arg

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

            type = parse_single_type

            skip_statement_end

            names.each do |name|
              fields << Arg.new(name, nil, type)
            end
          end
        else
          break
        end
      end

      fields
    end

    def parse_enum
      next_token_skip_space_or_newline

      check :CONST
      name = @token.value.to_s
      next_token_skip_statement_end

      constants = [] of Arg
      while !@token.keyword?(:end)
        check :CONST

        constant_name = @token.value.to_s
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
      case node
      when Var, InstanceVar, ClassVar, Ident, Global
        true
      when Call
        (node.obj.nil? && node.args.length == 0 && node.block.nil?) || node.name == "[]"
      else
        false
      end
    end

    def push_def
      @def_vars.push(Set(String).new)
    end

    def pop_def
      @def_vars.pop
    end

    def push_def(args)
      push_def(Set.new(args.map { |arg| arg.name }))
      ret = yield
      pop_def
      ret
    end

    def push_def(set)
      @def_vars.push(set)
    end

    def push_vars(vars)
      vars.each do |var|
        push_var var
      end
    end

    def push_var(var : Var | Arg | DeclareVar | BlockArg)
      push_var_name var.name.to_s
    end

    def push_var_name(name)
      @def_vars.last.add name
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
