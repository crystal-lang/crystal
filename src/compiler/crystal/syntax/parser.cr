require "set"
require "./ast"
require "./lexer"

module Crystal
  class Parser < Lexer
    record Unclosed, name, location

    property visibility
    property def_nest
    property type_nest
    getter? wants_doc

    def self.parse(str, def_vars = [Set(String).new])
      new(str, def_vars).parse
    end

    def initialize(str, @def_vars = [Set(String).new])
      super(str)
      @last_call_has_parenthesis = true
      @temp_token = Token.new
      @unclosed_stack = [] of Unclosed
      @calls_super = false
      @calls_initialize = false
      @uses_block_arg = false
      @assigns_special_var = false
      @def_nest = 0
      @type_nest = 0
      @block_arg_count = 0
      @in_macro_expression = false
      @stop_on_yield = 0
      @inside_c_struct = false
      @wants_doc = false
      @no_type_declaration = 0
    end

    def wants_doc=(@wants_doc)
      @doc_enabled = @wants_doc
    end

    def parse
      next_token_skip_statement_end

      expressions = parse_expressions.tap { check :EOF }

      check :EOF

      expressions
    end

    def parse_expressions
      value, _ = preserve_last_call_has_parenthesis do
        @last_call_has_parenthesis = true
        parse_expressions_internal
      end
      value
    end

    def parse_expressions_internal
      if is_end_token
        return Nop.new
      end

      exp = parse_multi_assign

      slash_is_regex!
      skip_statement_end

      if is_end_token
        return exp
      end

      exps = [] of ASTNode
      exps.push exp

      loop do
        exps << parse_multi_assign
        skip_statement_end
        break if is_end_token
      end

      Expressions.from(exps)
    end

    def parse_multi_assign
      location = @token.location

      last = parse_expression
      skip_space

      case @token.type
      when :","
        # Continue
      when :NEWLINE, :";"
        return last
      else
        if is_end_token
          return last
        else
          unexpected_token
        end
      end

      exps = [] of ASTNode
      exps << last

      i = 0
      assign_index = -1

      while @token.type == :","
        if assign_index == -1 && is_multi_assign_middle?(last)
          assign_index = i
        end

        i += 1

        next_token_skip_space_or_newline
        exps << (last = parse_op_assign(allow_ops: false))
        skip_space
      end

      if assign_index == -1 && is_multi_assign_middle?(last)
        assign_index = i
      end

      if assign_index == -1
        unexpected_token
      end

      targets = exps[0...assign_index].map { |exp| to_lhs(exp) }
      if ivars = @instance_vars
        targets.each do |target|
          ivars.add target.name if target.is_a?(InstanceVar)
        end
      end

      assign = exps[assign_index]
      values = [] of ASTNode

      case assign
      when Assign
        targets << to_lhs(assign.target)
        values << assign.value
      when Call
        assign.name = assign.name.byte_slice(0, assign.name.bytesize - 1)
        targets << assign
        values << assign.args.pop
      else
        raise "Bug: mutliassign index expression can only be Assign or Call"
      end

      values.concat exps[assign_index + 1..-1]
      if values.size != 1 && targets.size != 1 && targets.size != values.size
        raise "Multiple assignment count mismatch", location
      end

      multi = MultiAssign.new(targets, values).at(location)
      parse_expression_suffix multi, @token.location
    end

    def is_multi_assign_middle?(exp)
      case exp
      when Assign
        true
      when Call
        exp.name.ends_with? '='
      else
        false
      end
    end

    def to_lhs(exp)
      if exp.is_a?(Path) && inside_def?
        raise "dynamic constant assignment"
      end

      if exp.is_a?(Call) && !exp.obj && exp.args.empty?
        exp = Var.new(exp.name).at(exp)
      end
      if exp.is_a?(Var)
        if exp.name == "self"
          raise "can't change the value of self", exp.location.not_nil!
        end
        push_var exp
      end
      exp
    end

    def parse_expression
      location = @token.location
      atomic = parse_op_assign
      parse_expression_suffix atomic, location
    end

    def parse_expression_suffix(atomic, location)
      while true
        case @token.type
        when :SPACE
          next_token
        when :IDENT
          case @token.value
          when :if
            atomic = parse_expression_suffix(location) { |exp| If.new(exp, atomic) }
          when :unless
            atomic = parse_expression_suffix(location) { |exp| Unless.new(exp, atomic) }
          when :while
            raise "trailing `while` is not supported", @token
          when :until
            raise "trailing `until` is not supported", @token
          when :rescue
            next_token_skip_space
            rescue_body = parse_expression
            rescues = [Rescue.new(rescue_body)] of Rescue
            if atomic.is_a?(Assign)
              atomic.value = ExceptionHandler.new(atomic.value, rescues).at(location).tap { |e| e.suffix = true }
            else
              atomic = ExceptionHandler.new(atomic, rescues).at(location).tap { |e| e.suffix = true }
            end
          when :ensure
            next_token_skip_space
            ensure_body = parse_expression
            if atomic.is_a?(Assign)
              atomic.value = ExceptionHandler.new(atomic.value, ensure: ensure_body).at(location)
            else
              atomic = ExceptionHandler.new(atomic, ensure: ensure_body).at(location)
            end
          when :ifdef
            next_token_skip_statement_end
            exp = parse_flags_or
            atomic = IfDef.new(exp, atomic).at(location)
          else
            break
          end
        when :")", :",", :";", :"%}", :"}}", :NEWLINE, :EOF
          break
        else
          if is_end_token
            break
          else
            unexpected_token
          end
        end
      end
      atomic
    end

    def parse_expression_suffix(location)
      next_token_skip_statement_end
      exp = parse_op_assign_no_control
      (yield exp).at(location).at_end(exp)
    end

    def parse_op_assign_no_control(allow_ops = true, allow_suffix = true)
      check_void_expression_keyword
      parse_op_assign(allow_ops, allow_suffix)
    end

    def parse_op_assign(allow_ops = true, allow_suffix = true)
      doc = @token.doc
      location = @token.location

      atomic = parse_question_colon

      while true
        case @token.type
        when :SPACE
          next_token
          next
        when :IDENT
          unexpected_token unless allow_suffix
          break
        when :"="
          slash_is_regex!

          if atomic.is_a?(Call) && atomic.name == "[]"
            next_token_skip_space_or_newline

            atomic.name = "[]="
            atomic.name_size = 0
            atomic.args << parse_op_assign_no_control
          else
            break unless can_be_assigned?(atomic)

            if atomic.is_a?(Path) && inside_def?
              raise "dynamic constant assignment"
            end

            if atomic.is_a?(Var) && atomic.name == "self"
              raise "can't change the value of self", location
            end

            atomic = Var.new(atomic.name) if atomic.is_a?(Call)

            next_token_skip_space_or_newline

            # Constants need a new scope for their value
            case atomic
            when Path
              needs_new_scope = true
            when InstanceVar
              needs_new_scope = @def_nest == 0
            when Var
              @assigns_special_var = true if atomic.special_var?
            else
              needs_new_scope = false
            end

            push_def if needs_new_scope

            if @token.keyword?(:uninitialized) && (atomic.is_a?(Var) || atomic.is_a?(InstanceVar))
              push_var atomic
              next_token_skip_space
              type = parse_single_type
              atomic = UninitializedVar.new(atomic, type).at(location)
              return atomic
            else
              value = parse_op_assign_no_control
            end

            pop_def if needs_new_scope

            push_var atomic

            atomic = Assign.new(atomic, value).at(location)
            atomic.doc = doc
            atomic
          end
        when :"+=", :"-=", :"*=", :"/=", :"%=", :"|=", :"&=", :"^=", :"**=", :"<<=", :">>=", :"||=", :"&&="
          # Rewrite 'a += b' as 'a = a + b'

          unexpected_token unless allow_ops

          break unless can_be_assigned?(atomic)

          if atomic.is_a?(Path)
            raise "can't reassign to constant"
          end

          if atomic.is_a?(Var) && atomic.name == "self"
            raise "can't change the value of self", location
          end

          if atomic.is_a?(Call) && atomic.name != "[]" && !@def_vars.last.includes?(atomic.name)
            raise "'#{@token.type}' before definition of '#{atomic.name}'"

            atomic = Var.new(atomic.name)
          end

          push_var atomic

          method = @token.type.to_s.byte_slice(0, @token.to_s.bytesize - 1)
          method_column_number = @token.column_number

          token_type = @token.type

          next_token_skip_space_or_newline

          value = parse_op_assign_no_control

          if atomic.is_a?(Call) && atomic.name == "[]"
            obj = atomic.obj
            atomic_clone = atomic.clone

            case token_type
            when :"&&="
              atomic.args.push value
              assign = Call.new(obj, "[]=", atomic.args, name_column_number: method_column_number).at(location)
              fetch = atomic_clone
              fetch.name = "[]?"
              atomic = And.new(fetch, assign).at(location)
            when :"||="
              atomic.args.push value
              assign = Call.new(obj, "[]=", atomic.args, name_column_number: method_column_number).at(location)
              fetch = atomic_clone
              fetch.name = "[]?"
              atomic = Or.new(fetch, assign).at(location)
            else
              call = Call.new(atomic_clone, method, [value] of ASTNode, name_column_number: method_column_number).at(location)
              atomic.args.push call
              atomic = Call.new(obj, "[]=", atomic.args, name_column_number: method_column_number).at(location)
            end
          else
            case token_type
            when :"&&="
              if (ivars = @instance_vars) && atomic.is_a?(InstanceVar)
                ivars.add atomic.name
              end

              assign = Assign.new(atomic, value).at(location)
              atomic = And.new(atomic.clone, assign).at(location)
            when :"||="
              if (ivars = @instance_vars) && atomic.is_a?(InstanceVar)
                ivars.add atomic.name
              end

              assign = Assign.new(atomic, value).at(location)
              atomic = Or.new(atomic.clone, assign).at(location)
            else
              call = Call.new(atomic, method, [value] of ASTNode, name_column_number: method_column_number).at(location)
              atomic = Assign.new(atomic.clone, call).at(location)
            end
          end
        else
          break
        end
        allow_ops = true
      end

      atomic
    end

    ColonOrNewline = [:":", :NEWLINE]

    def parse_question_colon
      cond = parse_range

      while @token.type == :"?"
        location = @token.location

        check_void_value cond, location

        next_token_skip_space_or_newline
        next_token_skip_space_or_newline if @token.type == :":"

        @no_type_declaration += 1
        true_val = parse_question_colon
        check ColonOrNewline

        next_token_skip_space_or_newline
        next_token_skip_space_or_newline if @token.type == :":"

        false_val = parse_question_colon
        @no_type_declaration -= 1

        cond = If.new(cond, true_val, false_val)
      end

      cond
    end

    def parse_range
      location = @token.location
      exp = parse_or
      while true
        case @token.type
        when :".."
          exp = new_range(exp, location, false)
        when :"..."
          exp = new_range(exp, location, true)
        else
          return exp
        end
      end
    end

    def new_range(exp, location, exclusive)
      check_void_value exp, location
      next_token_skip_space_or_newline
      check_void_expression_keyword
      right = parse_or
      RangeLiteral.new(exp, right, exclusive).at(location).at_end(right)
    end

    macro parse_operator(name, next_operator, node, operators)
      def parse_{{name.id}}
        location = @token.location

        left = parse_{{next_operator.id}}
        while true
          case @token.type
          when :SPACE
            next_token
          when {{operators.id}}
            check_void_value left, location

            method = @token.type.to_s
            method_column_number = @token.column_number

            slash_is_regex!
            next_token_skip_space_or_newline
            right = parse_{{next_operator.id}}
            left = ({{node.id}}).at(location).at_end(right)
          else
            return left
          end
        end
      end
    end

    parse_operator :or, :and, "Or.new left, right", ":\"||\""
    parse_operator :and, :equality, "And.new left, right", ":\"&&\""
    parse_operator :equality, :cmp, "Call.new left, method, [right] of ASTNode, name_column_number: method_column_number", ":\"<\", :\"<=\", :\">\", :\">=\", :\"<=>\""
    parse_operator :cmp, :logical_or, "Call.new left, method, [right] of ASTNode, name_column_number: method_column_number", ":\"==\", :\"!=\", :\"=~\", :\"!~\", :\"===\""
    parse_operator :logical_or, :logical_and, "Call.new left, method, [right] of ASTNode, name_column_number: method_column_number", ":\"|\", :\"^\""
    parse_operator :logical_and, :shift, "Call.new left, method, [right] of ASTNode, name_column_number: method_column_number", ":\"&\""
    parse_operator :shift, :add_or_sub, "Call.new left, method, [right] of ASTNode, name_column_number: method_column_number", ":\"<<\", :\">>\""

    def parse_add_or_sub
      location = @token.location

      left = parse_mul_or_div
      while true
        case @token.type
        when :SPACE
          next_token
        when :"+", :"-"
          check_void_value left, location

          method = @token.type.to_s
          method_column_number = @token.column_number
          next_token_skip_space_or_newline
          right = parse_mul_or_div
          left = Call.new(left, method, [right] of ASTNode, name_column_number: method_column_number).at(location).at_end(right)
        when :NUMBER
          case char = @token.value.to_s[0]
          when '+', '-'
            method = char.to_s
            method_column_number = @token.column_number

            # Go back to the +/-, advance one char and continue from there
            self.current_pos = @token.start + 1
            next_token

            right = parse_mul_or_div
            left = Call.new(left, method, [right] of ASTNode, name_column_number: method_column_number).at(location).at_end(right)
          else
            return left
          end
        else
          return left
        end
      end
    end

    parse_operator :mul_or_div, :prefix, "Call.new left, method, [right] of ASTNode, name_column_number: method_column_number", ":\"*\", :\"/\", :\"%\""

    def parse_prefix
      column_number = @token.column_number
      case token_type = @token.type
      when :"!", :"+", :"-", :"~"
        location = @token.location
        next_token_skip_space_or_newline
        check_void_expression_keyword
        arg = parse_prefix
        Call.new(arg, token_type.to_s, name_column_number: column_number).at(location).at_end(arg)
      else
        parse_pow
      end
    end

    parse_operator :pow, :atomic_with_method, "Call.new left, method, [right] of ASTNode, name_column_number: method_column_number", ":\"**\""

    AtomicWithMethodCheck = [:IDENT, :"+", :"-", :"*", :"/", :"%", :"|", :"&", :"^", :"**", :"<<", :"<", :"<=", :"==", :"!=", :"=~", :"!~", :">>", :">", :">=", :"<=>", :"||", :"&&", :"===", :"[]", :"[]=", :"[]?", :"!"]

    def parse_atomic_with_method
      location = @token.location
      atomic = parse_atomic
      parse_atomic_method_suffix atomic, location
    end

    def parse_atomic_method_suffix(atomic, location)
      while true
        case @token.type
        when :SPACE
          next_token
        when :IDENT
          if @token.keyword?(:as)
            check_void_value atomic, location

            next_token_skip_space
            to = parse_single_type(allow_commas: false)
            atomic = Cast.new(atomic, to).at(location)
          else
            break
          end
        when :NEWLINE
          # In these cases we don't want to chain a call
          case atomic
          when ClassDef, ModuleDef, EnumDef, FunDef, Def
            break
          end

          # Allow '.' after newline for chaining calls
          old_pos, old_line, old_column = current_pos, @line_number, @column_number
          @temp_token.copy_from @token
          next_token_skip_space_or_newline
          unless @token.type == :"."
            self.current_pos, @line_number, @column_number = old_pos, old_line, old_column
            @token.copy_from @temp_token
            break
          end
        when :"."
          check_void_value atomic, location

          @wants_regex = false

          if current_char == '%'
            next_char
            @token.type = :"%"
            @token.column_number += 1
            skip_space_or_newline
          else
            next_token_skip_space_or_newline

            if @token.type == :INSTANCE_VAR
              ivar_name = @token.value.to_s
              end_location = token_end_location
              next_token_skip_space

              atomic = ReadInstanceVar.new(atomic, ivar_name).at(location)
              atomic.end_location = end_location
              next
            end
          end

          check AtomicWithMethodCheck
          name_column_number = @token.column_number

          if @token.value == :is_a?
            atomic = parse_is_a(atomic).at(location)
          elsif @token.value == :responds_to?
            atomic = parse_responds_to(atomic).at(location)
          else
            name = @token.type == :IDENT ? @token.value.to_s : @token.type.to_s
            end_location = token_end_location

            @wants_regex = false
            next_token

            space_consumed = false
            if @token.type == :SPACE
              @wants_regex = true
              next_token
              space_consumed = true
            end

            case @token.type
            when :"="
              # Rewrite 'f.x = arg' as f.x=(arg)
              next_token

              if @token.type == :"("
                next_token_skip_space
                arg = parse_single_arg
                check :")"
                next_token
              else
                skip_space_or_newline
                arg = parse_single_arg
              end

              atomic = Call.new(atomic, "#{name}=", [arg] of ASTNode, name_column_number: name_column_number).at(location)
              next
            when :"+=", :"-=", :"*=", :"/=", :"%=", :"|=", :"&=", :"^=", :"**=", :"<<=", :">>="
              # Rewrite 'f.x += value' as 'f.x=(f.x + value)'
              method = @token.type.to_s.byte_slice(0, @token.type.to_s.size - 1)
              next_token_skip_space_or_newline
              value = parse_op_assign
              atomic = Call.new(atomic, "#{name}=", [Call.new(Call.new(atomic.clone, name, name_column_number: name_column_number), method, [value] of ASTNode, name_column_number: name_column_number)] of ASTNode, name_column_number: name_column_number).at(location)
              next
            when :"||="
              # Rewrite 'f.x ||= value' as 'f.x || f.x=(value)'
              next_token_skip_space_or_newline
              value = parse_op_assign

              atomic = Or.new(
                Call.new(atomic, name).at(location),
                Call.new(atomic.clone, "#{name}=", value).at(location)
              ).at(location)
              next
            when :"&&="
              # Rewrite 'f.x &&= value' as 'f.x && f.x=(value)'
              next_token_skip_space
              value = parse_op_assign

              atomic = And.new(
                Call.new(atomic, name).at(location),
                Call.new(atomic.clone, "#{name}=", value).at(location)
              ).at(location)
              next
            else
              call_args, last_call_has_parenthesis = preserve_last_call_has_parenthesis { space_consumed ? parse_call_args_space_consumed : parse_call_args }
              if call_args
                args = call_args.args
                block = call_args.block
                block_arg = call_args.block_arg
                named_args = call_args.named_args
              else
                args = block = block_arg = nil
              end
            end

            block = parse_block(block, stop_on_do: space_consumed && !@last_call_has_parenthesis)
            if block || block_arg
              atomic = Call.new atomic, name, (args || [] of ASTNode), block, block_arg, named_args, name_column_number: name_column_number
            else
              atomic = args ? (Call.new atomic, name, args, named_args: named_args, name_column_number: name_column_number) : (Call.new atomic, name, name_column_number: name_column_number)
            end
            atomic.end_location = call_args.try(&.end_location) || block.try(&.end_location) || end_location
            atomic.at(location)
            atomic
          end
        when :"[]"
          check_void_value atomic, location

          column_number = @token.column_number
          next_token_skip_space
          atomic = Call.new(atomic, "[]", name_column_number: column_number).at(location)
          atomic.name_size = 0 if atomic.is_a?(Call)
          atomic
        when :"["
          check_void_value atomic, location

          column_number = @token.column_number
          next_token_skip_space_or_newline
          args = [] of ASTNode
          while true
            args << parse_single_arg
            skip_space_or_newline
            case @token.type
            when :","
              next_token_skip_space_or_newline
              if @token.type == :"]"
                next_token
                break
              end
            when :"]"
              next_token
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

          atomic = Call.new(atomic, method_name, args, name_column_number: column_number).at(location)
          atomic.name_size = 0 if atomic.is_a?(Call)
          atomic
        else
          break
        end
      end

      atomic
    end

    def parse_single_arg
      if @token.type == :"*"
        next_token_skip_space
        arg = parse_op_assign_no_control
        Splat.new(arg)
      else
        parse_op_assign_no_control
      end
    end

    def parse_is_a(atomic)
      next_token_skip_space

      if @token.type == :"("
        next_token_skip_space_or_newline
        type = parse_single_type
        skip_space
        check :")"
        next_token_skip_space
      else
        type = parse_single_type
      end

      IsA.new(atomic, type)
    end

    def parse_responds_to(atomic)
      next_token

      if @token.type == :"("
        next_token_skip_space_or_newline
        name = parse_responds_to_name
        next_token_skip_space_or_newline
        check :")"
        next_token_skip_space
      elsif @token.type == :SPACE
        next_token
        name = parse_responds_to_name
        next_token_skip_space
      else
        unexpected_token msg: "expected space or '('"
      end

      RespondsTo.new(atomic, name)
    end

    def parse_responds_to_name
      if @token.type != :SYMBOL
        unexpected_token msg: "expected name or symbol"
      end

      @token.value.to_s
    end

    def parse_atomic
      location = @token.location
      atomic = parse_atomic_without_location
      atomic.location ||= location
      atomic
    end

    def parse_atomic_without_location
      case @token.type
      when :"("
        parse_parenthesized_expression
      when :"[]"
        parse_empty_array_literal
      when :"["
        parse_array_literal
      when :"{"
        parse_hash_or_tuple_literal
      when :"{{"
        macro_exp = parse_macro_expression
        check_macro_expression_end
        next_token
        MacroExpression.new(macro_exp)
      when :"{%"
        macro_control = parse_macro_control(@line_number, @column_number)
        if macro_control
          check :"%}"
          next_token_skip_space
          macro_control
        else
          unexpected_token_in_atomic
        end
      when :"::"
        parse_ident_or_global_call
      when :"->"
        parse_fun_literal
      when :"@["
        parse_attribute
      when :NUMBER
        @wants_regex = false
        node_and_next_token NumberLiteral.new(@token.value.to_s, @token.number_kind)
      when :CHAR
        node_and_next_token CharLiteral.new(@token.value as Char)
      when :STRING, :DELIMITER_START
        parse_delimiter
      when :STRING_ARRAY_START
        parse_string_array
      when :SYMBOL_ARRAY_START
        parse_symbol_array
      when :SYMBOL
        node_and_next_token SymbolLiteral.new(@token.value.to_s)
      when :GLOBAL
        new_node_check_type_declaration Global
      when :"$~", :"$?"
        location = @token.location
        var = Var.new(@token.to_s).at(location)

        old_pos, old_line, old_column = current_pos, @line_number, @column_number
        @temp_token.copy_from(@token)

        next_token_skip_space

        if @token.type == :"="
          @token.copy_from(@temp_token)
          self.current_pos, @line_number, @column_number = old_pos, old_line, old_column

          push_var var
          node_and_next_token var
        else
          @token.copy_from(@temp_token)
          self.current_pos, @line_number, @column_number = old_pos, old_line, old_column

          node_and_next_token Call.new(var, "not_nil!").at(location)
        end
      when :GLOBAL_MATCH_DATA_INDEX
        value = @token.value.to_s
        if value == "0"
          node_and_next_token Path.global("PROGRAM_NAME")
        else
          if value.ends_with? '?'
            method = "[]?"
            value = value.chop
          else
            method = "[]"
          end
          location = @token.location
          node_and_next_token Call.new(Call.new(Var.new("$~").at(location), "not_nil!").at(location), method, NumberLiteral.new(value.to_i))
        end
      when :__LINE__
        node_and_next_token MagicConstant.expand_line_node(@token.location)
      when :__FILE__
        node_and_next_token MagicConstant.expand_file_node(@token.location)
      when :__DIR__
        node_and_next_token MagicConstant.expand_dir_node(@token.location)
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
        when :with
          parse_yield_with_scope
        when :abstract
          check_not_inside_def("can't use abstract inside def") do
            doc = @token.doc

            next_token_skip_space_or_newline
            case @token.type
            when :IDENT
              case @token.value
              when :def
                parse_def is_abstract: true, doc: doc
              when :class
                parse_class_def is_abstract: true, doc: doc
              when :struct
                parse_class_def is_abstract: true, is_struct: true, doc: doc
              else
                unexpected_token
              end
            else
              unexpected_token
            end
          end
        when :def
          check_not_inside_def("can't define def inside def") do
            parse_def
          end
        when :macro
          check_not_inside_def("can't define macro inside def") do
            parse_macro
          end
        when :require
          parse_require
        when :case
          parse_case
        when :if
          parse_if
        when :ifdef
          parse_ifdef
        when :unless
          parse_unless
        when :include
          check_not_inside_def("can't include inside def") do
            parse_include
          end
        when :extend
          check_not_inside_def("can't extend inside def") do
            parse_extend
          end
        when :class
          check_not_inside_def("can't define class inside def") do
            parse_class_def
          end
        when :struct
          check_not_inside_def("can't define struct inside def") do
            parse_class_def is_struct: true
          end
        when :module
          check_not_inside_def("can't define module inside def") do
            parse_module_def
          end
        when :enum
          check_not_inside_def("can't define enum inside def") do
            parse_enum_def
          end
        when :while
          parse_while
        when :until
          parse_until
        when :return
          parse_return
        when :next
          parse_next
        when :break
          parse_break
        when :lib
          check_not_inside_def("can't define lib inside def") do
            parse_lib
          end
        when :fun
          check_not_inside_def("can't define fun inside def") do
            parse_fun_def require_body: true
          end
        when :alias
          check_not_inside_def("can't define alias inside def") do
            parse_alias
          end
        when :pointerof
          parse_pointerof
        when :sizeof
          parse_sizeof
        when :instance_sizeof
          parse_instance_sizeof
        when :typeof
          parse_typeof
        when :private
          parse_visibility_modifier :private
        when :protected
          parse_visibility_modifier :protected
        when :asm
          parse_asm
        else
          set_visibility parse_var_or_call
        end
      when :CONST
        parse_ident_or_literal
      when :INSTANCE_VAR
        new_node_check_type_declaration(InstanceVar) do |name|
          add_instance_var(name)
        end
      when :CLASS_VAR
        new_node_check_type_declaration ClassVar
      when :UNDERSCORE
        node_and_next_token Underscore.new
      else
        unexpected_token_in_atomic
      end
    end

    def new_node_check_type_declaration(klass)
      new_node_check_type_declaration(klass) { }
    end

    def new_node_check_type_declaration(klass)
      name = @token.value.to_s
      yield name
      var = klass.new(name).at(@token.location)
      var.end_location = token_end_location
      @wants_regex = false
      next_token_skip_space

      if @no_type_declaration == 0 && @token.type == :":"
        next_token_skip_space
        var_type = parse_single_type
        TypeDeclaration.new(var, var_type).at(var.location)
      else
        var
      end
    end

    def parse_ident_or_literal
      ident = parse_ident
      skip_space

      if @token.type == :"{"
        tuple_or_hash = parse_hash_or_tuple_literal allow_of: false

        skip_space

        if @token.keyword?(:"of")
          unexpected_token
        end

        case tuple_or_hash
        when TupleLiteral
          ary = ArrayLiteral.new(tuple_or_hash.elements, name: ident).at(tuple_or_hash.location)
          return ary
        when HashLiteral
          tuple_or_hash.name = ident
          return tuple_or_hash
        else
          raise "Bug: tuple_or_hash should be tuple or hash, not #{tuple_or_hash}"
        end
      end
      ident
    end

    def check_not_inside_def(message)
      if @def_nest == 0
        yield
      else
        raise message, @token.line_number, @token.column_number
      end
    end

    def inside_def?
      @def_nest > 0
    end

    def parse_attribute
      doc = @token.doc

      next_token_skip_space
      name = check_const
      next_token_skip_space

      args = [] of ASTNode
      named_args = nil

      if @token.type == :"("
        open("attribute") do
          next_token_skip_space_or_newline
          while @token.type != :")"
            if @token.type == :IDENT && current_char == ':'
              named_args = parse_named_args(allow_newline: true)
              check :")"
              break
            else
              args << parse_call_arg
            end

            skip_space_or_newline
            if @token.type == :","
              next_token_skip_space_or_newline
            end
          end
          next_token_skip_space
        end
      end
      check :"]"
      next_token_skip_space

      attr = Attribute.new(name, args, named_args)
      attr.doc = doc
      attr
    end

    def parse_begin
      slash_is_regex!
      next_token_skip_statement_end
      exps = parse_expressions
      node, end_location = parse_exception_handler exps
      node.end_location = end_location
      if !node.is_a?(ExceptionHandler) && !node.is_a?(Expressions)
        node = Expressions.new([node]).at(node).at_end(node)
      end
      node.keyword = :begin if node.is_a?(Expressions)
      node
    end

    def parse_exception_handler(exp, implicit = false)
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
          raise "'else' is useless without 'rescue'", @token, 4
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

      end_location = token_end_location

      check_ident :end
      next_token_skip_space

      if rescues || a_ensure
        ex = ExceptionHandler.new(exp, rescues, a_else, a_ensure).at_end(end_location)
        ex.implicit = true if implicit
        {ex, end_location}
      else
        exp
        {exp, end_location}
      end
    end

    SemicolonOrNewLine = [:";", :NEWLINE]

    def parse_rescue
      next_token_skip_space

      case @token.type
      when :IDENT
        name = @token.value.to_s
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
      parse_while_or_until While
    end

    def parse_until
      parse_while_or_until Until
    end

    def parse_while_or_until(klass)
      slash_is_regex!
      next_token_skip_space_or_newline

      cond = parse_op_assign_no_control allow_suffix: false

      slash_is_regex!
      skip_statement_end

      body = parse_expressions
      skip_statement_end

      end_location = token_end_location
      check_ident :end
      next_token_skip_space

      klass.new(cond, body).at_end(end_location)
    end

    def call_block_arg_follows?
      @token.type == :"&" && !current_char.whitespace?
    end

    def parse_call_block_arg(args, check_paren, named_args = nil)
      location = @token.location

      next_token_skip_space

      if @token.type == :"."
        block_arg_name = "__arg#{@block_arg_count}"
        @block_arg_count += 1

        obj = Var.new(block_arg_name)
        @wants_regex = false
        next_token_skip_space

        location = @token.location

        if @token.value == :is_a?
          call = parse_is_a(obj).at(location)
        elsif @token.value == :responds_to?
          call = parse_responds_to(obj).at(location)
        elsif @token.type == :"["
          call = parse_atomic_method_suffix obj, location

          if @token.type == :"=" && call.is_a?(Call)
            next_token_skip_space
            exp = parse_op_assign
            call.name = "#{call.name}="
            call.args << exp
          end
        else
          # At this point we want to attach the "do" to the next call,
          # so we set this var to true to make the parser think the call
          # has parenthesis and so a "do" must be attached to it
          @last_call_has_parenthesis = true
          call = parse_var_or_call(force_call: true).at(location)

          if call.is_a?(Call)
            call.obj = obj
          else
            raise "Bug: #{call} should be a call"
          end

          call = call as Call

          if @token.type == :"="
            next_token_skip_space
            if @token.type == :"("
              next_token_skip_space
              exp = parse_op_assign
              check :")"
              next_token_skip_space
              call.name = "#{call.name}="
              call.args = [exp] of ASTNode
              call = parse_atomic_method_suffix call, location
            else
              exp = parse_op_assign
              call.name = "#{call.name}="
              call.args = [exp] of ASTNode
            end
          else
            call = parse_atomic_method_suffix call, location

            if @token.type == :"=" && call.is_a?(Call) && call.name == "[]"
              next_token_skip_space
              exp = parse_op_assign
              call.name = "#{call.name}="
              call.args << exp
            end
          end
        end

        block = Block.new([Var.new(block_arg_name)], call).at(location)
      else
        block_arg = parse_op_assign
      end

      end_location = token_end_location

      if check_paren
        check :")"
        next_token_skip_space
      else
        skip_space
      end

      CallArgs.new args, block, block_arg, named_args, false, end_location
    end

    def parse_class_def(is_abstract = false, is_struct = false, doc = nil)
      @type_nest += 1

      doc ||= @token.doc

      next_token_skip_space_or_newline
      name_column_number = @token.column_number

      name = parse_ident allow_type_vars: false
      skip_space

      type_vars = parse_type_vars

      superclass = nil

      if @token.type == :"<"
        next_token_skip_space_or_newline
        superclass = parse_ident
      end
      skip_statement_end

      body = parse_expressions

      end_location = token_end_location
      check_ident :end
      next_token_skip_space

      raise "Bug: ClassDef name can only be a Path" unless name.is_a?(Path)

      @type_nest -= 1

      class_def = ClassDef.new name, body, superclass, type_vars, is_abstract, is_struct, name_column_number
      class_def.doc = doc
      class_def.end_location = end_location
      class_def
    end

    def parse_type_vars
      type_vars = nil
      if @token.type == :"("
        type_vars = [] of String

        next_token_skip_space_or_newline
        while @token.type != :")"
          type_var_name = check_const
          unless Parser.free_var_name?(type_var_name)
            raise "type variables can only be single letters optionally followed by a digit", @token
          end

          if type_vars.includes? type_var_name
            raise "duplicated type var name: #{type_var_name}", @token
          end
          type_vars.push type_var_name

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
      @type_nest += 1

      location = @token.location
      doc = @token.doc

      next_token_skip_space_or_newline

      name_column_number = @token.column_number
      name = parse_ident allow_type_vars: false
      skip_space

      type_vars = parse_type_vars
      skip_statement_end

      body = parse_expressions

      end_location = token_end_location
      check_ident :end
      next_token_skip_space

      raise "Bug: ModuleDef name can only be a Path" unless name.is_a?(Path)

      @type_nest -= 1

      module_def = ModuleDef.new name, body, type_vars, name_column_number
      module_def.doc = doc
      module_def.end_location = end_location
      module_def
    end

    def parse_parenthesized_expression
      location = @token.location
      next_token_skip_space_or_newline

      if @token.type == :")"
        return node_and_next_token NilLiteral.new
      end

      exps = [] of ASTNode

      while true
        exps << parse_expression
        case @token.type
        when :")"
          @wants_regex = false
          next_token_skip_space
          break
        when :NEWLINE, :";"
          next_token_skip_space
          if @token.type == :")"
            @wants_regex = false
            next_token_skip_space
            break
          end
        else
          raise "unterminated parenthesized expression", location
        end
      end

      unexpected_token "(" if @token.type == :"("

      node = Expressions.new exps
      node.keyword = :"("
      node
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
          location = @token.location
          arg = parse_fun_literal_arg.at(location)
          if args.any? &.name.==(arg.name)
            raise "duplicated argument name: #{arg.name}", location
          end

          args << arg
        end
        next_token_skip_space_or_newline
      end

      current_vars = @def_vars.last.dup
      push_def current_vars
      push_vars args

      end_location = nil

      if @token.keyword?(:do)
        next_token_skip_statement_end
        check_not_pipe_before_proc_literal_body
        body = parse_expressions
        end_location = token_end_location
        check_ident :"end"
      elsif @token.type == :"{"
        next_token_skip_statement_end
        check_not_pipe_before_proc_literal_body
        @last_call_has_parenthesis = true
        body = parse_expressions
        end_location = token_end_location
        check :"}"
      else
        unexpected_token
      end

      pop_def

      next_token_skip_space

      FunLiteral.new(Def.new("->", args, body)).at_end(end_location)
    end

    def check_not_pipe_before_proc_literal_body
      if @token.type == :"|"
        location = @token.location
        next_token_skip_space

        msg = String.build do |msg|
          msg << "unexpected token '|', proc literals specify their arguments like this: ->("
          if @token.type == :IDENT
            msg << @token.value.to_s << " : Type"
            next_token_skip_space_or_newline
            msg << ", ..." if @token.type == :","
          else
            msg << "arg : Type"
          end
          msg << ") { ... }"
        end

        raise msg, location
      end
    end

    def parse_fun_literal_arg
      name = check_ident
      next_token_skip_space_or_newline

      if @token.type == :":"
        next_token_skip_space_or_newline

        type = parse_single_type
      end

      if @token.type == :","
        next_token_skip_space_or_newline
      end

      Arg.new name, restriction: type
    end

    def parse_fun_pointer
      location = @token.location

      case @token.type
      when :IDENT
        name = @token.value.to_s
        next_token_skip_space
        if @token.type == :"."
          next_token_skip_space
          second_name = check_ident
          if name != "self" && !@def_vars.last.includes?(name)
            raise "undefined variable '#{name}'", location.line_number, location.column_number
          end
          obj = Var.new(name)
          name = second_name
          next_token_skip_space
        end
      when :CONST
        obj = parse_ident
        check :"."
        next_token_skip_space
        name = check_ident
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

      FunPointer.new(obj, name, types)
    end

    record Piece, value, line_number do
      @value : String | ASTNode
    end

    def parse_delimiter
      if @token.type == :STRING
        return node_and_next_token StringLiteral.new(@token.value.to_s)
      end

      location = @token.location
      delimiter_state = @token.delimiter_state

      check :DELIMITER_START

      next_string_token(delimiter_state)
      delimiter_state = @token.delimiter_state

      pieces = [] of Piece
      has_interpolation = false

      delimiter_state, has_interpolation, options, token_end_location = consume_delimiter pieces, delimiter_state, has_interpolation

      if delimiter_state.kind == :string
        while true
          passed_backslash_newline = @token.passed_backslash_newline
          skip_space

          if passed_backslash_newline && @token.type == :DELIMITER_START && @token.delimiter_state.kind == :string
            next_string_token(delimiter_state)
            delimiter_state = @token.delimiter_state
            delimiter_state, has_interpolation, options, token_end_location = consume_delimiter pieces, delimiter_state, has_interpolation
          else
            break
          end
        end
      end

      if has_interpolation
        if needs_heredoc_indent_removed?(delimiter_state)
          pieces = remove_heredoc_indent(pieces, delimiter_state.heredoc_indent)
        else
          pieces = pieces.map do |piece|
            value = piece.value
            value.is_a?(String) ? StringLiteral.new(value) : value
          end
        end
        result = StringInterpolation.new(pieces)
      else
        if needs_heredoc_indent_removed?(delimiter_state)
          pieces = remove_heredoc_indent(pieces, delimiter_state.heredoc_indent)
          string = pieces.join { |piece| (piece as StringLiteral).value }
        else
          string = pieces.map(&.value).join
        end
        result = StringLiteral.new string
      end

      case delimiter_state.kind
      when :command
        result = Call.new(nil, "`", result)
      when :regex
        if result.is_a?(StringLiteral) && (regex_error = Regex.error?(result.value))
          raise "invalid regex: #{regex_error}", location
        end

        result = RegexLiteral.new(result, options)
      end

      result.end_location = token_end_location

      result
    end

    def consume_delimiter(pieces, delimiter_state, has_interpolation)
      options = Regex::Options::None
      token_end_location = nil
      while true
        case @token.type
        when :STRING
          pieces << Piece.new(@token.value.to_s, @token.line_number)

          next_string_token(delimiter_state)
          delimiter_state = @token.delimiter_state
        when :DELIMITER_END
          if delimiter_state.kind == :regex
            options = consume_regex_options
          end
          token_end_location = token_end_location()
          next_token
          break
        when :EOF
          case delimiter_state.kind
          when :command
            raise "Unterminated command"
          when :regex
            raise "Unterminated regular expression"
          when :heredoc
            raise "Unterminated heredoc"
          else
            raise "Unterminated string literal"
          end
        else
          line_number = @token.line_number
          delimiter_state = @token.delimiter_state
          next_token_skip_space_or_newline
          exp = parse_expression

          if exp.is_a?(StringLiteral)
            pieces << Piece.new(exp.value, line_number)
          else
            pieces << Piece.new(exp, line_number)
            has_interpolation = true
          end

          if @token.type != :"}"
            raise "Unterminated string interpolation"
          end

          @token.delimiter_state = delimiter_state
          next_string_token(delimiter_state)
          delimiter_state = @token.delimiter_state
        end
      end

      {delimiter_state, has_interpolation, options, token_end_location}
    end

    def consume_regex_options
      options = Regex::Options::None
      while true
        case current_char
        when 'i'
          options |= Regex::Options::IGNORE_CASE
          next_char
        when 'm'
          options |= Regex::Options::MULTILINE
          next_char
        when 'x'
          options |= Regex::Options::EXTENDED
          next_char
        else
          if 'a' <= current_char.downcase <= 'z'
            raise "unknown regex option: #{current_char}"
          end
          break
        end
      end
      options
    end

    def needs_heredoc_indent_removed?(delimiter_state)
      delimiter_state.kind == :heredoc && delimiter_state.heredoc_indent > 0
    end

    def remove_heredoc_indent(pieces : Array, indent)
      current_line = MemoryIO.new
      remove_indent = true
      new_pieces = [] of ASTNode
      pieces.each do |piece|
        value = piece.value
        if value.is_a?(String)
          if value == "\n" || value == "\r\n"
            current_line << value
            line = current_line.to_s
            line = remove_heredoc_from_line(line, indent, piece.line_number - 1) if remove_indent
            new_pieces << StringLiteral.new(line)
            current_line.clear
            remove_indent = true
          elsif (slash_n = value.starts_with?("\n")) || value.starts_with?("\r\n")
            current_line << (slash_n ? "\n" : "\r\n")
            line = current_line.to_s
            line = remove_heredoc_from_line(line, indent, piece.line_number - 1) if remove_indent
            new_pieces << StringLiteral.new(line)
            current_line.clear
            remove_indent = true
            current_line << value.byte_slice(slash_n ? 1 : 2)
          else
            current_line << value
          end
        else
          if remove_indent
            line = current_line.to_s
            if (line.size < indent) || !line.each_char.take(indent).all?(&.whitespace?)
              raise "heredoc line must have an indent greater or equal than #{indent}", piece.line_number, 1
            else
              line = line[indent..-1]
            end
            new_pieces << StringLiteral.new(line) unless line.empty?
            new_pieces << value
            remove_indent = false
            current_line.clear
          else
            new_pieces << value
          end
        end
      end
      unless current_line.empty?
        line = current_line.to_s
        line = remove_heredoc_from_line(line, indent, pieces.last.line_number) if remove_indent
        new_pieces << StringLiteral.new(line)
      end
      new_pieces
    end

    def remove_heredoc_from_line(line, indent, line_number)
      if line.each_char.take(indent).all? &.whitespace?
        if line.size - 1 < indent
          "\n"
        else
          line[indent..-1]
        end
      else
        raise "heredoc line must have an indent greater or equal than #{indent}", line_number, 1
      end
    end

    def parse_string_without_interpolation
      string = parse_delimiter
      if string.is_a?(StringLiteral)
        string.value
      else
        yield
      end
    end

    def parse_string_array
      parse_string_or_symbol_array StringLiteral, "String"
    end

    def parse_symbol_array
      parse_string_or_symbol_array SymbolLiteral, "Symbol"
    end

    def parse_string_or_symbol_array(klass, elements_type)
      strings = [] of ASTNode

      while true
        next_string_array_token
        case @token.type
        when :STRING
          strings << klass.new(@token.value.to_s)
        when :STRING_ARRAY_END
          next_token
          break
        when :EOF
          raise "Unterminated symbol array literal"
        end
      end

      ArrayLiteral.new strings, Path.global(elements_type)
    end

    def parse_empty_array_literal
      line = @line_number
      column = @token.column_number

      next_token_skip_space
      if @token.keyword?(:of)
        next_token_skip_space_or_newline
        of = parse_single_type
        ArrayLiteral.new(of: of).at_end(of)
      else
        raise "for empty arrays use '[] of ElementType'", line, column
      end
    end

    def parse_array_literal
      slash_is_regex!

      exps = [] of ASTNode
      end_location = nil

      open("array literal") do
        next_token_skip_space_or_newline
        while @token.type != :"]"
          exps << parse_expression
          end_location = token_end_location
          skip_space
          if @token.type == :NEWLINE
            skip_space_or_newline
            check :"]"
            break
          end

          if @token.type == :","
            slash_is_regex!
            next_token_skip_space_or_newline
          end
        end
        next_token_skip_space
      end

      of = nil
      if @token.keyword?(:of)
        next_token_skip_space_or_newline
        of = parse_single_type
        end_location = of.end_location
      end

      ArrayLiteral.new(exps, of).at_end(end_location)
    end

    def parse_hash_or_tuple_literal(allow_of = true)
      location = @token.location
      line = @line_number
      column = @token.column_number

      slash_is_regex!
      next_token_skip_space_or_newline

      if @token.type == :"}"
        end_location = token_end_location
        next_token_skip_space
        new_hash_literal([] of HashLiteral::Entry, line, column, end_location)
      else
        if hash_symbol_key?
          first_key = SymbolLiteral.new(@token.value.to_s)
          next_token
        else
          first_key = parse_op_assign
          case @token.type
          when :":"
            if first_key.is_a?(StringLiteral)
              # Nothing: it's a string key
            else
              check :"=>"
            end
          when :","
            slash_is_regex!
            next_token_skip_space_or_newline
            return parse_tuple first_key, location
          when :"}"
            return parse_tuple first_key, location
          else
            check :"=>"
          end
        end
        slash_is_regex!
        next_token_skip_space
        parse_hash_literal first_key, location, allow_of
      end
    end

    def parse_hash_literal(first_key, location, allow_of)
      slash_is_regex!

      line = @line_number
      column = @token.column_number
      end_location = nil

      entries = [] of HashLiteral::Entry
      entries << HashLiteral::Entry.new(first_key, parse_op_assign)

      if @token.type == :NEWLINE
        next_token_skip_space_or_newline
        check :"}"
        next_token_skip_space
      else
        open("hash literal", location) do
          skip_space_or_newline
          if @token.type == :","
            slash_is_regex!
            next_token_skip_space_or_newline
          end

          while @token.type != :"}"
            if hash_symbol_key?
              key = SymbolLiteral.new(@token.value.to_s)
              next_token
            else
              key = parse_op_assign
              skip_space_or_newline
              if @token.type == :":" && key.is_a?(StringLiteral)
                # Nothing: it's a string key
              else
                check :"=>"
              end
            end
            slash_is_regex!
            next_token_skip_space_or_newline
            entries << HashLiteral::Entry.new(key, parse_op_assign)
            skip_space
            if @token.type == :NEWLINE
              next_token_skip_space_or_newline
              check :"}"
              break
            end
            if @token.type == :","
              slash_is_regex!
              next_token_skip_space_or_newline
            end
          end
          end_location = token_end_location
          next_token_skip_space
        end
      end

      new_hash_literal entries, line, column, end_location, allow_of: allow_of
    end

    def hash_symbol_key?
      (@token.type == :IDENT || @token.type == :CONST) && current_char == ':' && peek_next_char != ':'
    end

    def parse_tuple(first_exp, location)
      exps = [] of ASTNode
      end_location = nil

      open("tuple literal", location) do
        exps << first_exp
        while @token.type != :"}"
          exps << parse_expression
          skip_space_or_newline
          if @token.type == :","
            next_token_skip_space_or_newline
          end
        end
        end_location = token_end_location
        next_token_skip_space
      end

      TupleLiteral.new(exps).at_end(end_location)
    end

    def new_hash_literal(entries, line, column, end_location, allow_of = true)
      of = nil

      if allow_of
        if @token.keyword?(:of)
          next_token_skip_space_or_newline
          of_key = parse_single_type
          check :"=>"
          next_token_skip_space_or_newline
          of_value = parse_single_type
          of = HashLiteral::Entry.new(of_key, of_value)
          end_location = of_value.end_location
        end

        if entries.empty? && !of
          raise "for empty hashes use '{} of KeyType => ValueType'", line, column
        end
      end

      HashLiteral.new(entries, of).at_end(end_location)
    end

    def parse_require
      raise "can't require inside def", @token if @def_nest > 0
      raise "can't require inside type declarations", @token if @type_nest > 0

      next_token_skip_space
      check :DELIMITER_START
      string = parse_string_without_interpolation { "interpolation not allowed in require" }

      skip_space

      Require.new string
    end

    def parse_case
      slash_is_regex!
      next_token_skip_space_or_newline
      unless @token.keyword?(:when)
        cond = parse_op_assign_no_control
        skip_statement_end
      end

      whens = [] of When
      a_else = nil

      while true
        case @token.type
        when :IDENT
          case @token.value
          when :when
            slash_is_regex!
            next_token_skip_space_or_newline
            when_conds = [] of ASTNode
            while true
              if cond && @token.type == :"."
                next_token
                call = parse_var_or_call(force_call: true) as Call
                call.obj = ImplicitObj.new
                when_conds << call
              else
                when_conds << parse_op_assign_no_control
              end
              skip_space
              if @token.keyword?(:then)
                next_token_skip_space_or_newline
                break
              else
                slash_is_regex!
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

            slash_is_regex!
            when_body = parse_expressions
            skip_space_or_newline
            whens << When.new(when_conds, when_body)
          when :else
            if whens.size == 0
              unexpected_token @token.to_s, "expecting when"
            end
            slash_is_regex!
            next_token_skip_statement_end
            a_else = parse_expressions
            skip_statement_end
            check_ident :end
            next_token
            break
          when :end
            if whens.empty?
              unexpected_token @token.to_s, "expecting when, else or end"
            end
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
      parse_include_or_extend Include
    end

    def parse_extend
      parse_include_or_extend Extend
    end

    def parse_include_or_extend(klass)
      location = @token.location

      next_token_skip_space_or_newline

      if @token.keyword?(:self)
        name = Self.new.at(@token.location)
        name.end_location = token_end_location
        next_token_skip_space
      else
        name = parse_ident
      end

      klass.new name
    end

    def parse_to_def(a_def)
      instance_vars = prepare_parse_def
      @def_nest += 1

      # Small memory optimization: don't keep the Set in the Def if it's empty
      instance_vars = nil if instance_vars.empty?

      result = parse

      a_def.instance_vars = instance_vars
      a_def.calls_super = @calls_super
      a_def.calls_initialize = @calls_initialize
      a_def.uses_block_arg = @uses_block_arg
      a_def.assigns_special_var = @assigns_special_var

      result
    end

    def parse_def(is_abstract = false, is_macro_def = false, doc = nil)
      doc ||= @token.doc

      instance_vars = prepare_parse_def
      a_def = parse_def_helper is_abstract: is_abstract, is_macro_def: is_macro_def

      # Small memory optimization: don't keep the Set in the Def if it's empty
      instance_vars = nil if instance_vars.empty?

      a_def.instance_vars = instance_vars
      a_def.calls_super = @calls_super
      a_def.calls_initialize = @calls_initialize
      a_def.uses_block_arg = @uses_block_arg
      a_def.assigns_special_var = @assigns_special_var
      a_def.doc = doc
      @instance_vars = nil
      @calls_super = false
      @calls_initialize = false
      @uses_block_arg = false
      @assigns_special_var = false
      @block_arg_name = nil
      a_def
    end

    def prepare_parse_def
      @calls_super = false
      @calls_initialize = false
      @uses_block_arg = false
      @block_arg_name = nil
      @assigns_special_var = false
      @instance_vars = Set(String).new
    end

    def parse_macro
      doc = @token.doc

      next_token_skip_space_or_newline

      if @token.keyword?(:def)
        a_def = parse_def_helper is_macro_def: true
        a_def.doc = doc
        return a_def
      end

      push_def

      check DefOrMacroCheck1

      name_line_number = @token.line_number
      name_column_number = @token.column_number

      name = check_ident
      next_token_skip_space

      args = [] of Arg

      found_default_value = false
      found_splat = false

      splat_index = nil
      index = 0

      case @token.type
      when :"("
        next_token_skip_space_or_newline
        while @token.type != :")"
          extras = parse_arg(args, nil, true, found_default_value, found_splat, allow_restrictions: false)
          if !found_default_value && extras.default_value
            found_default_value = true
          end
          if !splat_index && extras.splat
            splat_index = index
            found_splat = true
          end
          if block_arg = extras.block_arg
            check :")"
            break
          elsif @token.type == :","
            next_token_skip_space_or_newline
          else
            skip_space
            if @token.type != :")"
              unexpected_token @token.to_s, "expected ',' or ')'"
            end
          end
          index += 1
        end
        next_token
      when :IDENT, :"*"
        if @token.keyword?(:end)
          unexpected_token @token.to_s, "expected ';' or newline"
        else
          unexpected_token @token.to_s, "parentheses are mandatory for macro arguments"
        end
      end

      end_location = nil

      if @token.keyword?(:end)
        end_location = token_end_location
        body = Expressions.new
        next_token_skip_space
      else
        body, end_location = parse_macro_body(name_line_number, name_column_number)
      end

      pop_def

      node = Macro.new name, args, body, block_arg, splat_index
      node.name_column_number = name_column_number
      node.doc = doc
      node.end_location = end_location
      node
    end

    def parse_macro_body(start_line, start_column, macro_state = Token::MacroState.default)
      skip_whitespace = check_macro_skip_whitespace

      pieces = [] of ASTNode

      while true
        next_macro_token macro_state, skip_whitespace
        macro_state = @token.macro_state
        if macro_state.yields
          @yields = 0
        end

        skip_whitespace = false

        case @token.type
        when :MACRO_LITERAL
          pieces << MacroLiteral.new(@token.value.to_s)
        when :MACRO_EXPRESSION_START
          pieces << MacroExpression.new(parse_macro_expression)
          check_macro_expression_end
          skip_whitespace = check_macro_skip_whitespace
        when :MACRO_CONTROL_START
          macro_control = parse_macro_control(start_line, start_column, macro_state)
          if macro_control
            pieces << macro_control
            skip_whitespace = check_macro_skip_whitespace
          else
            return new_macro_expressions(pieces), nil
          end
        when :MACRO_VAR
          macro_var_name = @token.value.to_s
          if current_char == '{'
            macro_var_exps = parse_macro_var_exps
          else
            macro_var_exps = nil
          end
          pieces << MacroVar.new(macro_var_name, macro_var_exps)
        when :MACRO_END
          break
        when :EOF
          raise "unterminated macro", start_line, start_column
        else
          unexpected_token
        end
      end

      end_location = token_end_location

      next_token

      {new_macro_expressions(pieces), end_location}
    end

    private def new_macro_expressions(pieces)
      if pieces.empty?
        Expressions.new
      else
        Expressions.from(pieces)
      end
    end

    def parse_macro_var_exps
      next_token # '{'
      next_token

      exps = [] of ASTNode
      while true
        exps << parse_expression_inside_macro
        skip_space
        case @token.type
        when :","
          next_token_skip_space
          if @token.type == :"}"
            break
          end
        when :"}"
          break
        else
          unexpected_token @token, "expecting ',' or '}'"
        end
      end
      exps
    end

    def check_macro_skip_whitespace
      if current_char == '\\' && peek_next_char.whitespace?
        next_char
        true
      else
        false
      end
    end

    def parse_macro_expression
      next_token_skip_space_or_newline
      parse_expression_inside_macro
    end

    def check_macro_expression_end
      check :"}"

      next_token
      check :"}"
    end

    def parse_macro_control(start_line, start_column, macro_state = Token::MacroState.default)
      next_token_skip_space_or_newline

      case @token.type
      when :IDENT
        case @token.value
        when :for
          next_token_skip_space

          vars = [] of Var

          while true
            vars << Var.new(check_ident).at(@token.location)

            next_token_skip_space
            if @token.type == :","
              next_token_skip_space
            else
              break
            end
          end

          check_ident :in
          next_token_skip_space

          exp = parse_expression_inside_macro

          check :"%}"

          body, end_location = parse_macro_body(start_line, start_column, macro_state)

          check_ident :end
          next_token_skip_space
          check :"%}"

          return MacroFor.new(vars, exp, body)
        when :if
          return parse_macro_if(start_line, start_column, macro_state)
        when :unless
          macro_if = parse_macro_if(start_line, start_column, macro_state)
          case macro_if
          when MacroIf
            macro_if.then, macro_if.else = macro_if.else, macro_if.then
          when MacroExpression
            if (exp = macro_if.exp).is_a?(If)
              exp.then, exp.else = exp.else, exp.then
            end
          end
          return macro_if
        when :begin
          next_token_skip_space
          check :"%}"

          body, end_location = parse_macro_body(start_line, start_column, macro_state)

          check_ident :end
          next_token_skip_space
          check :"%}"

          return MacroIf.new(BoolLiteral.new(true), body)
        when :else, :elsif, :end
          return nil
        end
      end

      @in_macro_expression = true
      exps = parse_expressions
      @in_macro_expression = false

      MacroExpression.new(exps, output: false)
    end

    def parse_macro_if(start_line, start_column, macro_state, check_end = true)
      next_token_skip_space

      @in_macro_expression = true
      cond = parse_op_assign
      @in_macro_expression = false

      if @token.type != :"%}" && check_end
        an_if = parse_if_after_condition cond, true
        return MacroExpression.new(an_if, output: false)
      end

      check :"%}"

      a_then, end_location = parse_macro_body(start_line, start_column, macro_state)

      if @token.type == :IDENT
        case @token.value
        when :else
          next_token_skip_space
          check :"%}"

          a_else, end_location = parse_macro_body(start_line, start_column, macro_state)

          if check_end
            check_ident :end
            next_token_skip_space
            check :"%}"
          end
        when :elsif
          a_else = parse_macro_if(start_line, start_column, macro_state, false)

          if check_end
            check_ident :end
            next_token_skip_space
            check :"%}"
          end
        when :end
          if check_end
            next_token_skip_space
            check :"%}"
          end
        else
          unexpected_token
        end
      else
        unexpected_token
      end

      return MacroIf.new(cond, a_then, a_else)
    end

    def parse_expression_inside_macro
      @in_macro_expression = true

      if @token.type == :"*"
        next_token_skip_space
        exp = parse_expression
        exp = Splat.new(exp).at(exp.location)
      else
        exp = parse_expression
      end

      skip_space_or_newline

      @in_macro_expression = false
      exp
    end

    DefOrMacroCheck1 = [:IDENT, :CONST, :"<<", :"<", :"<=", :"==", :"===", :"!=", :"=~", :"!~", :">>", :">", :">=", :"+", :"-", :"*", :"/", :"!", :"~", :"%", :"&", :"|", :"^", :"**", :"[]", :"[]=", :"<=>", :"[]?"]
    DefOrMacroCheck2 = [:"<<", :"<", :"<=", :"==", :"===", :"!=", :"=~", :"!~", :">>", :">", :">=", :"+", :"-", :"*", :"/", :"!", :"~", :"%", :"&", :"|", :"^", :"**", :"[]", :"[]?", :"[]=", :"<=>"]

    def parse_def_helper(is_abstract = false, is_macro_def = false)
      push_def
      @doc_enabled = false
      @def_nest += 1

      # At this point we want to attach the "do" to calls inside the def,
      # not to calls that might have this def as a macro argument.
      @last_call_has_parenthesis = true

      next_token

      case current_char
      when '%'
        next_char
        @token.type = :"%"
        @token.column_number += 1
      when '/'
        next_char
        @token.type = :"/"
        @token.column_number += 1
      when '`'
        next_char
        @token.type = :"`"
        @token.column_number += 1
      else
        skip_space_or_newline
        check DefOrMacroCheck1
      end

      receiver = nil
      @yields = nil
      name_line_number = @token.line_number
      name_column_number = @token.column_number
      receiver_location = @token.location
      end_location = token_end_location

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
      extra_assigns = [] of ASTNode

      if @token.type == :"."
        unless receiver
          if name
            receiver = Var.new(name).at(receiver_location)
          else
            raise "shouldn't reach this line"
          end
        end
        next_token_skip_space

        if @token.type == :IDENT
          name = @token.value.to_s
          name_column_number = @token.column_number
          next_token
          if @token.type == :"="
            name = "#{name}="
            next_token_skip_space
          else
            skip_space
          end
        else
          check DefOrMacroCheck2
          name = @token.type.to_s
          name_column_number = @token.column_number
          next_token_skip_space
        end
      else
        if receiver
          unexpected_token
        else
          raise "shouldn't reach this line" unless name
        end
        name = name.not_nil!
      end

      found_default_value = false
      found_splat = false

      index = 0
      splat_index = nil

      case @token.type
      when :"("
        next_token_skip_space_or_newline
        while @token.type != :")"
          extras = parse_arg(args, extra_assigns, true, found_default_value, found_splat)
          if !found_default_value && extras.default_value
            found_default_value = true
          end
          if !splat_index && extras.splat
            splat_index = index
            found_splat = true
          end
          if block_arg = extras.block_arg
            compute_block_arg_yields block_arg
            check :")"
            break
          elsif @token.type == :","
            next_token_skip_space_or_newline
          else
            skip_space_or_newline
            if @token.type != :")"
              unexpected_token @token.to_s, "expected ',' or ')'"
            end
          end
          index += 1
        end
        next_token_skip_space
        if @token.type == :SYMBOL
          raise "a space is mandatory between ':' and return type", @token
        end
      when :IDENT, :INSTANCE_VAR, :CLASS_VAR, :"*"
        if @token.keyword?(:end)
          unexpected_token @token.to_s, "expected ';' or newline"
        else
          unexpected_token @token.to_s, "parentheses are mandatory for def arguments"
        end
      when :";", :"NEWLINE"
        # Skip
      when :":"
        # Skip
      when :"&"
        unexpected_token @token.to_s, "parentheses are mandatory for def arguments"
      when :SYMBOL
        raise "a space is mandatory between ':' and return type", @token
      else
        if is_abstract && @token.type == :EOF
          # OK
        else
          unexpected_token
        end
      end

      if is_macro_def
        check :":"
        next_token_skip_space
        return_type = parse_single_type
        end_location = return_type.end_location

        if is_abstract
          body = Nop.new
        else
          if @token.keyword?(:end)
            body = Expressions.new
            next_token_skip_space
          else
            body, end_location = parse_macro_body(name_line_number, name_column_number)
          end
        end
      else
        if @token.type == :":"
          next_token_skip_space
          return_type = parse_single_type
          end_location = return_type.end_location
        end

        if is_abstract
          body = Nop.new
        else
          slash_is_regex!
          skip_statement_end

          end_location = token_end_location

          if @token.keyword?(:end)
            body = Expressions.from(extra_assigns)
            next_token_skip_space
          else
            body = parse_expressions
            if extra_assigns.size > 0
              exps = [] of ASTNode
              exps.concat extra_assigns
              if body.is_a?(Expressions)
                exps.concat body.expressions
              else
                exps.push body
              end
              body = Expressions.from exps
            end
            body, end_location = parse_exception_handler body, implicit: true
          end
        end
      end

      @def_nest -= 1
      @doc_enabled = @wants_doc
      pop_def

      node = Def.new name, args, body, receiver, block_arg, return_type, is_macro_def, @yields, is_abstract, splat_index
      node.name_column_number = name_column_number
      node.visibility = @visibility
      node.end_location = end_location
      node
    end

    def compute_block_arg_yields(block_arg)
      block_arg_restriction = block_arg.restriction
      if block_arg_restriction.is_a?(Fun)
        @yields = block_arg_restriction.inputs.try(&.size) || 0
      else
        @yields = 0
      end
    end

    record ArgExtras, block_arg, default_value, splat

    def parse_arg(args, extra_assigns, parenthesis, found_default_value, found_splat, allow_restrictions = true)
      if @token.type == :"&"
        next_token_skip_space_or_newline
        block_arg = parse_block_arg(extra_assigns)
        return ArgExtras.new(block_arg, false, false)
      end

      splat = false
      if @token.type == :"*"
        if found_splat
          unexpected_token
        end

        splat = true
        next_token_skip_space
      end

      arg_location = @token.location
      arg_name, uses_arg = parse_arg_name(arg_location, extra_assigns)

      if args.any? { |arg| arg.name == arg_name }
        raise "duplicated argument name: #{arg_name}", @token
      end

      default_value = nil
      restriction = nil
      found_space = false

      if parenthesis
        next_token
        found_space = @token.type == :SPACE || @token.type == :NEWLINE
        skip_space_or_newline
      else
        next_token
        found_space = @token.type == :SPACE
        skip_space
      end

      unless splat
        if @token.type == :"="
          if found_splat || splat
            unexpected_token
          end

          next_token_skip_space_or_newline

          case @token.type
          when :__LINE__, :__FILE__, :__DIR__
            default_value = MagicConstant.new(@token.type).at(@token.location)
            next_token
          else
            @no_type_declaration += 1
            default_value = parse_op_assign
            @no_type_declaration -= 1
          end

          skip_space
        else
          if found_default_value && !splat
            raise "argument must have a default value", arg_location
          end
        end
      end

      if @token.type == :SYMBOL
        raise "space required after colon in type restriction", @token
      end

      if allow_restrictions && @token.type == :":"
        if !default_value && !found_space
          raise "space required before colon in type restriction", @token
        end

        next_token_skip_space_or_newline

        location = @token.location
        restriction = parse_single_type
      end

      raise "Bug: arg_name is nil" unless arg_name

      arg = Arg.new(arg_name, default_value, restriction).at(arg_location)
      args << arg
      push_var arg

      ArgExtras.new(nil, !!default_value, splat)
    end

    def parse_block_arg(extra_assigns)
      name_location = @token.location
      arg_name, uses_arg = parse_arg_name(name_location, extra_assigns)
      @uses_block_arg = true if uses_arg

      next_token_skip_space_or_newline

      inputs = nil
      output = nil

      if @token.type == :":"
        next_token_skip_space_or_newline

        location = @token.location

        type_spec = parse_single_type
      end

      block_arg = Arg.new(arg_name, restriction: type_spec).at(name_location)

      push_var block_arg

      @block_arg_name = block_arg.name

      block_arg
    end

    def parse_arg_name(location, extra_assigns)
      case @token.type
      when :IDENT
        arg_name = @token.value.to_s
        uses_arg = false
      when :INSTANCE_VAR
        arg_name = @token.value.to_s[1..-1]
        ivar = InstanceVar.new(@token.value.to_s).at(location)
        var = Var.new(arg_name).at(location)
        assign = Assign.new(ivar, var).at(location)
        if extra_assigns
          extra_assigns.push assign
        else
          raise "can't use @instance_variable here"
        end
        add_instance_var ivar.name
        uses_arg = true
      when :CLASS_VAR
        arg_name = @token.value.to_s[2..-1]
        cvar = ClassVar.new(@token.value.to_s).at(location)
        var = Var.new(arg_name).at(location)
        assign = Assign.new(cvar, var).at(location)
        if extra_assigns
          extra_assigns.push assign
        else
          raise "can't use @@class_var here"
        end
        uses_arg = true
      else
        raise "unexpected token: #{@token}"
      end

      {arg_name, uses_arg}
    end

    def parse_if(check_end = true)
      slash_is_regex!
      next_token_skip_space_or_newline

      cond = parse_op_assign_no_control allow_suffix: false
      parse_if_after_condition cond, check_end
    end

    def parse_if_after_condition(cond, check_end)
      slash_is_regex!
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
          a_else = parse_if check_end: false
        end
      end

      end_location = token_end_location
      if check_end
        check_ident :end
        next_token_skip_space
      end

      If.new(cond, a_then, a_else).at_end(end_location)
    end

    def parse_unless
      next_token_skip_space_or_newline

      cond = parse_op_assign_no_control allow_suffix: false
      skip_statement_end

      a_then = parse_expressions
      skip_statement_end

      a_else = nil
      if @token.keyword?(:else)
        next_token_skip_statement_end
        a_else = parse_expressions
      end

      check_ident :end
      end_location = token_end_location
      next_token_skip_space

      Unless.new(cond, a_then, a_else).at_end(end_location)
    end

    def parse_ifdef(check_end = true, mode = :normal)
      next_token_skip_space_or_newline

      cond = parse_flags_or
      skip_statement_end

      a_then = parse_ifdef_body(mode)
      skip_statement_end

      a_else = nil
      if @token.type == :IDENT
        case @token.value
        when :else
          next_token_skip_statement_end
          a_else = parse_ifdef_body(mode)
        when :elsif
          a_else = parse_ifdef check_end: false, mode: mode
        end
      end

      end_location = token_end_location

      if check_end
        check_ident :end
        next_token_skip_space
      end

      IfDef.new(cond, a_then, a_else).at_end(end_location)
    end

    def parse_ifdef_body(mode)
      case mode
      when :lib
        parse_lib_body
      when :struct_or_union
        parse_struct_or_union_body
      else
        parse_expressions
      end
    end

    parse_operator :flags_or, :flags_and, "Or.new left, right", ":\"||\""
    parse_operator :flags_and, :flags_atomic, "And.new left, right", ":\"&&\""

    def parse_flags_atomic
      case @token.type
      when :"("
        next_token_skip_space
        if @token.type == :")"
          raise "unexpected token: #{@token}"
        end

        atomic = parse_flags_or
        skip_space

        check :")"
        next_token_skip_space

        atomic
      when :"!"
        next_token_skip_space
        Not.new(parse_flags_atomic)
      when :IDENT
        str = @token.to_s
        next_token_skip_space
        Var.new(str)
      else
        raise "unexpected token: #{@token}"
      end
    end

    def set_visibility(node)
      if visibility = @visibility
        node.visibility = visibility
      end
      node
    end

    def parse_var_or_call(global = false, force_call = false)
      location = @token.location
      end_location = token_end_location
      doc = @token.doc

      case @token.value
      when :is_a?
        obj = Var.new("self").at(location)
        return parse_is_a(obj)
      when :responds_to?
        obj = Var.new("self").at(location)
        return parse_responds_to(obj)
      end

      name = @token.value.to_s
      name_column_number = @token.column_number

      if force_call && !@token.value
        name = @token.type.to_s
      end

      is_var = is_var?(name)

      @wants_regex = false
      next_token

      if @token.type == :SPACE
        # We don't want the next token to be a regex literal if the call's name is
        # a variable in the current scope (it's unlikely that there will be a method
        # with that name that accepts a regex as a first argument).
        # This allows us to write: a = 1; b = 2; a /b
        @wants_regex = !is_var
      end

      case name
      when "super"
        @calls_super = true
      when "initialize"
        @calls_initialize = true
      end

      call_args, last_call_has_parenthesis = preserve_last_call_has_parenthesis do
        parse_call_args stop_on_do_after_space: (is_var || !@last_call_has_parenthesis)
      end
      if call_args
        args = call_args.args
        block = call_args.block
        block_arg = call_args.block_arg
        named_args = call_args.named_args
      end

      if call_args && call_args.stopped_on_do_after_space
        # This is the case when we have:
        #
        #     x = 1
        #     foo x do
        #     end
        #
        # In this case, since x is a variable and the previous call (foo)
        # doesn't have parenthesis, we don't parse "x do end" as an invocation
        # to a method x with a block. Instead, we just stop on x and we don't
        # consume the block, leaving the block for 'foo' to consume.
      else
        block = parse_block(block)
      end

      node =
        if block || block_arg || global
          Call.new nil, name, (args || [] of ASTNode), block, block_arg, named_args, global, name_column_number, last_call_has_parenthesis
        else
          if args
            if (!force_call && is_var) && args.size == 1 && (num = args[0]) && (num.is_a?(NumberLiteral) && num.has_sign?)
              sign = num.value[0].to_s
              num.value = num.value.byte_slice(1)
              Call.new(Var.new(name), sign, args)
            else
              Call.new(nil, name, args, nil, block_arg, named_args, global, name_column_number, last_call_has_parenthesis)
            end
          else
            if @no_type_declaration == 0 && @token.type == :":"
              next_token_skip_space_or_newline
              declared_type = parse_single_type
              declare_var = TypeDeclaration.new(Var.new(name).at(location), declared_type).at(location)
              push_var declare_var
              declare_var
            elsif (!force_call && is_var)
              if @block_arg_name && !@uses_block_arg && name == @block_arg_name
                @uses_block_arg = true
              end
              Var.new name
            else
              Call.new nil, name, [] of ASTNode, nil, block_arg, named_args, global, name_column_number, last_call_has_parenthesis
            end
          end
        end
      node.doc = doc
      node.end_location = block.try(&.end_location) || call_args.try(&.end_location) || end_location
      node
    end

    def preserve_last_call_has_parenthesis
      old_last_call_has_parenthesis = @last_call_has_parenthesis
      value = yield
      last_call_has_parenthesis = @last_call_has_parenthesis
      @last_call_has_parenthesis = old_last_call_has_parenthesis
      {value, last_call_has_parenthesis}
    end

    def parse_block(block, stop_on_do = false)
      if @token.keyword?(:do)
        return block if stop_on_do

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
          case @token.type
          when :IDENT
            arg_name = @token.value.to_s
          when :UNDERSCORE
            arg_name = "_"
          else
            raise "expecting block argument name, not #{@token.type}", @token
          end

          var = Var.new(arg_name).at(@token.location)
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

      end_location = token_end_location
      next_token_skip_space

      Block.new(block_args, block_body).at_end(end_location)
    end

    record CallArgs, args, block, block_arg, named_args, stopped_on_do_after_space, end_location

    def parse_call_args(stop_on_do_after_space = false, allow_curly = false, control = false)
      case @token.type
      when :"{"
        @last_call_has_parenthesis = false
        nil
      when :"("
        slash_is_regex!

        args = [] of ASTNode
        end_location = nil

        open("call") do
          next_token_skip_space_or_newline
          while @token.type != :")"
            if call_block_arg_follows?
              return parse_call_block_arg(args, true)
            end

            if @token.type == :IDENT && current_char == ':'
              named_args = parse_named_args(allow_newline: true)

              if call_block_arg_follows?
                return parse_call_block_arg(args, true, named_args)
              end

              check :")"
              end_location = token_end_location

              next_token_skip_space
              return CallArgs.new args, nil, nil, named_args, false, end_location
            else
              args << parse_call_arg
            end

            skip_space_or_newline
            if @token.type == :","
              slash_is_regex!
              next_token_skip_space_or_newline
            else
              check :")"
              break
            end
          end
          end_location = token_end_location
          next_token_skip_space
          @last_call_has_parenthesis = true
        end

        CallArgs.new args, nil, nil, nil, false, end_location
      when :SPACE
        slash_is_not_regex!
        end_location = token_end_location
        next_token
        @last_call_has_parenthesis = false unless control

        if stop_on_do_after_space && @token.keyword?(:do)
          return CallArgs.new nil, nil, nil, nil, true, end_location
        end

        if control && @token.keyword?(:do)
          unexpected_token
        end

        parse_call_args_space_consumed check_plus_and_minus: true, allow_curly: allow_curly
      else
        @last_call_has_parenthesis = false
        nil
      end
    end

    def parse_call_args_space_consumed(check_plus_and_minus = true, allow_curly = false)
      if @token.keyword?(:as) || @token.keyword?(:end)
        return nil
      end

      case @token.type
      when :"&"
        return nil if current_char.whitespace?
      when :"+", :"-"
        if check_plus_and_minus
          return nil if current_char.whitespace?
        end
      when :"{"
        return nil unless allow_curly
      when :CHAR, :STRING, :DELIMITER_START, :STRING_ARRAY_START, :SYMBOL_ARRAY_START, :NUMBER, :IDENT, :SYMBOL, :INSTANCE_VAR, :CLASS_VAR, :CONST, :GLOBAL, :"$~", :"$?", :GLOBAL_MATCH_DATA_INDEX, :REGEX, :"(", :"!", :"[", :"[]", :"+", :"-", :"~", :"&", :"->", :"{{", :__LINE__, :__FILE__, :__DIR__, :UNDERSCORE
        # Nothing
      when :"*"
        if current_char.whitespace?
          return nil
        end
      when :"::"
        if current_char.whitespace?
          return nil
        end
      else
        return nil
      end

      case @token.value
      when :if, :unless, :while, :until, :rescue, :ensure
        return nil
      when :yield
        return nil if @stop_on_yield > 0
      end

      args = [] of ASTNode
      end_location = nil

      while @token.type != :NEWLINE && @token.type != :";" && @token.type != :EOF && @token.type != :")" && @token.type != :":" && !is_end_token
        if call_block_arg_follows?
          return parse_call_block_arg(args, false)
        end

        if @token.type == :IDENT && current_char == ':'
          named_args = parse_named_args

          if call_block_arg_follows?
            return parse_call_block_arg(args, false, named_args: named_args)
          end

          end_location = token_end_location

          skip_space
          return CallArgs.new args, nil, nil, named_args, false, end_location
        else
          arg = parse_call_arg
          args << arg
          end_location = arg.end_location
        end

        skip_space

        if @token.type == :","
          location = @token.location
          slash_is_regex!
          next_token_skip_space_or_newline
          raise "invalid trailing comma in call" if @token.keyword?(:end) || @token.type == :EOF
        else
          break
        end
      end

      CallArgs.new args, nil, nil, nil, false, end_location
    end

    def parse_named_args(allow_newline = false)
      named_args = [] of NamedArgument
      while true
        location = @token.location
        name = @token.value.to_s

        if named_args.any? { |arg| arg.name == name }
          raise "duplicated named argument: #{name}", @token
        end

        next_token
        check :":"
        next_token_skip_space_or_newline
        value = parse_op_assign
        named_args << NamedArgument.new(name, value).at(location)
        skip_space_or_newline if allow_newline
        if @token.type == :","
          next_token_skip_space_or_newline
          if @token.type == :")" || @token.type == :"&"
            break
          end
        else
          break
        end
      end
      named_args
    end

    def parse_call_arg
      if @token.keyword?(:out)
        parse_out
      else
        splat = false
        if @token.type == :"*"
          unless current_char.whitespace?
            splat = true
            next_token
          end
        end
        arg = parse_op_assign_no_control
        arg = Splat.new(arg).at(arg.location) if splat
        arg
      end
    end

    def parse_out
      next_token_skip_space_or_newline
      location = @token.location
      name = @token.value.to_s

      case @token.type
      when :IDENT
        var = Var.new(name).at(location)
        var_out = Out.new(var).at(location)
        push_var var

        next_token
        var_out
      when :INSTANCE_VAR
        ivar = InstanceVar.new(name).at(location)
        ivar_out = Out.new(ivar).at(location)

        add_instance_var name

        next_token
        ivar_out
      when :UNDERSCORE
        underscore = Underscore.new.at(location)
        var_out = Out.new(underscore).at(location)
        next_token
        var_out
      else
        raise "expecting variable or instance variable after out"
      end
    end

    def parse_ident_or_global_call
      location = @token.location
      next_token_skip_space_or_newline

      case @token.type
      when :IDENT
        set_visibility parse_var_or_call global: true
      when :CONST
        parse_ident_after_colons(location, true, true)
      else
        unexpected_token
      end
    end

    def parse_ident(allow_type_vars = true)
      location = @token.location

      global = false

      case @token.type
      when :"::"
        global = true
        next_token_skip_space_or_newline
      when :UNDERSCORE
        return node_and_next_token Underscore.new.at(location)
      end

      check :CONST
      parse_ident_after_colons(location, global, allow_type_vars)
    end

    def parse_ident_after_colons(location, global, allow_type_vars)
      start_line = location.line_number
      start_column = location.column_number

      names = [] of String
      names << @token.value.to_s
      end_location = token_end_location

      next_token
      while @token.type == :"::"
        next_token_skip_space_or_newline
        names << check_const
        end_location = token_end_location
        next_token
      end

      const = Path.new(names, global).at(location)
      const.end_location = end_location

      token_location = @token.location
      if token_location && token_location.line_number == start_line
        const.name_size = token_location.column_number - start_column
      end

      if allow_type_vars && @token.type == :"("
        next_token_skip_space

        types = parse_types allow_primitives: true
        if types.empty?
          raise "must specify at least one type var"
        end

        check :")"
        const = Generic.new(const, types).at(location)
        const.end_location = token_end_location

        next_token_skip_space
      end

      const
    end

    def parse_types(allow_primitives = false)
      type = parse_type(allow_primitives)
      case type
      when Array
        type
      when ASTNode
        [type] of ASTNode
      else
        raise "Bug"
      end
    end

    def parse_single_type(allow_primitives = false, allow_commas = true)
      location = @token.location
      type = parse_type(allow_primitives, allow_commas: allow_commas)
      case type
      when Array
        raise "unexpected ',' in type (use parenthesis to disambiguate)", location
      when ASTNode
        type
      else
        raise "Bug"
      end
    end

    def parse_type(allow_primitives, allow_commas = true)
      location = @token.location

      if @token.type == :"->"
        input_types = nil
      else
        input_types = parse_type_union(allow_primitives)
        input_types = [input_types] unless input_types.is_a?(Array)
        while allow_commas && @token.type == :"," && ((allow_primitives && next_comes_type_or_int) || (!allow_primitives && next_comes_type))
          next_token_skip_space_or_newline
          if @token.type == :"->"
            next_types = parse_type(false)
            case next_types
            when Array
              input_types.concat next_types
            when ASTNode
              input_types << next_types
            end
            next
          else
            type_union = parse_type_union(allow_primitives)
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
        when :",", :")", :"}", :";", :NEWLINE
          return_type = nil
        else
          type_union = parse_type_union(allow_primitives)
          if type_union.is_a?(Array)
            raise "can't return more than more type", location.line_number, location.column_number
          else
            return_type = type_union
          end
        end
        Fun.new(input_types, return_type).at(location)
      else
        input_types = input_types.not_nil!
        if input_types.size == 1
          input_types.first
        else
          input_types
        end
      end
    end

    def parse_type_union(allow_primitives)
      types = [] of ASTNode
      parse_type_with_suffix(types, allow_primitives)
      if @token.type == :"|"
        while @token.type == :"|"
          next_token_skip_space_or_newline
          parse_type_with_suffix(types, allow_primitives)
        end

        if types.size == 1
          types.first
        else
          Union.new types
        end
      elsif types.size == 1
        types.first
      else
        types
      end
    end

    def parse_type_with_suffix(types, allow_primitives)
      if @token.type == :IDENT && @token.value == "self?"
        type = Self.new
        type = Union.new([type, Path.global("Nil")] of ASTNode)
        next_token_skip_space
      elsif @token.keyword?(:self)
        type = Self.new
        next_token_skip_space
      else
        case @token.type
        when :"{"
          next_token_skip_space_or_newline
          type = parse_type(allow_primitives)
          check :"}"
          next_token_skip_space
          case type
          when Array
            type = make_tuple_type(type)
          when ASTNode
            type = make_tuple_type([type] of ASTNode)
          else
            raise "Bug"
          end
        when :"("
          next_token_skip_space_or_newline
          type = parse_type(allow_primitives)
          check :")"
          next_token_skip_space
          case type
          when Array
            types.concat type
            return
          when ASTNode
            # skip
          else
            raise "Bug"
          end
        else
          if allow_primitives
            case @token.type
            when :NUMBER
              num = NumberLiteral.new(@token.value.to_s, @token.number_kind).at(@token.location)
              types << node_and_next_token(num)
              skip_space
              return types
            end
          end

          type = parse_simple_type
        end
      end

      types << parse_type_suffix(type)
    end

    def parse_simple_type
      if @token.keyword?(:typeof)
        type = parse_typeof
      else
        type = parse_ident
      end
      skip_space
      type
    end

    def parse_type_suffix(type)
      while true
        case @token.type
        when :"?"
          type = Union.new([type, Path.global("Nil")] of ASTNode)
          next_token_skip_space
        when :"*"
          type = make_pointer_type(type)
          next_token_skip_space
        when :"**"
          type = make_pointer_type(make_pointer_type(type))
          next_token_skip_space
        when :"["
          next_token_skip_space
          size = parse_single_type allow_primitives: true
          check :"]"
          next_token_skip_space
          type = make_static_array_type(type, size)
        when :"+"
          type = Virtual.new(type)
          next_token_skip_space
        when :"."
          next_token
          check_ident :class
          type = Metaclass.new(type)
          next_token_skip_space
        else
          break
        end
      end
      type
    end

    def parse_typeof
      next_token_skip_space
      check :"("
      next_token_skip_space_or_newline
      if @token.type == :")"
        raise "missing typeof argument"
      end

      exps = [] of ASTNode
      while @token.type != :")"
        exps << parse_op_assign
        if @token.type == :","
          next_token_skip_space_or_newline
        end
      end

      end_location = token_end_location
      next_token_skip_space

      TypeOf.new(exps).at_end(end_location)
    end

    def next_comes_type
      next_comes_type_or_int allow_int: false
    end

    def next_comes_type_or_int(allow_int = true)
      old_pos, old_line, old_column = current_pos, @line_number, @column_number

      @temp_token.copy_from(@token)

      next_token_skip_space

      while @token.type == :"{" || @token.type == :"("
        next_token_skip_space
      end

      begin
        case @token.type
        when :CONST
          next_token_skip_space
          if @token.type == :"."
            next_token_skip_space
            if @token.keyword?(:class)
              return true
            end
          else
            return true
          end
        when :UNDERSCORE
          return true
        when :"->"
          return true
        when :NUMBER
          return allow_int && @token.number_kind == :i32
        when :IDENT
          case @token.value
          when :typeof, :self
            return true
          end
        when :"::"
          next_token_skip_space
          if @token.type == :CONST
            return true
          end
        end

        false
      ensure
        @token.copy_from(@temp_token)
        self.current_pos, @line_number, @column_number = old_pos, old_line, old_column
      end
    end

    def make_pointer_type(node)
      Generic.new(Path.global("Pointer").at(node), [node] of ASTNode).at(node)
    end

    def make_static_array_type(type, size)
      Generic.new(Path.global("StaticArray").at(type), [type, size] of ASTNode).at(type.location).at(type)
    end

    def make_tuple_type(types)
      Generic.new(Path.global("Tuple"), types)
    end

    def parse_visibility_modifier(modifier)
      doc = @token.doc

      next_token_skip_space
      exp = parse_op_assign

      modifier = VisibilityModifier.new(modifier, exp)
      modifier.doc = doc
      exp.doc = doc
      modifier
    end

    def parse_asm
      next_token_skip_space
      check :"("
      next_token_skip_space_or_newline
      text = parse_string_without_interpolation { "interpolation not allowed in asm" }
      skip_space_or_newline

      volatile = false
      alignstack = false
      intel = false

      unless @token.type == :")"
        if @token.type == :"::"
          # No output operands
          next_token_skip_space_or_newline

          if @token.type == :DELIMITER_START
            inputs = parse_asm_operands
          end
        else
          check :":"
          next_token_skip_space_or_newline

          if @token.type == :DELIMITER_START
            output = parse_asm_operand
          end

          if @token.type == :":"
            next_token_skip_space_or_newline

            if @token.type == :DELIMITER_START
              inputs = parse_asm_operands
            end
          end
        end

        if @token.type == :"::"
          next_token_skip_space_or_newline
          volatile, alignstack, intel = parse_asm_options
        else
          if @token.type == :":"
            next_token_skip_space_or_newline
            clobbers = parse_asm_clobbers
          end

          if @token.type == :":"
            next_token_skip_space_or_newline
            volatile, alignstack, intel = parse_asm_options
          end
        end

        check :")"
      end

      next_token_skip_space

      Asm.new(text, output, inputs, clobbers, volatile, alignstack, intel)
    end

    def parse_asm_operands
      operands = [] of AsmOperand
      while true
        operands << parse_asm_operand
        if @token.type == :","
          next_token_skip_space_or_newline
        end
        break unless @token.type == :DELIMITER_START
      end
      operands
    end

    def parse_asm_operand
      text = parse_string_without_interpolation { "interpolation not allowed in constraint" }
      check :"("
      next_token_skip_space_or_newline
      exp = parse_expression
      check :")"
      next_token_skip_space_or_newline
      AsmOperand.new(text, exp)
    end

    def parse_asm_clobbers
      clobbers = [] of String
      while true
        clobbers << parse_string_without_interpolation { "interpolation not allowed in asm clobber" }
        skip_space_or_newline
        if @token.type == :","
          next_token_skip_space_or_newline
        end
        break unless @token.type == :DELIMITER_START
      end
      clobbers
    end

    def parse_asm_options
      volatile = false
      alignstack = false
      intel = false
      while true
        location = @token.location
        option = parse_string_without_interpolation { "interpolation not allowed in asm clobber" }
        skip_space_or_newline
        case option
        when "volatile"
          volatile = true
        when "alignstack"
          alignstack = true
        when "intel"
          intel = true
        else
          raise "unknown asm option: #{option}", location
        end

        if @token.type == :","
          next_token_skip_space_or_newline
        end
        break unless @token.type == :DELIMITER_START
      end
      {volatile, alignstack, intel}
    end

    def parse_yield_with_scope
      location = @token.location
      next_token_skip_space
      @stop_on_yield += 1
      @yields ||= 1
      scope = parse_op_assign
      @stop_on_yield -= 1
      skip_space
      check_ident :yield
      parse_yield scope, location
    end

    def parse_yield(scope = nil, location = @token.location)
      end_location = token_end_location
      next_token

      call_args, last_call_has_parenthesis = preserve_last_call_has_parenthesis { parse_call_args }

      if call_args
        args = call_args.args
        end_location = nil
      end

      yields = (@yields ||= 0)
      if args && args.size > yields
        @yields = args.size
      end

      Yield.new(args || [] of ASTNode, scope).at(location).at_end(end_location)
    end

    def parse_break
      parse_control_expression Break
    end

    def parse_return
      parse_control_expression Return
    end

    def parse_next
      parse_control_expression Next
    end

    def parse_control_expression(klass)
      end_location = token_end_location
      next_token

      call_args, last_call_has_parenthesis = preserve_last_call_has_parenthesis do
        @last_call_has_parenthesis = true
        parse_call_args allow_curly: true, control: true
      end
      args = call_args.args if call_args

      if args
        if args.size == 1
          node = klass.new(args.first)
        else
          tuple = TupleLiteral.new(args).at(args.last)
          node = klass.new(tuple)
        end
      else
        node = klass.new.at_end(end_location)
      end

      node
    end

    def parse_lib
      next_token_skip_space_or_newline

      name = check_const
      name_column_number = @token.column_number
      next_token_skip_statement_end

      body = parse_lib_body

      check_ident :end
      next_token_skip_space

      LibDef.new name, body, name_column_number
    end

    def parse_lib_body
      expressions = [] of ASTNode
      while true
        skip_statement_end
        break if is_end_token
        expressions << parse_lib_body_exp
      end
      expressions
    end

    def parse_lib_body_exp
      location = @token.location
      parse_lib_body_exp_without_location.at(location)
    end

    def parse_lib_body_exp_without_location
      case @token.type
      when :"@["
        parse_attribute
      when :IDENT
        case @token.value
        when :alias
          parse_alias
        when :fun
          parse_fun_def
        when :type
          parse_type_def
        when :struct
          @inside_c_struct = true
          node = parse_struct_or_union StructDef
          @inside_c_struct = false
          node
        when :union
          parse_struct_or_union UnionDef
        when :enum
          parse_enum_def
        when :ifdef
          parse_ifdef check_end: true, mode: :lib
        else
          unexpected_token
        end
      when :CONST
        ident = parse_ident
        next_token_skip_space
        check :"="
        next_token_skip_space_or_newline
        value = parse_expression
        skip_statement_end
        Assign.new(ident, value)
      when :GLOBAL
        location = @token.location
        name = @token.value.to_s[1..-1]
        next_token_skip_space_or_newline
        if @token.type == :"="
          next_token_skip_space
          check IdentOrConst
          real_name = @token.value.to_s
          next_token_skip_space
        end
        check :":"
        next_token_skip_space_or_newline
        type = parse_single_type

        if 'A' <= name[0] <= 'Z'
          raise "external variables must start with lowercase, use for example `$#{name.underscore} = #{name} : #{type}`", location
        end

        skip_statement_end
        ExternalVar.new(name, type, real_name)
      else
        unexpected_token
      end
    end

    IdentOrConst = [:IDENT, :CONST]

    def parse_fun_def(require_body = false)
      doc = @token.doc

      push_def if require_body

      next_token_skip_space_or_newline
      name = check_ident
      next_token_skip_space_or_newline

      if @token.type == :"="
        next_token_skip_space_or_newline
        case @token.type
        when :IDENT, :CONST
          real_name = @token.value.to_s
          next_token_skip_space_or_newline
        when :DELIMITER_START
          real_name = parse_string_without_interpolation { "interpolation not allowed in fun name" }
          skip_space
        else
          unexpected_token
        end
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

            args << Arg.new(arg_name, nil, arg_type).at(arg_location)

            push_var_name arg_name if require_body
          else
            arg_types = parse_types
            arg_types.each do |arg_type_2|
              args << Arg.new("", nil, arg_type_2).at(arg_type_2.location)
            end
          end

          if @token.type == :","
            next_token_skip_space_or_newline
          else
            skip_space_or_newline
            check :")"
            break
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
          next_token
        else
          body = parse_expressions
          body, end_location = parse_exception_handler body, implicit: true
        end
      else
        body = nil
      end

      pop_def if require_body

      fun_def = FunDef.new name, args, return_type, varargs, body, real_name
      fun_def.doc = doc
      fun_def
    end

    def parse_alias
      doc = @token.doc

      next_token_skip_space_or_newline
      name = check_const
      next_token_skip_space_or_newline
      check :"="
      next_token_skip_space_or_newline

      value = parse_single_type
      skip_space

      alias_node = Alias.new(name, value)
      alias_node.doc = doc
      alias_node
    end

    def parse_pointerof
      next_token_skip_space

      check :"("
      next_token_skip_space_or_newline

      if @token.keyword?(:self)
        raise "can't take pointerof(self)", @token.line_number, @token.column_number
      end

      exp = parse_op_assign
      skip_space

      end_location = token_end_location
      check :")"
      next_token_skip_space

      PointerOf.new(exp).at_end(end_location)
    end

    def parse_sizeof
      parse_sizeof SizeOf
    end

    def parse_instance_sizeof
      parse_sizeof InstanceSizeOf
    end

    def parse_sizeof(klass)
      next_token_skip_space

      check :"("
      next_token_skip_space_or_newline

      location = @token.location
      exp = parse_single_type.at(location)

      skip_space

      end_location = token_end_location
      check :")"
      next_token_skip_space

      klass.new(exp).at_end(end_location)
    end

    def parse_type_def
      next_token_skip_space_or_newline
      name = check_const
      name_column_number = @token.column_number
      next_token_skip_space_or_newline
      check :"="
      next_token_skip_space_or_newline

      type = parse_single_type
      skip_space

      TypeDef.new name, type, name_column_number
    end

    def parse_struct_or_union(klass)
      next_token_skip_space_or_newline
      name = check_const
      next_token_skip_statement_end
      body = parse_struct_or_union_body
      check_ident :end
      next_token_skip_space

      klass.new name, Expressions.from(body)
    end

    def parse_struct_or_union_body
      exps = [] of ASTNode

      while true
        case @token.type
        when :IDENT
          case @token.value
          when :ifdef
            exps << parse_ifdef(mode: :struct_or_union)
          when :include
            if @inside_c_struct
              location = @token.location
              exps << parse_include.at(location)
            else
              parse_struct_or_union_fields exps
            end
          when :else
            break
          when :end
            break
          else
            parse_struct_or_union_fields exps
          end
        when :";", :NEWLINE
          skip_statement_end
        else
          break
        end
      end

      exps
    end

    def parse_struct_or_union_fields(exps)
      args = [Arg.new(@token.value.to_s).at(@token.location)]

      next_token_skip_space_or_newline

      while @token.type == :","
        next_token_skip_space_or_newline
        args << Arg.new(check_ident).at(@token.location)
        next_token_skip_space_or_newline
      end

      check :":"
      next_token_skip_space_or_newline

      type = parse_single_type

      skip_statement_end

      args.each do |an_arg|
        an_arg.restriction = type
        exps << an_arg
      end
    end

    def parse_enum_def
      doc = @token.doc

      next_token_skip_space_or_newline

      name = parse_ident allow_type_vars: false
      skip_space

      case @token.type
      when :":"
        next_token_skip_space_or_newline
        base_type = parse_single_type
        skip_statement_end
      when :";", :NEWLINE
        skip_statement_end
      else
        unexpected_token
      end

      members = [] of ASTNode
      until @token.keyword?(:end)
        case @token.type
        when :CONST
          location = @token.location
          constant_name = @token.value.to_s
          member_doc = @token.doc

          next_token_skip_space
          if @token.type == :"="
            next_token_skip_space_or_newline

            constant_value = parse_logical_or
            next_token_skip_statement_end
          else
            constant_value = nil
            skip_statement_end
          end

          case @token.type
          when :",", :";"
            next_token_skip_statement_end
          end

          arg = Arg.new(constant_name, constant_value).at(location).at_end(constant_value || location)
          arg.doc = member_doc

          members << arg
        when :IDENT
          visibility = nil

          case @token.value
          when :private
            visibility = :private
            next_token_skip_space
          when :protected
            visibility = :protected
            next_token_skip_space
          end

          def_location = @token.location

          if @token.value == :def
            member = parse_def.at(def_location)
            member = VisibilityModifier.new(visibility, member) if visibility
            members << member
          else
            unexpected_token
          end
        when :CLASS_VAR
          class_var = ClassVar.new(@token.value.to_s).at(@token.location)

          next_token_skip_space
          check :"="
          next_token_skip_space_or_newline
          value = parse_op_assign

          members << Assign.new(class_var, value).at(class_var)
        when :";", :NEWLINE
          skip_statement_end
        else
          unexpected_token
        end
      end

      check_ident :end
      next_token_skip_space

      raise "Bug: EnumDef name can only be a Path" unless name.is_a?(Path)

      enum_def = EnumDef.new name, members, base_type
      enum_def.doc = doc
      enum_def
    end

    def node_and_next_token(node)
      node.end_location = token_end_location
      next_token
      node
    end

    def is_end_token
      case @token.type
      when :"}", :"]", :"%}", :EOF
        return true
      end

      if @token.type == :IDENT
        case @token.value
        when :do, :end, :else, :elsif, :when, :rescue, :ensure
          return true
        end
      end

      false
    end

    def can_be_assigned?(node)
      case node
      when Var, InstanceVar, ClassVar, Path, Global, Underscore
        true
      when Call
        (node.obj.nil? && node.args.size == 0 && node.block.nil?) || node.name == "[]"
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
      push_def(Set.new(args.map &.name))
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

    def push_var(var : Var | Arg)
      push_var_name var.name.to_s
    end

    def push_var(var : TypeDeclaration)
      var_var = var.var
      case var_var
      when Var
        push_var_name var_var.name
      when InstanceVar
        push_var_name var_var.name
      else
        raise "can't happen"
      end
    end

    def push_var_name(name)
      @def_vars.last.add name
    end

    def push_var(node)
      # Nothing
    end

    def open(symbol, location = @token.location)
      @unclosed_stack.push Unclosed.new(symbol, location)
      begin
        value = yield
      ensure
        @unclosed_stack.pop
      end
      value
    end

    def check_void_value(exp, location)
      if exp.is_a?(ControlExpression)
        raise "void value expression", location
      end
    end

    def check_void_expression_keyword
      case @token.type
      when :IDENT
        case @token.value
        when :break, :next, :return
          raise "void value expression", @token, @token.value.to_s.size
        end
      end
    end

    def check(token_types : Array)
      raise "expecting any of these tokens: #{token_types.join ", "} (not '#{@token.type.to_s}')", @token unless token_types.any? { |type| @token.type == type }
    end

    def check(token_type)
      raise "expecting token '#{token_type}', not '#{@token.to_s}'", @token unless token_type == @token.type
    end

    def check_token(value)
      raise "expecting token '#{value}', not '#{@token.to_s}'", @token unless @token.type == :TOKEN && @token.value == value
    end

    def check_ident(value)
      raise "expecting identifier '#{value}', not '#{@token.to_s}'", @token unless @token.keyword?(value)
    end

    def check_ident
      check :IDENT
      @token.value.to_s
    end

    def check_const
      check :CONST
      @token.value.to_s
    end

    def unexpected_token(token = @token.to_s, msg = nil)
      if msg
        raise "unexpected token: #{token} (#{msg})", @token
      else
        raise "unexpected token: #{token}", @token
      end
    end

    def unexpected_token_in_atomic
      if unclosed = @unclosed_stack.last?
        raise "unterminated #{unclosed.name}", unclosed.location
      end

      unexpected_token
    end

    def is_var?(name)
      return true if @in_macro_expression

      name = name.to_s
      name == "self" || @def_vars.last.includes?(name)
    end

    def add_instance_var(name)
      return if @in_macro_expression

      @instance_vars.try &.add name
    end

    def self.free_var_name?(name)
      name.size == 1 || (name.size == 2 && name[1].digit?)
    end
  end
end
