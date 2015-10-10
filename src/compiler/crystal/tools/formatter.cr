module Crystal
  class Formatter < Visitor
    def self.format(source, filename = nil)
      parser = Parser.new(source)
      parser.filename = filename
      nodes = parser.parse

      formatter = new(source)
      formatter.skip_space_or_newline
      nodes.accept formatter
      formatter.finish
      formatter.to_s
    end

    def initialize(source)
      @lexer = Lexer.new(source)
      @lexer.comments_enabled = true
      @lexer.count_whitespace = true
      @lexer.wants_raw = true
      @token = next_token

      @output = StringIO.new(source.bytesize)
      @indent = 0
      @column = 0
      @visibility_indent = nil
      @wrote_newline = false
      @macro_state = Token::MacroState.default
      @inside_macro = 0
      @inside_cond = 0
      @inside_lib = 0
      @inside_struct_or_union = 0
      @arg_needs_prelude = true
      @dot_column = nil
      @def_column = 0
    end

    def visit(node : Expressions)
      if node.expressions.size == 1 && @token.type == :"("
        # If it's (...) with a single expression, we treat it
        # like a single expression, indenting it if needed
        prelude

        column = @column

        write "("
        next_token_skip_space
        if @token.type == :NEWLINE
          next_token_skip_space_or_newline
          write_line
          indent(column + 2, node.expressions.first)
          skip_space_write_line
          skip_space_or_newline
          write_indent(column)
          check :")"
          write ")"
          next_token
          return false
        end
        skip_space_or_newline
        no_indent node.expressions.first
        skip_space_or_newline
        write ")"
        next_token
        return false
      end

      prelude indent: false

      old_indent = @indent
      column = @column
      base_indent = old_indent
      next_needs_indent = true

      has_paren = false
      has_begin = false

      unless starts_with_expressions?(node)
        if @token.type == :"("
          write "("
          next_needs_indent = false
          next_token
          has_paren = true
        elsif @token.keyword?(:begin)
          write "begin"
          write_line
          next_token_skip_space_or_newline
          if @token.type == :";"
            next_token_skip_space_or_newline
          end
          has_begin = true
          @indent = column + 2
          base_indent = @indent
        end
      end

      node.expressions.each_with_index do |exp, i|

        needs_two_lines = !last?(i, node.expressions) && !exp.is_a?(Attribute) &&
                            (!(exp.is_a?(IfDef) && node.expressions[i + 1].is_a?(LibDef))) &&
                            (needs_two_lines?(exp) || needs_two_lines?(node.expressions[i + 1]))

        @indent = 0 unless next_needs_indent
        exp.accept self
        @indent = base_indent

        skip_space

        if @token.type == :";"
          if needs_two_lines
            next_token_skip_space_or_newline
          else
            next_token_skip_space
            if @token.type == :NEWLINE
              write_line
              next_token_skip_space
              next_needs_indent = true
            else
              write "; " unless last?(i, node.expressions)
              skip_space_or_newline
              next_needs_indent = false
            end
          end
        else
          next_needs_indent = true
        end

        if last?(i, node.expressions)
          skip_space_or_newline last: true
        else
          if needs_two_lines
            skip_space_write_line
            write_line
          else
            consume_newlines
          end
        end
      end

      @indent = old_indent

      if has_paren
        check :")"
        write ")"
        next_token
      end

      if has_begin
        check_end
        next_token
        write_line
        @indent = column
        write_indent
        write "end"
      end

      false
    end

    def starts_with_expressions?(node)
      case node
      when Expressions
        first = node.expressions.first?
        first && starts_with_expressions?(first)
      when Call
        node.obj.is_a?(Expressions) || starts_with_expressions?(node.obj)
      when ExceptionHandler
        !node.implicit && !node.suffix
      else
        false
      end
    end

    def needs_two_lines?(node)
      case node
      when Def, ClassDef, ModuleDef, LibDef, StructOrUnionDef, Macro
        true
      else
        false
      end
    end

    def visit(node : Nop)
      prelude

      false
    end

    def visit(node : NilLiteral)
      prelude

      check_keyword :nil
      write "nil"
      next_token

      false
    end

    def visit(node : BoolLiteral)
      prelude

      check_keyword :false, :true
      write node.value
      next_token

      false
    end

    def visit(node : CharLiteral)
      prelude

      check :CHAR
      write @token.raw
      next_token

      false
    end

    def visit(node : SymbolLiteral)
      prelude

      check :SYMBOL
      write @token.raw
      next_token

      false
    end

    def visit(node : NumberLiteral)
      prelude

      if @token.type == :__LINE__
        write @token.type
        next_token
        return false
      end

      check :NUMBER
      write @token.raw
      next_token

      false
    end

    def visit(node : StringLiteral)
      prelude

      if @token.type == :__FILE__ || @token.type == :__DIR__
        write @token.type
        next_token
        return false
      end

      check :DELIMITER_START
      is_regex = @token.delimiter_state.kind == :regex

      write @token.raw
      next_string_token

      while true
        case @token.type
        when :STRING
          write @token.raw
          next_string_token
        when :INTERPOLATION_START
          # This is the case of #{__DIR__}
          write "\#{"
          next_token_skip_space_or_newline
          write @token.type
          next_token_skip_space_or_newline
          check :"}"
          write "}"
          next_string_token
        when :DELIMITER_END
          break
        end
      end

      write @token.raw
      format_regex_modifiers if is_regex

      if space_slash_newline?
        write " \\"
        write_line
        next_token
        visit(node)
      else
        next_token
      end

      false
    end

    def visit(node : StringInterpolation)
      prelude

      check :DELIMITER_START
      is_regex = @token.delimiter_state.kind == :regex

      write @token.raw
      next_string_token

      delimiter_state = @token.delimiter_state

      node.expressions.each do |exp|
        if @token.type == :DELIMITER_END
          # This is for " ... " \
          #             " ... "
          write @token.raw
          write " \\"
          write_line
          next_token_skip_space_or_newline
          check :DELIMITER_START
          write_indent
          write @token.raw
          next_string_token
        end

        if exp.is_a?(StringLiteral)
          # It might be #{__DIR__}, for example
          if @token.type == :INTERPOLATION_START
            next_token_skip_space_or_newline
            write "\#{"
            write @token.type
            next_token_skip_space_or_newline
            check :"}"
            write "}"
          else
            write @token.raw
          end
          next_string_token
        else
          check :INTERPOLATION_START
          write "\#{"
          delimiter_state = @token.delimiter_state
          next_token_skip_space_or_newline
          no_indent exp
          skip_space_or_newline
          check :"}"
          write "}"
          @token.delimiter_state = delimiter_state
          next_string_token
        end
      end

      check :DELIMITER_END
      write @token.raw
      format_regex_modifiers if is_regex
      next_token

      false
    end

    def visit(node : RegexLiteral)
      node.value.accept self

      false
    end

    def format_regex_modifiers
      while true
        char = @lexer.current_char
        case char
        when 'i', 'm', 'x'
          write char
          @lexer.next_char
        else
          break
        end
      end
    end

    def space_slash_newline?
      pos = @lexer.reader.pos
      while true
        char = @lexer.current_char
        case char
        when ' ', '\t'
          @lexer.next_char
        when '\\'
          @lexer.reader.pos = pos
          return true
        else
          break
        end
      end
      @lexer.reader.pos = pos
      false
    end

    def visit(node : ArrayLiteral)
      prelude

      case @token.type
      when :"["
        format_array_or_tuple_elements node.elements, :"[", :"]"
      when :"[]"
        write "[]"
        next_token
      when :STRING_ARRAY_START, :SYMBOL_ARRAY_START
        first = true
        if @token.type == :STRING_ARRAY_START
          write "%w("
        else
          write "%i("
        end
        while true
          next_string_array_token
          case @token.type
          when :STRING
            write " " unless first
            write @token.raw
            first = false
          when :STRING_ARRAY_END
            write ")"
            next_token
            break
          end
        end
        return false
      else
        name = node.name.not_nil!
        no_indent name
        skip_space
        format_array_or_tuple_elements node.elements, :"{", :"}"
      end

      if node_of = node.of
        skip_space_or_newline
        check_keyword :of
        write " of "
        next_token_skip_space_or_newline
        no_indent node_of
      end

      false
    end

    def visit(node : TupleLiteral)
      prelude

      format_array_or_tuple_elements node.elements, :"{", :"}"

      false
    end

    def format_array_or_tuple_elements(elements, prefix, suffix)
      check prefix
      write prefix
      slash_is_regex!
      next_token
      prefix_indent = @column
      base_indent = @column
      has_newlines = false
      wrote_newline = false
      write_space_at_end = false
      next_needs_indent = false
      found_comment = false

      skip_space
      if @token.type == :NEWLINE
        if elements.empty?
          skip_space_or_newline
          check suffix
          write suffix
          next_token
          return false
        end

        base_indent += 1
        consume_newlines
        skip_space_or_newline
        wrote_newline = true
        next_needs_indent = true
        has_newlines = true
      end

      elements.each_with_index do |element, i|
        # This is to prevent writing `{{`
        if prefix == :"{" && i == 0 && !wrote_newline && (element.is_a?(TupleLiteral) || element.is_a?(HashLiteral))
          write " "
          write_space_at_end = true
        end

        if next_needs_indent
          indent(base_indent, element)
        else
          no_indent element
        end

        last = last?(i, elements)

        found_comment = skip_space(write_comma: last  && has_newlines)

        if @token.type == :","
          write "," unless last || found_comment
          slash_is_regex!
          next_token
          found_comment = skip_space(write_comma: last && has_newlines)
          if @token.type == :NEWLINE
            if last && !found_comment
              write ","
              found_comment = true
            end
            consume_newlines
            skip_space_or_newline
            next_needs_indent = true
            has_newlines = true
          else
            write " " unless last || found_comment
          end
        end
      end

      if has_newlines
        unless found_comment
          write ","
          write_line
        end
        write_indent(prefix_indent - 1)
      elsif write_space_at_end
        write " "
      end

      skip_space_or_newline
      check suffix
      write suffix

      next_token
    end

    def visit(node : HashLiteral)
      prelude

      if name = node.name
        no_indent name
        skip_space
      end

      check :"{"
      write "{"
      slash_is_regex!
      next_token

      prefix_indent = @column
      base_indent = @column
      has_newlines = false
      wrote_newline = false
      write_space_at_end = false

      old_indent = @indent
      @indent = 0

      skip_space
      if @token.type == :NEWLINE
        base_indent += 1
        wrote_newline = true
      end

      node.entries.each_with_index do |entry, i|
        skip_space
        if @token.type == :NEWLINE
          @indent = base_indent
          consume_newlines
          has_newlines = true
        elsif i > 0
          write " "
        end
        skip_space_or_newline
        write_indent(@indent)

        # This is to prevent writing `{{`
        if i == 0 && !wrote_newline && (entry.key.is_a?(TupleLiteral) || entry.key.is_a?(HashLiteral))
          write " "
          write_space_at_end = true
        end

        format_hash_entry entry
        @indent = 0
        skip_space_or_newline
        if @token.type == :","
          write "," unless last?(i, node.entries)
          slash_is_regex!
          next_token
        end
      end

      @indent = old_indent

      skip_space_or_newline
      check :"}"

      if has_newlines
        write ","
        write_line
        write_indent(prefix_indent - 1)
      elsif write_space_at_end
        write " "
      end

      write "}"
      next_token

      if node_of = node.of
        skip_space_or_newline
        check_keyword :of
        write " of "
        next_token_skip_space_or_newline
        no_indent { format_hash_entry node_of }
      end

      false
    end

    def format_hash_entry(entry)
      if entry.key.is_a?(SymbolLiteral) && @token.type == :IDENT
        write @token
        write ": "
        next_token
        check :":"
      else
        no_indent entry.key
        skip_space_or_newline

        if @token.type == :":" && entry.key.is_a?(StringLiteral)
          write ": "
        else
          check :"=>"
          write " => "
        end
      end
      slash_is_regex!
      next_token_skip_space_or_newline
      no_indent entry.value
    end

    def visit(node : RangeLiteral)
      node.from.accept self
      skip_space_or_newline
      if node.exclusive
        check :"..."
        write "..."
      else
        check :".."
        write ".."
      end
      next_token_skip_space_or_newline
      node.to.accept self
      false
    end

    def visit(node : Path)
      prelude

      has_parentheses = false

      if @token.type == :"("
        write "("
        next_token_skip_space
        has_parentheses = true
      end

      # Sometimes the :: is not present because the parser generates ::Nil, for example
      if node.global && @token.type == :"::"
        write "::"
        next_token_skip_space_or_newline
      end

      node.names.each_with_index do |name, i|
        skip_space_or_newline
        check :CONST
        write @token.value
        next_token
        skip_space unless last?(i, node.names)
        if @token.type == :"::"
          write "::"
          next_token
        end
      end

      if has_parentheses
        skip_space_or_newline
        check :")"
        write ")"
        next_token
      end

      false
    end

    def visit(node : Generic)
      prelude

      name = node.name
      first_name = name.global && name.names.size == 1 && name.names.first

      # Check if it's T* instead of Pointer(T)
      if first_name == "Pointer" && @token.value != "Pointer"
        type_var = node.type_vars.first
        type_var.accept self
        skip_space_or_newline

        # Another case is T** instead of Pointer(Pointer(T))
        if @token.type == :"**"
          if type_var.is_a?(Generic)
            write "**"
            next_token
          else
            # Skip
          end
        else
          check :"*"
          write "*"
          next_token
        end

        return false
      end

      # Check if it's T[N] instead of StaticArray(T, N)
      if first_name == "StaticArray" && @token.value != "StaticArray"
        node.type_vars[0].accept self
        skip_space_or_newline
        check :"["
        write "["
        next_token_skip_space_or_newline
        node.type_vars[1].accept self
        skip_space_or_newline
        check :"]"
        write "]"
        next_token
        return false
      end

      # Check if it's {A, B} instead of Tuple(A, B)
      if first_name == "Tuple" && @token.value != "Tuple"
        check :"{"
        write "{"
        next_token_skip_space_or_newline
        node.type_vars.each_with_index do |type_var, i|
          no_indent type_var
          skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, node.type_vars)
            next_token_skip_space_or_newline
          end
        end
        check :"}"
        write "}"
        next_token
        return false
      end

      name.accept self
      skip_space_or_newline

      check :"("
      write "("
      next_token_skip_space_or_newline

      node.type_vars.each_with_index do |type_var, i|
        no_indent type_var
        skip_space_or_newline
        if @token.type == :","
          write ", " unless last?(i, node.type_vars)
          next_token_skip_space_or_newline
        end
      end

      check :")"
      write ")"
      next_token

      false
    end

    def visit(node : Union)
      has_parentheses = false
      if @token.type == :"("
        write "("
        next_token_skip_space_or_newline
        has_parentheses = true
      end

      node.types.each_with_index do |type, i|
        no_indent type

        last = last?(i, node.types)
        skip_space_or_newline unless last

        # This can happen if it's a nilable type written like T?
        case @token.type
        when :"?"
          write " " if type.is_a?(Self)
          write "?"
          next_token
          break
        when :"|"
          write " | " unless last
          next_token
          skip_space_or_newline unless last
        when :")"
          # This can happen in a case like (A)?
          break
        end
      end

      if has_parentheses
        check :")"
        write ")"
        next_token_skip_space
      end

      # This can happen in a case like (A)?
      if @token.type == :"?"
        write "?"
        next_token
      end

      false
    end

    def visit(node : If)
      visit_if_or_unless node, :if
    end

    def visit(node : Unless)
      visit_if_or_unless node, :unless
    end

    def visit(node : IfDef)
      visit_if_or_unless node, :ifdef
    end

    def visit_if_or_unless(node, keyword)
      prelude

      if !@token.keyword?(keyword) && node.else.is_a?(Nop)
        # Suffix if/unless
        no_indent node.then
        skip_space_or_newline
        check_keyword keyword
        write " "
        write keyword
        write " "
        next_token_skip_space_or_newline
        no_indent node.cond
        return false
      end

      # This is the case of `cond ? exp1 : exp2`
      if keyword == :if && !@token.keyword?(:if)
        no_indent node.cond
        skip_space_or_newline
        check :"?"
        write " ? "
        next_token_skip_space_or_newline
        no_indent node.then
        skip_space_or_newline
        check :":"
        write " : "
        next_token_skip_space_or_newline
        no_indent node.else
        return false
      end

      column = @column

      check_keyword keyword
      write keyword
      write " "
      next_token_skip_space_or_newline

      format_if_at_cond node, column

      false
    end

    def format_if_at_cond(node, column, check_end = true)
      inside_cond do
        no_indent node.cond
      end

      indent(column + 2) { skip_space }
      skip_semicolon
      format_nested node.then, column
      indent(column + 2) { skip_space_or_newline last: true }
      jump_semicolon

      node_else = node.else

      if @token.keyword?(:else)
        write_indent(column)
        write "else"
        next_token
        indent(column + 2) { skip_space }
        skip_semicolon
        format_nested node.else, column
      elsif node_else.is_a?(If) && @token.keyword?(:elsif)
        format_elsif node_else, column
      elsif node_else.is_a?(IfDef) && @token.keyword?(:elsif)
        format_elsif node_else, column
      end

      if check_end
        format_end column
      end
    end

    def format_elsif(node_else, column)
      write_indent(column)
      write "elsif "
      next_token_skip_space_or_newline
      format_if_at_cond node_else, column, check_end: false
    end

    def visit(node : While)
      format_while_or_until node, :while
    end

    def visit(node : Until)
      format_while_or_until node, :until
    end

    def format_while_or_until(node, keyword)
      prelude

      column = @column

      check_keyword keyword
      write keyword
      write " "
      next_token_skip_space_or_newline
      inside_cond { no_indent node.cond }

      format_nested_with_end node.body, column

      false
    end

    def format_nested(node, column, write_end_line = true)
      slash_is_regex!
      if node.is_a?(Nop)
        skip_nop(column + 2)
      else
        indent(column + 2) do
          skip_space_write_line
          skip_space_or_newline
          node.accept self
          skip_space_write_line if write_end_line
        end
      end
    end

    def format_nested_with_end(node, column, write_end_line = true)
      indent(column + 2) { skip_space }

      if @token.type == :";"
        if node.is_a?(Nop)
          next_token_skip_space_or_newline
          check_end
          write "; end"
          next_token
          return false
        else
          next_token_skip_space
        end
      end

      format_nested node, column, write_end_line: write_end_line
      format_end(column)
    end

    def format_end(column)
      indent(column + 2) { skip_space_or_newline last: true }
      check_end
      write_indent(column)
      write "end"
      next_token
    end

    def visit(node : Def)
      column = prelude_with_visibility_check
      @def_column = column

      if node.abstract
        check_keyword :abstract
        write "abstract "
        next_token_skip_space_or_newline
      end

      if node.macro_def?
        check_keyword :macro
        write "macro "
        next_token_skip_space_or_newline
      end

      check_keyword :def
      write "def "
      next_token

      if receiver = node.receiver
        skip_space_or_newline
        no_indent receiver
        skip_space_or_newline
        check :"."
        write "."
        next_token
      end

      if @lexer.current_char == '%'
        @token.type = "%"
        @token.column_number += 1
        @lexer.next_char
      end

      skip_space_or_newline

      write node.name
      next_token_skip_space
      next_token_skip_space if @token.type == :"="

      to_skip = format_def_args node

      if return_type = node.return_type
        skip_space
        check :":"
        write " : "
        next_token_skip_space_or_newline
        no_indent node.return_type.not_nil!
      end

      if node.macro_def?
        format_macro_body node, column

        return false
      end

      body = node.body

      if to_skip > 0
        body = node.body
        if body.is_a?(Expressions)
          body.expressions = body.expressions[to_skip .. -1]
          if body.expressions.empty?
            body = Nop.new
          end
        else
          body = Nop.new
        end
      end

      unless node.abstract
        format_nested_with_end body, column
      end

      false
    end

    def format_def_args(node : ASTNode)
      format_def_args node.args, node.block_arg, node.splat_index, false
    end

    def format_def_args(args : Array, block_arg, splat_index, variadic)
      to_skip = 0

      # If there are no args, remove extra "()", if any
      if args.empty?
        if @token.type == :"("
          next_token_skip_space_or_newline

          if block_arg
            check :"&"
            write "(&"
            next_token_skip_space
            to_skip += 1 if at_skip?
            no_indent block_arg
            skip_space_or_newline
            write ")"
          end

          if variadic
            skip_space_or_newline
            check :"..."
            write "(...)"
            next_token_skip_space_or_newline
          end

          check :")"
          next_token
        elsif block_arg
          skip_space_or_newline
          check :"&"
          write " &"
          next_token_skip_space
          to_skip += 1 if at_skip?
          no_indent block_arg
          skip_space
        end
      else
        prefix_size = @column + 1

        old_indent = @indent
        next_needs_indent = false
        has_parentheses = false
        @indent = 0

        if @token.type == :"("
          has_parentheses = true
          write "("
          next_token_skip_space
          if @token.type == :NEWLINE
            write_line
            next_needs_indent = true
          end
          skip_space_or_newline
        else
          write " "
        end

        args.each_with_index do |arg, i|
          @indent = prefix_size if next_needs_indent

          if i == splat_index
            check :"*"
            write "*"
            next_token_skip_space_or_newline
          end

          to_skip += 1 if at_skip?
          arg.accept self
          @indent = 0
          skip_space_or_newline
          if @token.type == :","
            write "," unless last?(i, args)
            next_token_skip_space
            if @token.type == :NEWLINE
              unless last?(i, args)
                write_line
                next_needs_indent = true
              end
            else
              next_needs_indent = false
              write " " unless last?(i, args)
            end
            skip_space_or_newline
          end
        end

        if block_arg
          check :"&"
          write ", &"
          next_token_skip_space
          to_skip += 1 if at_skip?
          no_indent block_arg
          skip_space
        end

        if variadic
          check :"..."
          write ", ..."
          next_token_skip_space_or_newline
        end

        if has_parentheses
          check :")"
          write ")"
          next_token
        end

        @indent = old_indent
      end

      to_skip
    end

    # The parser transforms `def foo(@x); end` to `def foo(x); @x = x; end` so if we
    # find an instance var we later need to skip the first expressions in the body
    def at_skip?
      @token.type == :INSTANCE_VAR || @token.type == :CLASS_VAR
    end

    def visit(node : FunDef)
      prelude

      column = @column

      check_keyword :fun
      write "fun "
      next_token_skip_space_or_newline

      check :IDENT
      write node.name
      next_token_skip_space

      if @token.type == :"="
        write " = "
        next_token_skip_space
        if @token.type == :DELIMITER_START
          no_indent StringLiteral.new(node.real_name)
        else
          write node.real_name
          next_token_skip_space
        end
      end

      format_def_args node.args, nil, nil, node.varargs

      if return_type = node.return_type
        skip_space
        check :":"
        write " : "
        next_token_skip_space_or_newline
        no_indent return_type
      end

      if body = node.body
        format_nested_with_end body, column
      end

      false
    end

    def visit(node : Macro)
      column = prelude_with_visibility_check

      check_keyword :macro
      write "macro "
      next_token_skip_space_or_newline

      check :IDENT
      write node.name
      next_token

      format_def_args node
      format_macro_body node, column

      false
    end

    def format_macro_body(node, column)
      if @token.keyword?(:end)
        write_line
        write "end"
        next_token
        return false
      end

      next_macro_token

      inside_macro do
        format_nested node.body, column, write_end_line: false
      end

      skip_space_or_newline
      check :MACRO_END
      write "end"
      next_token
    end

    def visit(node : MacroLiteral)
      write @token.raw
      next_macro_token
      false
    end

    def visit(node : MacroExpression)
      prelude unless inside_macro?

      if node.output
        if inside_macro?
          check :MACRO_EXPRESSION_START
        else
          check :"{{"
        end
        write "{{"
      else
        check :MACRO_CONTROL_START
        write "{% "
      end
      macro_state = @macro_state
      next_token_skip_space_or_newline
      no_indent node.exp
      skip_space_or_newline
      @macro_state = macro_state

      if node.output
        check :"}"
        next_token
        check :"}"
        write "}}"
      else
        check :"%}"
        write " %}"
      end

      if inside_macro?
        check_macro_whitespace
        next_macro_token
      else
        next_token
      end

      false
    end

    def visit(node : MacroIf)
      prelude unless inside_macro?

      if inside_macro?
        check :MACRO_CONTROL_START
      else
        check :"{%"
      end
      write "{% "

      macro_state = @macro_state
      next_token_skip_space_or_newline

      if @token.keyword?(:begin)
        # This is rewritten to `if true`
        write "begin"
        next_token_skip_space_or_newline
      elsif @token.keyword?(:unless)
        # This is rewritten to `if !...`
        node.then, node.else = node.else, node.then
        write "unless "
        next_token_skip_space_or_newline

        outside_macro { no_indent node.cond }
        skip_space_or_newline
      else
        check_keyword :if
        write "if "
        next_token_skip_space_or_newline

        outside_macro { no_indent node.cond }
        skip_space_or_newline
      end

      check :"%}"
      write " %}"

      @macro_state = macro_state
      check_macro_whitespace
      next_macro_token

      inside_macro { no_indent node.then }

      unless node.else.is_a?(Nop)
        check :MACRO_CONTROL_START
        macro_state = @macro_state
        next_token_skip_space_or_newline

        check_keyword :else
        next_token_skip_space_or_newline
        check :"%}"

        write "{% else %}"
        check_macro_whitespace
        next_macro_token

        inside_macro { no_indent node.else }
      end

      check :MACRO_CONTROL_START
      macro_state = @macro_state
      next_token_skip_space_or_newline

      check_end
      next_token_skip_space_or_newline
      check :"%}"

      write "{% end %}"

      if inside_macro?
        check_macro_whitespace
        next_macro_token
      else
        next_token
      end

      false
    end

    def visit(node : MacroFor)
      prelude unless inside_macro?

      if inside_macro?
        check :MACRO_CONTROL_START
      else
        check :"{%"
      end
      write "{% "

      macro_state = @macro_state
      next_token_skip_space_or_newline

      check_keyword :for
      write "for "
      next_token_skip_space_or_newline

      outside_macro do
        node.vars.each_with_index do |var, i|
          no_indent var
          unless last?(i, node.vars)
            skip_space_or_newline
            if @token.type == :","
              write ", "
              next_token_skip_space_or_newline
            end
          end
        end
      end

      skip_space_or_newline

      check_keyword :in
      write " in "
      next_token_skip_space_or_newline

      outside_macro { no_indent node.exp }
      skip_space_or_newline

      check :"%}"
      write " %}"

      check_macro_whitespace
      next_macro_token

      inside_macro { no_indent node.body }

      check :MACRO_CONTROL_START
      macro_state = @macro_state
      next_token_skip_space_or_newline

      check_end
      next_token_skip_space_or_newline
      check :"%}"

      write "{% end %}"

      if inside_macro?
        check_macro_whitespace
        next_macro_token
      else
        next_token
      end

      false
    end

    def visit(node : MacroVar)
      check :MACRO_VAR
      write "%"
      write node.name
      next_macro_token

      false
    end

    def visit(node : Arg)
      prelude if @arg_needs_prelude
      @arg_needs_prelude = true

      restriction = node.restriction

      if @inside_lib > 0
        # This is the case of `fun foo(Char)`
        if @token.type != :IDENT && restriction
          no_indent restriction
          return false
        end
      end

      write @token.value
      next_token

      if default_value = node.default_value
        skip_space_or_newline
        check :"="
        write " = "
        next_token_skip_space_or_newline
        no_indent default_value
      end

      if restriction
        skip_space_or_newline

        # This is for a case like `x, y : Int32`
        if @inside_struct_or_union && @token.type == :","
          @arg_needs_prelude = false
          write ", "
          next_token
          return false
        end

        check :":"
        write " : "
        next_token_skip_space_or_newline
        no_indent restriction
      end

      false
    end

    def visit(node : Splat)
      prelude

      check :"*"
      write "*"
      next_token_skip_space_or_newline
      no_indent node.exp

      false
    end

    def visit(node : BlockArg)
      write @token.value
      next_token_skip_space

      if (restriction = node.fun) && @token.type == :":"
        skip_space_or_newline
        check :":"
        write " : "
        next_token_skip_space_or_newline
        no_indent restriction
      end

      false
    end

    def visit(node : Fun)
      has_parentheses = false
      if @token.type == :"("
        write "("
        next_token_skip_space_or_newline
        has_parentheses = true
      end

      if inputs = node.inputs
        inputs.each_with_index do |input, i|
          input.accept self
          skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, inputs)
            next_token_skip_space_or_newline
          end
        end
      end

      if @token.type == :")"
        next_token_skip_space
        write ")"
        has_parentheses = false
      end

      write " " if inputs

      check :"->"
      write "->"
      next_token

      if output = node.output
        write " "
        skip_space_or_newline
        output.accept self
      end

      if has_parentheses
        check :")"
        write ")"
        next_token
      end

      false
    end

    def visit(node : Self)
      check_keyword :self
      write "self"
      next_token
      false
    end

    def visit(node : Var)
      prelude
      write node.name
      next_token
      false
    end

    def visit(node : InstanceVar)
      prelude
      write node.name
      next_token
      false
    end

    def visit(node : ClassVar)
      prelude
      write node.name
      next_token
      false
    end

    def visit(node : Global)
      prelude
      write node.name
      next_token
      false
    end

    def visit(node : ReadInstanceVar)
      node.obj.accept self

      skip_space_or_newline
      check :"."
      write "."
      next_token_skip_space_or_newline
      write node.name
      next_token

      false
    end

    def visit(node : Call)
      # This is the case of `...`
      if node.name == "`"
        node.args.first.accept self
        return false
      end

      base_column = prelude_with_visibility_check
      obj = node.obj

      # Special cases
      if @token.type == :"$~" && node.name == "not_nil!" && obj.is_a?(Var) && obj.name == "$~"
        write "$~"
        next_token
        return false
      end

      if @token.type == :"$?" && node.name == "not_nil!" && obj.is_a?(Var) && obj.name == "$?"
        write "$?"
        next_token
        return false
      end

      if @token.type == :GLOBAL_MATCH_DATA_INDEX && node.name == "[]" && obj.is_a?(Call) && obj.name == "not_nil!"
        obj2 = obj.obj
        if obj2.is_a?(Var) && obj2.name == "$~"
          write "$"
          write @token.value
          next_token
          return false
        end
      end

      if node.global
        check :"::"
        write "::"
        next_token
      end

      if obj
        {:"!", :"+", :"-", :"~"}.each do |op|
          if node.name == op.to_s && @token.type == op && node.args.empty?
            write op
            next_token_skip_space_or_newline
            no_indent obj
            return false
          end
        end

        no_indent obj
        skip_space

        # It's something like `foo.bar\n
        #                         .baz`
        if @token.type == :NEWLINE
          newline_indent = @dot_column || @column
          indent(newline_indent) { consume_newlines }
          write_indent(newline_indent)
        end

        if @token.type != :"."
          # It's an operator
          if @token.type == :"["
            write "["
            next_token_skip_space_or_newline

            args = node.args

            if node.name == "[]="
              last_arg = args.pop
            end

            args.each_with_index do |arg, i|
              no_indent arg
              skip_space_or_newline
              if @token.type == :","
                unless last?(i, args)
                  write ", "
                end
                next_token_skip_space_or_newline
              end
            end
            check :"]"
            write "]"
            next_token

            if node.name == "[]?"
              skip_space

              # This might not be present in the case of `x[y] ||= z`
              if @token.type == :"?"
                write "?"
                next_token
              end
            end

            if last_arg
              skip_space_or_newline

              if @token.type != :"="
                # This is the case of `x[y] op= value`
                write " "
                write @token.type
                write " "
                next_token_skip_space_or_newline
                no_indent (last_arg as Call).args.last
                return false
              end

              write " = "
              next_token_skip_space_or_newline
              no_indent last_arg
            end

            return false
          elsif @token.type == :"[]"
            write "[]"
            next_token

            if node.name == "[]="
              skip_space_or_newline
              check :"="
              write " = "
              next_token_skip_space_or_newline
              no_indent node.args.last
            end

            return false
          else
            write " "
            write node.name

            # This is the case of a-1 and a+1
            if @token.type == :NUMBER
              write " "
              write @token.raw[1..-1]
              next_token
              return false
            end

            slash_is_regex!
          end

          next_token
          found_comment = skip_space
          if found_comment || @token.type == :NEWLINE
            skip_space_write_line
            indent(base_column + 2, node.args.last)
          else
            write " "
            no_indent node.args.last
          end
          return false
        end

        next_token
        skip_space
        if @token.type == :NEWLINE
          newline_indent = @dot_column || @column
          indent(newline_indent) { consume_newlines }
          write_indent(newline_indent)
        end

        @dot_column = @column
        write "."

        skip_space_or_newline
      end

      # This is for foo &.[bar] and &.[bar]?
      if !obj && (node.name == "[]" || node.name == "[]?") && @token.type == :"["
        write "["
        next_token_skip_space_or_newline
        format_call_args(node, false)
        check :"]"
        write "]"
        next_token
        if node.name == "[]?"
          check :"?"
          write "?"
          next_token
        end
        return false
      end

      current_dot_column = @dot_column

      assignment = node.name.ends_with?('=') && node.name.chars.any?(&.alpha?)

      if assignment
        write node.name[0 ... -1]
      else
        write node.name
      end
      next_token

      if assignment
        skip_space

        if @token.type != :"="
          # It's something like `foo.bar += 1`
          write " "
          write @token.type
          write " "
          next_token_skip_space_or_newline
          no_indent (node.args.last as Call).args.last
          @dot_column = current_dot_column
          return false
        end

        next_token
        if @token.type == :"("
          write "=("
          has_parentheses = true
          slash_is_regex!
          next_token
          format_call_args(node, true)
          skip_space_or_newline
          check :")"
          write ")"
          next_token
        else
          skip_space_or_newline
          write " = "
          no_indent node.args.last
        end

        @dot_column = current_dot_column
        return false
      end

      has_parentheses = false
      ends_with_newline = false
      has_args = !node.args.empty? || node.named_args

      column = @column
      has_newlines = false

      if @token.type == :"("
        check :"("
        slash_is_regex!
        next_token
        if obj && !has_args && !node.block_arg && !node.block
          skip_space_or_newline
          check :")"
          next_token
          @dot_column = current_dot_column
          return false
        end

        write "("
        has_parentheses = true
        has_newlines = format_call_args(node, true)
        skip_space
        if @token.type == :NEWLINE
          ends_with_newline = true
        end
        skip_space_or_newline
      elsif has_args || node.block_arg
        write " "
        skip_space
        has_newlines = format_call_args(node, false)
      end

      if block = node.block
        needs_space = !has_parentheses || has_args
        skip_space
        if has_parentheses && @token.type == :")"
          write ")"
          next_token_skip_space_or_newline
          format_block block, base_column, needs_space
          @dot_column = current_dot_column
          return false
        end
        format_block block, base_column, needs_space
      end

      if has_parentheses
        if @token.type == :","
          next_token_skip_space_or_newline
          if has_newlines
            write ","
            write_line
            write_indent(column)
          end
        end
        check :")"

        if ends_with_newline
          write_line
          write_indent(column)
        end
        write ")"
        next_token
      end

      @dot_column = current_dot_column
      false
    end

    def format_call_args(node : ASTNode, has_parentheses)
      format_args node.args, has_parentheses, node.named_args, node.block_arg
    end

    def format_args(args : Array, has_parentheses, named_args = nil, block_arg = nil)
      column = @column
      needed_indent = has_parentheses ? column + 1 : column
      next_needs_indent = false
      has_newlines = false

      if @token.type == :NEWLINE
        write_line
        indent(needed_indent) { next_token_skip_space_or_newline }
        next_needs_indent = true
        has_newlines = true
      else
        needed_indent = column
      end

      skip_space_or_newline
      args.each_with_index do |arg, i|
        if next_needs_indent
          indent(needed_indent, arg)
        else
          no_indent arg
        end
        next_needs_indent = false
        unless last?(i, args)
          skip_space
          check :","
          write ","
          slash_is_regex!
          next_token_skip_space
          if @token.type == :NEWLINE
            indent(needed_indent) { consume_newlines }
            next_needs_indent = true
            has_newlines = true
          else
            write " "
          end
          skip_space_or_newline
        end
      end

      if named_args
        skip_space

        next_needs_indent = false

        named_args_column = @column

        unless args.empty?
          check :","
          write ","
          next_token_skip_space
          if @token.type == :NEWLINE
            write_line
            indent(needed_indent) { next_token_skip_space_or_newline }
            next_needs_indent = true
            has_newlines = true
            named_args_column = needed_indent
          else
            write " "
            skip_space_or_newline
            named_args_column = @column
          end
        end

        needed_indent = named_args_column

        named_args.each_with_index do |named_arg, i|
          write_indent(named_args_column) if next_needs_indent
          no_indent named_arg

          next_needs_indent = false

          unless last?(i, named_args)
            skip_space
            if @token.type == :","
              write ","
              next_token_skip_space
              if @token.type == :NEWLINE
                write_line
                next_token_skip_space_or_newline
                next_needs_indent = true
                has_newlines = true
              else
                write " "
              end
              skip_space_or_newline
            end
          end
        end
      end

      if block_arg
        skip_space_or_newline
        if @token.type == :","
          write ","
          next_token_skip_space
          if @token.type == :NEWLINE
            write_line
            write_indent(needed_indent)
            has_newlines = true
          else
            write " "
          end
        end
        skip_space_or_newline
        check :"&"
        write "&"
        next_token_skip_space_or_newline
        no_indent block_arg
      end

      has_newlines
    end

    def visit(node : NamedArgument)
      write node.name
      next_token_skip_space_or_newline
      check :":"
      write ": "
      next_token_skip_space_or_newline
      no_indent node.value

      false
    end

    def format_block(node, base_column, needs_space)
      needs_comma = false

      if @token.type == :","
        needs_comma = true
        next_token_skip_space_or_newline
      end

      if @token.keyword?(:do)
        write " do"
        next_token_skip_space_or_newline
        format_block_args node.args
        format_nested_with_end node.body, base_column
      elsif @token.type == :"{"
        check :"{"
        write "," if needs_comma
        write " {"
        next_token_skip_space
        format_block_args node.args
        if @token.type == :NEWLINE
          write_line
          indent(base_column + 2, node.body)
          skip_space_or_newline
          write_line
          check :"}"
          write_indent(base_column)
          write "}"
        else
          unless node.body.is_a?(Nop)
            write " "
            no_indent node.body
          end
          skip_space_or_newline
          check :"}"
          write " }"
        end
        next_token
      else
        # It's foo &.bar
        write "," if needs_comma
        check :"&"
        next_token_skip_space_or_newline
        check :"."
        next_token_skip_space_or_newline
        write " " if needs_space
        write "&."

        body = node.body
        case body
        when Call
          call = body
          clear_obj call

          if !call.obj && (call.name == "[]") && call.name == "[]?"
            check :"["
            write "["
            next_token_skip_space_or_newline
            format_call_args(call, false)
            skip_space_or_newline
            check :"]"
            write "]"
            next_token
            if call.name == "[]?"
              check :"?"
              write "?"
              next_token
            end
          else
            no_indent call
          end
        when IsA
          call = Call.new(nil, "is_a?", args: [body.const] of ASTNode)
          no_indent call
        when RespondsTo
          call = Call.new(nil, "responds_to?", args: [SymbolLiteral.new(body.name.to_s)] of ASTNode)
          no_indent call
        else
          raise "Bug: expected Call, IsA or RespondsTo as &. argument, at #{node.location}"
        end
      end
    end

    def format_block_args(args)
      return if args.empty?

      check :"|"
      write " |"
      next_token_skip_space_or_newline
      args.each_with_index do |arg, i|
        no_indent arg
        skip_space_or_newline
        if @token.type == :","
          next_token_skip_space_or_newline
          write ", " unless last?(i, args)
        end
      end
      skip_space_or_newline
      check :"|"
      write "|"
      next_token_skip_space
    end

    def visit(node : IsA)
      format_special_call(node, :is_a?) do
        no_indent node.const
        skip_space_or_newline
      end
    end

    def visit(node : RespondsTo)
      format_special_call(node, :responds_to?) do
        check :SYMBOL
        write @token.raw
        next_token_skip_space_or_newline
      end
    end

    def format_special_call(node, keyword)
      node.obj.accept self
      skip_space_or_newline
      check :"."
      write "."
      next_token_skip_space_or_newline
      check_keyword keyword
      write keyword
      next_token_skip_space_or_newline

      has_parentheses = false
      if @token.type == :"("
        write "("
        next_token_skip_space_or_newline
        has_parentheses = true
      else
        write " "
      end

      yield

      if has_parentheses
        check :")"
        write ")"
        next_token
      end

      false
    end

    def visit(node : Or)
      format_binary node, :"||", :"||="
    end

    def visit(node : And)
      format_binary node, :"&&", :"&&="
    end

    def format_binary(node, token, alternative)
      prelude

      column = @column

      no_indent { node.left.accept self }
      skip_space_or_newline

      # This is the case of `left ||= right`
      if @token.type == alternative
        write " "
        write alternative
        write " "
        next_token_skip_space
        case right = node.right
        when Assign
          no_indent right.value
        when Call
          no_indent right.args.last
        else
          raise "Bug: expected Assign or Call after op assign, at #{node.location}"
        end
        return false
      end

      check token
      write " "
      write token
      next_token_skip_space
      if @token.type == :NEWLINE
        next_token_skip_space_or_newline
        write_line
        next_indent = @inside_cond == 0 ? column + 2 : column
        indent(next_indent, node.right)
        return false
      end

      skip_space_or_newline
      write " "
      no_indent node.right

      false
    end

    def visit(node : Not)
      prelude

      check :"!"
      write "!"
      next_token_skip_space_or_newline

      no_indent node.exp

      false
    end

    def visit(node : Assign)
      node.target.accept self
      skip_space_or_newline

      if @token.type == :"="
        check :"="
        write " ="
        slash_is_regex!
        next_token_skip_space
        if @token.type == :NEWLINE
          next_token_skip_space_or_newline
          write_line
          indent node.value
        else
          write " "
          no_indent node.value
        end
      else
        # This is the case of `target op= value`
        write " "
        write @token.type
        write " "
        next_token_skip_space_or_newline
        call = node.value as Call
        no_indent call.args.last
      end

      false
    end

    def visit(node : Require)
      prelude

      check_keyword :require
      write "require "
      next_token_skip_space_or_newline

      no_indent StringLiteral.new(node.string)

      false
    end

    def visit(node : VisibilityModifier)
      prelude

      column = @column

      check_keyword node.modifier
      write node.modifier
      write " "
      next_token_skip_space_or_newline

      @visibility_indent = column
      node.exp.accept self
      @visibility_indent = nil

      false
    end

    def visit(node : MagicConstant)
      check node.name
      write node.name
      next_token

      false
    end

    def visit(node : ModuleDef)
      prelude

      column = @column

      check_keyword :module
      write "module "
      next_token_skip_space_or_newline

      no_indent node.name
      format_type_vars node.type_vars

      format_nested_with_end node.body, column

      false
    end

    def visit(node : ClassDef)
      prelude

      column = @column

      if node.abstract
        check_keyword :abstract
        write "abstract "
        next_token_skip_space_or_newline
      end

      if node.struct
        check_keyword :struct
        write "struct "
      else
        check_keyword :class
        write "class "
      end
      next_token_skip_space_or_newline

      no_indent node.name
      format_type_vars node.type_vars

      if superclass = node.superclass
        skip_space_or_newline
        check :"<"
        write " < "
        next_token_skip_space_or_newline
        no_indent superclass
      end

      format_nested_with_end node.body, column

      false
    end

    def format_type_vars(type_vars)
      if type_vars
        skip_space
        check :"("
        write "("
        next_token_skip_space_or_newline
        type_vars.each_with_index do |type_var, i|
          write type_var
          next_token_skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, type_vars)
            next_token_skip_space_or_newline
          end
        end
        check :")"
        write ")"
        next_token_skip_space
      end
    end

    def visit(node : StructOrUnionDef)
      prelude

      column = @column

      if node.is_a?(StructDef)
        check_keyword :struct
        write "struct "
      else
        check_keyword :union
        write "union "
      end
      next_token_skip_space_or_newline

      write node.name
      next_token

      @inside_struct_or_union += 1
      format_nested_with_end node.body, column
      @inside_struct_or_union -= 1

      false
    end

    def visit(node : Include)
      prelude

      check_keyword :include
      write "include "
      next_token_skip_space_or_newline

      no_indent node.name

      false
    end

    def visit(node : Extend)
      prelude

      check_keyword :extend
      write "extend "
      next_token_skip_space_or_newline

      no_indent node.name

      false
    end

    def visit(node : LibDef)
      prelude

      column = @column
      @inside_lib += 1

      check_keyword :lib
      write "lib "
      next_token_skip_space_or_newline

      check :CONST
      write node.name
      next_token

      format_nested_with_end node.body, column

      @inside_lib -= 1

      false
    end

    def visit(node : EnumDef)
      prelude

      column = @column

      check_keyword :enum
      write "enum "
      next_token_skip_space_or_newline

      no_indent node.name

      if base_type = node.base_type
        skip_space
        check :":"
        write " : "
        next_token_skip_space_or_newline
        no_indent base_type
      end

      format_nested_with_end Expressions.from(node.members), column

      false
    end

    def visit(node : DeclareVar)
      node.var.accept self
      skip_space_or_newline
      check :"::"
      write " :: "
      next_token_skip_space_or_newline
      no_indent node.declared_type

      false
    end

    def visit(node : Return)
      format_control_expression node, :return
    end

    def visit(node : Break)
      format_control_expression node, :break
    end

    def visit(node : Next)
      format_control_expression node, :next
    end

    def format_control_expression(node, keyword)
      prelude

      check_keyword keyword
      write keyword
      next_token

      has_parentheses = false
      if @token.type == :"("
        has_parentheses = true
        write "("
        next_token_skip_space_or_newline
      end

      if exp = node.exp
        write " " unless has_parentheses
        skip_space

        if exp.is_a?(TupleLiteral) && @token.type != :"{"
          exp.elements.each_with_index do |elem, i|
            no_indent elem
            skip_space_or_newline
            if @token.type == :","
              write ", " unless last?(i, exp.elements)
              next_token_skip_space_or_newline
            end
          end
        else
          no_indent exp
          skip_space_or_newline
        end
      end

      if has_parentheses
        check :")"
        write ")"
        next_token
      end

      false
    end

    def visit(node : Yield)
      prelude

      if scope = node.scope
        check_keyword :with
        write "with "
        next_token_skip_space_or_newline
        no_indent scope
        skip_space_or_newline
        write " "
      end

      check_keyword :yield
      write "yield"
      next_token

      prefix_indent = @column + 1
      base_indent = prefix_indent
      next_needs_indent = false
      has_newlines = false

      has_parentheses = false
      if @token.type == :"("
        has_parentheses = true
        write "("
        next_token_skip_space
        if @token.type == :NEWLINE
          write_line
          next_needs_indent = true
          base_indent += 2
        end
      else
        write " " unless node.exps.empty?
      end

      node.exps.each_with_index do |exp, i|
        write_indent(base_indent) if next_needs_indent
        no_indent exp
        skip_space
        if @token.type == :","
          write "," unless last?(i, node.exps)
          next_token_skip_space
          if @token.type == :NEWLINE
            write_line
            next_needs_indent = true
            has_newlines = true
            next_token_skip_space_or_newline
          else
            write " " unless last?(i, node.exps)
          end
        end
      end

      if has_parentheses
        if has_newlines
          write ","
          write_line
          write_indent(prefix_indent - 1)
        end
        check :")"
        write ")"
        next_token
      end

      false
    end

    def visit(node : Case)
      prelude

      prefix_indent = @column

      check_keyword :case
      write "case"
      slash_is_regex!
      next_token_skip_space_or_newline

      if cond = node.cond
        write " "
        no_indent cond
      end

      skip_space_write_line

      node.whens.each_with_index do |a_when, i|
        indent(prefix_indent) { format_when(a_when, last?(i, node.whens)) }
        skip_space_or_newline
      end

      skip_space_or_newline

      if a_else = node.else
        check_keyword :else
        write_indent(prefix_indent)
        write "else"
        next_token_skip_space
        if @token.type == :NEWLINE
          write_line
          next_token_skip_space_or_newline
          indent(prefix_indent + 2, a_else)
          skip_space_or_newline
        else
          write " "
          no_indent a_else
          skip_space_or_newline
        end
        write_line
      end

      check_end
      write_indent(prefix_indent)
      write "end"
      next_token

      false
    end

    def format_when(node, is_last)
      prelude

      prefix_indent = @column

      check_keyword :when
      write "when"
      slash_is_regex!
      next_token_skip_space
      write " "
      base_indent = @column
      next_needs_indent = false
      node.conds.each_with_index do |cond, i|
        write_indent(base_indent) if next_needs_indent
        no_indent cond
        next_needs_indent = false
        unless last?(i, node.conds)
          skip_space_or_newline
          if @token.type == :","
            write ","
            slash_is_regex!
            next_token
            skip_space
            if @token.type == :NEWLINE
              write_line
              next_needs_indent = true
            else
              write " "
            end
          end
        end
      end
      skip_space
      if @token.type == :";" || @token.keyword?(:then)
        separator = @token.to_s
        slash_is_regex!
        next_token_skip_space
        if @token.type == :NEWLINE
          format_nested(node.body, prefix_indent)
        else
          write " " if separator == "then"
          write separator
          write " "
          no_indent node.body
          write_line
        end
      else
        format_nested(node.body, prefix_indent)
      end

      false
    end

    def visit(node : ImplicitObj)
      false
    end

    def visit(node : Attribute)
      prelude

      check :"@["
      write "@["
      next_token_skip_space_or_newline

      write @token
      next_token_skip_space

      column = @column

      if @token.type == :"("
        has_args = !node.args.empty? || node.named_args
        if has_args
          write "("
        end
        next_token_skip_space
        has_newlines = format_args node.args, true, named_args: node.named_args
        skip_space_or_newline

        if @token.type == :","
          next_token_skip_space_or_newline
          if has_newlines
            write ","
            write_line
            write_indent(column)
          end
        end

        skip_space_or_newline
        check :")"
        write ")" if has_args
        next_token_skip_space_or_newline
      end

      check :"]"
      write "]"
      next_token

      false
    end

    def visit(node : Cast)
      node.obj.accept self
      skip_space_or_newline
      check_keyword :as
      write " as "
      next_token_skip_space_or_newline
      no_indent node.to
      false
    end

    def visit(node : TypeOf)
      format_unary(:typeof) { format_args node.expressions, true }
    end

    def visit(node : SizeOf)
      format_unary node, :sizeof
    end

    def visit(node : InstanceSizeOf)
      format_unary node, :instance_sizeof
    end

    def visit(node : PointerOf)
      format_unary node, :pointerof
    end

    def format_unary(node, keyword)
      format_unary(keyword) { no_indent node.exp }
    end

    def format_unary(keyword)
      prelude

      check_keyword keyword
      write keyword
      next_token_skip_space_or_newline
      check :"("
      write "("
      next_token_skip_space_or_newline
      yield
      skip_space_or_newline
      check :")"
      write ")"
      next_token

      false
    end

    def visit(node : Underscore)
      prelude

      check :UNDERSCORE
      write "_"
      next_token

      false
    end

    def visit(node : MultiAssign)
      prelude

      node.targets.each_with_index do |target, i|
        no_indent { target.accept self }
        skip_space_or_newline
        if @token.type == :","
          write ", " unless last?(i, node.targets)
          next_token_skip_space_or_newline
        end
      end

      check :"="
      write " ="
      next_token_skip_space
      if @token.type == :NEWLINE && node.values.size == 1
        next_token_skip_space_or_newline
        write_line
        indent node.values.first
      else
        write " "
        no_indent { format_mutli_assign_values node.values }
      end

      false
    end

    def format_mutli_assign_values(values)
      values.each_with_index do |value, i|
        no_indent { value.accept self }
        unless last?(i, values)
          skip_space_or_newline
          if @token.type == :","
            write ", "
            next_token_skip_space_or_newline
          end
        end
      end
    end

    def visit(node : ExceptionHandler)
      column = @column

      implicit_handler = false
      if node.implicit
        node.body.accept self
        skip_space_or_newline

        write_line
        implicit_handler = true
        column = @def_column
      else
        prelude
        column = @column

        if node.suffix
          no_indent node.body
          skip_space
          write " rescue "
          next_token_skip_space_or_newline
          no_indent node.rescues.not_nil!.first.not_nil!.body
          return false
        end
      end

      unless implicit_handler
        check_keyword :begin
        write "begin"
        next_token
        format_nested(node.body, column)
      end

      if node_rescues = node.rescues
        node_rescues.each_with_index do |node_rescue, i|
          skip_space_or_newline
          check_keyword :rescue
          write_indent(column)
          write "rescue"
          next_token

          name = node_rescue.name
          if name
            skip_space_or_newline
            write " "
            write name
            next_token
          end

          if types = node_rescue.types
            skip_space_or_newline
            if name
              check :":"
              write " : "
              next_token_skip_space_or_newline
            else
              write " "
            end
            types.each_with_index do |type, j|
              no_indent type
              unless last?(j, types)
                skip_space_or_newline
                if @token.type == :"|"
                  write " | "
                  next_token_skip_space_or_newline
                end
              end
            end
          end
          format_nested(node_rescue.body, column)
        end
      end

      if node_else = node.else
        skip_space_or_newline
        check_keyword :else
        write_indent(column)
        write "else"
        next_token
        format_nested(node_else, column)
      end

      if node_ensure = node.ensure
        skip_space_or_newline
        check_keyword :ensure
        write_indent(column)
        write "ensure"
        next_token
        format_nested(node_ensure, column)
      end

      unless implicit_handler
        skip_space_or_newline
        check_end
        write_indent(column)
        write "end"
        next_token
      end

      false
    end

    def visit(node : Alias)
      format_alias_or_typedef node, :alias, node.value
    end

    def visit(node : TypeDef)
      format_alias_or_typedef node, :type, node.type_spec
    end

    def format_alias_or_typedef(node, keyword, value)
      prelude

      check_keyword keyword
      write keyword
      write " "
      next_token_skip_space_or_newline

      write node.name
      next_token_skip_space_or_newline

      check :"="
      write " = "
      next_token_skip_space_or_newline

      no_indent value

      false
    end

    def visit(node : FunPointer)
      prelude

      check :"->"
      write "->"
      next_token_skip_space_or_newline

      call = Call.new(node.obj, node.name, node.args)
      no_indent call

      false
    end

    def visit(node : FunLiteral)
      prelude

      column = @column

      check :"->"
      write "->"
      next_token_skip_space_or_newline

      a_def = node.def

      if @token.type == :"("
        write "(" unless a_def.args.empty?
        next_token_skip_space_or_newline

        a_def.args.each_with_index do |arg, i|
          no_indent arg
          skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, a_def.args)
            next_token_skip_space_or_newline
          end
        end

        check :")"
        write ")" unless a_def.args.empty?
        next_token_skip_space_or_newline
      end

      write " " unless a_def.args.empty?

      is_do = false
      if @token.keyword?(:do)
        write "do"
        is_do = true
      else
        check :"{"
        write "{"
      end
      next_token_skip_space

      if @token.type == :NEWLINE
        format_nested(a_def.body, column)
      else
        skip_space_or_newline
        write " "
        no_indent a_def.body
        write " "
      end

      skip_space_or_newline

      if is_do
        check_end
        write_indent(column)
        write "end"
        next_token
      else
        check :"}"
        write_indent(column)
        write "}"
        next_token
      end

      false
    end

    def visit(node : ExternalVar)
      prelude

      check :GLOBAL
      write @token.value
      next_token_skip_space_or_newline

      if @token.type == :"="
        write " = "
        next_token_skip_space_or_newline
        write @token.value
        next_token_skip_space_or_newline
      end

      check :":"
      write " : "
      next_token_skip_space_or_newline

      no_indent node.type_spec

      false
    end

    def visit(node : Out)
      prelude

      check_keyword :out
      write "out "
      next_token_skip_space_or_newline

      node.exp.accept self

      false
    end

    def visit(node : Metaclass)
      node.name.accept self
      skip_space

      check :"."
      write "."
      next_token_skip_space_or_newline
      check_keyword :class
      write "class"
      next_token

      false
    end

    def visit(node : Virtual)
      node.name.accept self
      skip_space

      check :"+"
      write "+"
      next_token

      false
    end

    def visit(node : Block)
      # Handled in format_block
      return false
    end

    def visit(node : When)
      # Handled in format_when
      return false
    end

    def visit(node : Rescue)
      # Handled in visit(node : ExceptionHandler)
      return false
    end

    def visit(node : Primitive)
      return false
    end

    def visit(node : MacroId)
      return false
    end

    def visit(node : TypeNode)
      return false
    end

    def visit(node : MetaVar)
      return false
    end

    def visit(node : TypeFilteredNode)
      return false
    end

    def visit(node : ASTNode)
      node.raise "missing handler for #{node.class}"
    end

    def to_s(io)
      io << @output
    end

    def next_token
      @token = @lexer.next_token
    end

    def next_string_token
      @token = @lexer.next_string_token(@token.delimiter_state)
    end

    def next_string_array_token
      @token = @lexer.next_string_array_token
    end

    def next_macro_token
      char = @lexer.current_char
      @token = @lexer.next_macro_token(@macro_state, false)
      @macro_state = @token.macro_state

      # Unescape
      if char == '\\' && !@token.raw.starts_with?(char)
        @token.raw = "\\#{@token.raw}"
      end
    end

    def next_token_skip_space
      next_token
      skip_space
    end

    def next_token_skip_space_or_newline
      next_token
      skip_space_or_newline
    end

    def skip_space(write_comma = false)
      base_column = @column
      has_space = false
      while @token.type == :SPACE
        next_token
        has_space = true
      end
      if @token.type == :COMMENT
        needs_space = has_space && base_column != 0
        if write_comma
          write ", "
        else
          write " " if needs_space
        end
        write_comment(needs_indent: !needs_space)
        true
      else
        false
      end
    end

    def skip_space_or_newline(last = false)
      base_column = @column
      has_space = false
      newlines = 0
      while true
        case @token.type
        when :SPACE
          has_space = true
          next_token
        when :NEWLINE
          newlines += 1
          next_token
        else
          break
        end
      end
      if @token.type == :COMMENT
        needs_space = has_space && newlines == 0 && base_column != 0
        if needs_space
          write " "
        elsif last && newlines > 0
          write_line if !@wrote_newline && newlines > 1
          write_line
        end
        write_comment(needs_indent: !needs_space)
        true
      else
        false
      end
    end

    def slash_is_regex!
      @lexer.slash_is_regex = true
    end

    def skip_space_write_line
      found_comment = skip_space
      write_line unless found_comment || @wrote_newline
      found_comment
    end

    def skip_nop(indent)
      skip_space_write_line
      indent(indent) { skip_space_or_newline }
    end

    def skip_semicolon
      while @token.type == :";"
        next_token
      end
    end

    def jump_semicolon
      skip_space
      skip_semicolon
      skip_space_or_newline
    end

    def write_comment(needs_indent = true)
      while @token.type == :COMMENT
        write_indent if needs_indent
        value = @token.value.to_s.strip
        char_1 = value[1]?
        if char_1 && !char_1.whitespace?
          value = "\# #{value[1 .. -1].strip}"
        end
        write value
        next_token_skip_space
        consume_newlines
        skip_space_or_newline
      end
    end

    def consume_newlines
      if @token.type == :NEWLINE
        write_line
        next_token

        if @token.type == :NEWLINE
          write_line
        end

        skip_space_or_newline
      end
    end

    def prelude(indent = true)
      skip_space_or_newline
      write_comment
      write_indent if indent
    end

    def prelude_with_visibility_check
      if visibility_indent = @visibility_indent
        column = visibility_indent
        @visibility_indent = nil
      else
        prelude
        column = @column
      end
      column
    end

    def indent
      @indent += 2
      yield
      @indent -= 2
    end

    def indent(node : ASTNode)
      indent { node.accept self }
    end

    def indent(indent : Int)
      old_indent = @indent
      @indent = indent
      yield
      @indent = old_indent
    end

    def indent(indent : Int, node : ASTNode)
      indent(indent) { node.accept self }
    end

    def no_indent(node : ASTNode)
      no_indent { node.accept self }
    end

    def no_indent
      old_indent = @indent
      @indent = 0
      yield
      @indent = old_indent
    end

    def write_indent
      write_indent @indent
    end

    def write_indent(indent)
      indent.times { write " " }
    end

    def write(string : String)
      @output << string
      @column += string.size
      @wrote_newline = false
    end

    def write(obj)
      write obj.to_s
    end

    def write_line
      @output.puts
      @column = 0
      @wrote_newline = true
    end

    def clear_obj(call)
      obj = call.obj
      if obj.is_a?(Call)
        clear_obj obj
      else
        call.obj = nil
      end
    end

    def finish
      skip_space
      write_line
      skip_space_or_newline
    end

    def check_keyword(*keywords)
      raise "expecting keyword #{keywords.join " or "}, not `#{@token.type}, #{@token.value}`, at #{@token.location}" unless keywords.any? { |k| @token.keyword?(k) }
    end

    def check(token_type)
      raise "expecting #{token_type}, not `#{@token.type}, #{@token.value}`, at #{@token.location}" unless @token.type == token_type
    end

    def check_end
      if @token.type == :";"
        next_token_skip_space_or_newline
      end
      check_keyword :end
    end

    def last?(index, collection)
      index == collection.size - 1
    end

    def inside_macro
      @inside_macro += 1
      yield
      @inside_macro -= 1
    end

    def outside_macro
      old_inside_macro = @inside_macro
      @inside_macro = 0
      yield
      @inside_macro = old_inside_macro
    end

    def inside_macro?
      @inside_macro != 0
    end

    def check_macro_whitespace
      if @lexer.current_char == '\\' && @lexer.peek_next_char.whitespace?
        @lexer.next_char
        write "\\"
        write @lexer.skip_macro_whitespace
        @macro_state.whitespace = true
        true
      else
        false
      end
    end

    def inside_cond
      @inside_cond += 1
      yield
      @inside_cond -= 1
    end
  end
end
