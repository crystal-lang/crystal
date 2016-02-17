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
    end

    record AlignInfo, id, line, start_column, middle_column, end_column, number do
      def size
        end_column - start_column
      end
    end

    class CommentInfo
      property start_line
      property end_line
      property needs_newline

      def initialize(@start_line, @kind)
        @end_line = @start_line
        @needs_newline = true
      end
    end

    def initialize(source)
      @lexer = Lexer.new(source)
      @lexer.comments_enabled = true
      @lexer.count_whitespace = true
      @lexer.wants_raw = true
      @comment_columns = [nil] of Int32?
      @indent = 0
      @line = 0
      @column = 0
      @token = @lexer.token
      @token = next_token

      @output = MemoryIO.new(source.bytesize)
      @line_output = MemoryIO.new
      @next_exp_column = nil
      @wrote_newline = false
      @wrote_comment = false
      @macro_state = Token::MacroState.default
      @inside_macro = 0
      @inside_cond = 0
      @inside_lib = 0
      @inside_struct_or_union = 0
      @dot_column = nil
      @def_indent = 0
      @last_write = ""
      @exp_needs_indent = true
      @inside_def = 0

      # This stores the column number (if any) of each comment in every line
      @when_infos = [] of AlignInfo
      @hash_infos = [] of AlignInfo
      @assign_infos = [] of AlignInfo
      @doc_comments = [] of CommentInfo
      @current_doc_comment = nil
      @hash_in_same_line = Set(typeof(object_id)).new
      @shebang = @token.type == :COMMENT && @token.value.to_s.starts_with?("#!")
    end

    def visit(node : FileNode)
      true
    end

    def visit(node : Expressions)
      if node.expressions.size == 1 && @token.type == :"("
        # If it's (...) with a single expression, we treat it
        # like a single expression, indenting it if needed
        write "("
        next_token_skip_space
        if @token.type == :NEWLINE
          next_token_skip_space_or_newline
          write_line
          write_indent(@indent + 2, node.expressions.first)
          skip_space_write_line
          skip_space_or_newline
          write_indent
          write_token :")"
          return false
        end
        skip_space_or_newline
        accept node.expressions.first
        skip_space
        if @token.type == :NEWLINE
          skip_space_or_newline
          write_line
          write_indent(@indent + 2)
        end
        skip_space_or_newline
        write ")"
        next_token
        return false
      end

      old_indent = @indent
      base_indent = old_indent
      next_needs_indent = false

      has_paren = false
      has_begin = false

      if node.keyword == :"(" && @token.type == :"("
        write "("
        next_needs_indent = false
        next_token
        has_paren = true
      elsif node.keyword == :begin && @token.keyword?(:begin)
        write "begin"
        @indent += 2
        write_line
        next_token_skip_space_or_newline
        if @token.type == :";"
          next_token_skip_space_or_newline
        end
        has_begin = true
        base_indent = @indent
        next_needs_indent = true
      end

      last_aligned_assign = nil
      max_length = nil
      skip_space

      node.expressions.each_with_index do |exp, i|
        is_assign = assign?(exp)
        if is_assign && !last_aligned_assign
          last_aligned_assign, max_length = find_assign_chunk(node.expressions, exp, i + 1)
        else
          max_length = nil unless is_assign
        end

        if last?(i, node.expressions)
          needs_two_lines = false
        else
          next_exp = node.expressions[i + 1]
          needs_two_lines = !last?(i, node.expressions) && !exp.is_a?(Attribute) &&
            (!(exp.is_a?(IfDef) && next_exp.is_a?(LibDef))) &&
            (!(exp.is_a?(Def) && exp.abstract && next_exp.is_a?(Def) && next_exp.abstract)) &&
            (needs_two_lines?(exp) || needs_two_lines?(next_exp))
        end

        @assign_length = max_length
        if next_needs_indent
          write_indent(@indent, exp)
        else
          accept exp
        end
        @dot_column = nil

        skip_space

        if @token.type == :";"
          if needs_two_lines
            skip_semicolon_or_space_or_newline
          else
            found_comment = skip_semicolon_or_space
            if @token.type == :NEWLINE
              write_line
              next_token_skip_space
              next_needs_indent = true
            else
              write "; " unless last?(i, node.expressions) || found_comment
              skip_space_or_newline
              next_needs_indent = found_comment
            end
          end
        else
          next_needs_indent = true
        end

        unless @exp_needs_indent
          next_needs_indent = false
          @exp_needs_indent = true
        end

        if last?(i, node.expressions)
          skip_space_or_newline last: true
        else
          if needs_two_lines
            skip_space_write_line
            found_comment = skip_space_or_newline last: true, at_least_one: true
            write_line unless found_comment
          else
            consume_newlines
          end
        end

        last_aligned_assign = nil if last_aligned_assign.same?(exp)
      end

      @indent = old_indent

      if has_paren
        write_token :")"
      end

      if has_begin
        check_end
        next_token
        write_line
        write_indent
        write "end"
      end

      false
    end

    def assign?(exp)
      case exp
      when Assign
        exp.target.is_a?(Path)
      when Arg
        true
      else
        false
      end
    end

    def assign_length(exp)
      case exp
      when Assign
        assign_length exp.target
      when Arg
        exp.name.size
      when Path
        exp.names.first.size
      else
        0
      end
    end

    def find_assign_chunk(expressions, last, i)
      max_length = assign_length(last)

      while i < expressions.size
        exp = expressions[i]
        exp_location = exp.location
        break unless exp_location

        last_location = last.location
        break unless last_location
        break unless last_location.line_number + 1 == exp_location.line_number

        last = exp
        exp_length = assign_length(exp)
        max_length = exp_length if exp_length > max_length

        i += 1
      end

      {last, max_length}
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
      false
    end

    def visit(node : NilLiteral)
      write_keyword :nil

      false
    end

    def visit(node : BoolLiteral)
      check_keyword :false, :true
      write node.value
      next_token

      false
    end

    def visit(node : CharLiteral)
      check :CHAR
      write @token.raw
      next_token

      false
    end

    def visit(node : SymbolLiteral)
      check :SYMBOL
      write @token.raw
      next_token

      false
    end

    def visit(node : NumberLiteral)
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
        next_token_skip_space_or_newline
        visit(node)
      else
        next_token
      end

      false
    end

    def visit(node : StringInterpolation)
      check :DELIMITER_START
      is_regex = @token.delimiter_state.kind == :regex

      write @token.raw
      next_string_token

      delimiter_state = @token.delimiter_state

      node.expressions.each do |exp|
        if @token.type == :DELIMITER_END
          # This is for " ... " \
          #     " ... "
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
          skip_strings

          check :INTERPOLATION_START
          write "\#{"
          delimiter_state = @token.delimiter_state
          next_token_skip_space_or_newline
          indent(@column, exp)
          skip_space_or_newline
          check :"}"
          write "}"
          @token.delimiter_state = delimiter_state
          next_string_token
        end
      end

      skip_strings

      check :DELIMITER_END
      write @token.raw
      format_regex_modifiers if is_regex
      next_token

      false
    end

    private def skip_strings
      # Heredocs might indice some spaces that are removed
      # because of indentation
      while @token.type == :STRING
        write @token.raw
        next_string_token
      end
    end

    def visit(node : RegexLiteral)
      accept node.value

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
      pos = @lexer.current_pos
      while true
        char = @lexer.current_char
        case char
        when ' ', '\t'
          @lexer.next_char
        when '\\'
          @lexer.current_pos = pos
          return true
        else
          break
        end
      end
      @lexer.current_pos = pos
      false
    end

    def space_newline?
      pos = @lexer.current_pos
      while true
        char = @lexer.current_char
        case char
        when ' ', '\t'
          @lexer.next_char
        when '\n'
          @lexer.current_pos = pos
          return true
        else
          break
        end
      end
      @lexer.current_pos = pos
      false
    end

    def visit(node : ArrayLiteral)
      case @token.type
      when :"["
        format_literal_elements node.elements, :"[", :"]"
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
        count = 0
        while true
          has_space_newline = space_newline?
          if has_space_newline
            write_line
            if count == node.elements.size
              write_indent
            else
              write_indent(@indent + 2)
            end
          end
          next_string_array_token
          case @token.type
          when :STRING
            write " " unless first || has_space_newline
            write @token.raw
            first = false
          when :STRING_ARRAY_END
            write ")"
            next_token
            break
          end
          count += 1
        end
        return false
      else
        name = node.name.not_nil!
        accept name
        skip_space
        format_literal_elements node.elements, :"{", :"}"
      end

      if node_of = node.of
        write_keyword " ", :of, " "
        accept node_of
      end

      false
    end

    def visit(node : TupleLiteral)
      format_literal_elements node.elements, :"{", :"}"
      false
    end

    def format_literal_elements(elements, prefix, suffix)
      slash_is_regex!
      write_token prefix
      has_newlines = false
      wrote_newline = false
      write_space_at_end = false
      next_needs_indent = false
      found_comment = false
      found_first_newline = false

      skip_space
      if @token.type == :NEWLINE
        if elements.empty?
          skip_space_or_newline
          write_token suffix
          return false
        end

        indent(@indent + 2) { consume_newlines }
        skip_space_or_newline
        wrote_newline = true
        next_needs_indent = true
        has_newlines = true
        found_first_newline = true
      end

      elements.each_with_index do |element, i|
        # This is to prevent writing `{{`
        current_element = element
        if current_element.is_a?(HashLiteral::Entry)
          current_element = current_element.key
        end

        if prefix == :"{" && i == 0 && !wrote_newline && (current_element.is_a?(TupleLiteral) || current_element.is_a?(HashLiteral))
          write " "
          write_space_at_end = true
        end

        if next_needs_indent
          write_indent(@indent + 2, element)
        else
          accept element
        end

        last = last?(i, elements)

        found_comment = skip_space(write_comma: last && has_newlines)

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
            indent(@indent + 2) { consume_newlines }
            skip_space_or_newline
            next_needs_indent = true
            has_newlines = true
          else
            unless last || found_comment
              write " "
              next_needs_indent = false
            end
          end
        end
      end

      finish_list suffix, has_newlines, found_comment, found_first_newline, write_space_at_end
    end

    def visit(node : HashLiteral)
      if name = node.name
        accept name
        skip_space
      end

      old_hash = @current_hash
      @current_hash = node
      format_literal_elements node.entries, :"{", :"}"
      @current_hash = old_hash

      if node_of = node.of
        write_keyword " ", :of, " "
        format_hash_entry nil, node_of
      end

      if @hash_in_same_line.includes? node.object_id
        @hash_infos.reject! { |info| info.id == node.object_id }
      end

      false
    end

    def accept(node : HashLiteral::Entry)
      format_hash_entry(@current_hash.not_nil!, node)
    end

    def format_hash_entry(hash, entry)
      start_line = @line
      start_column = @column
      found_in_same_line = false

      if entry.key.is_a?(SymbolLiteral) && (@token.type == :IDENT || @token.type == :CONST)
        write @token
        next_token
        slash_is_regex!
        write_token :":", " "
        middle_column = @column
        found_in_same_line ||= check_hash_info hash, entry.key, start_line, start_column, middle_column
      else
        accept entry.key
        skip_space_or_newline
        middle_column = @column
        if @token.type == :":" && entry.key.is_a?(StringLiteral)
          write ": "
          slash_is_regex!
          next_token
          middle_column = @column
          found_in_same_line ||= check_hash_info hash, entry.key, start_line, start_column, middle_column
        else
          slash_is_regex!
          write_token " ", :"=>", " "
          found_in_same_line ||= check_hash_info hash, entry.key, start_line, start_column, middle_column
        end
      end
      skip_space_or_newline
      accept entry.value

      if found_in_same_line
        @hash_in_same_line << hash.object_id
      end
    end

    def finish_list(suffix, has_newlines, found_comment, found_first_newline, write_space_at_end)
      if @token.type == suffix && !found_first_newline
        if @wrote_newline
          write_indent
        else
          write " " if write_space_at_end
        end
      else
        found_comment ||= skip_space_or_newline
        check suffix

        if has_newlines
          unless found_comment
            write ","
            write_line
          end
          write_indent
        elsif write_space_at_end
          write " "
        end
        skip_space_or_newline
      end

      write_token suffix
    end

    def check_hash_info(hash, key, start_line, start_column, middle_column)
      end_column = @column
      found_in_same_line = false
      if @line == start_line
        last_info = @hash_infos.last?
        if last_info && last_info.line == @line
          found_in_same_line = true
        elsif hash
          number = key.is_a?(NumberLiteral)
          @hash_infos << AlignInfo.new(hash.object_id, @line, start_column, middle_column, end_column, number)
        end
      end
      found_in_same_line
    end

    def visit(node : RangeLiteral)
      accept node.from
      skip_space_or_newline
      write_token(node.exclusive ? :"..." : :"..")
      skip_space_or_newline
      accept node.to
      false
    end

    def visit(node : Path)
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
        write_token :")"
      end

      false
    end

    def visit(node : Generic)
      name = node.name
      first_name = name.global && name.names.size == 1 && name.names.first

      # Check if it's T* instead of Pointer(T)
      if first_name == "Pointer" && @token.value != "Pointer"
        type_var = node.type_vars.first
        accept type_var
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
          write_token :"*"
        end

        return false
      end

      # Check if it's T[N] instead of StaticArray(T, N)
      if first_name == "StaticArray" && @token.value != "StaticArray"
        accept node.type_vars[0]
        skip_space_or_newline
        write_token :"["
        skip_space_or_newline
        accept node.type_vars[1]
        skip_space_or_newline
        write_token :"]"
        return false
      end

      # Check if it's {A, B} instead of Tuple(A, B)
      if first_name == "Tuple" && @token.value != "Tuple"
        write_token :"{"
        skip_space_or_newline
        node.type_vars.each_with_index do |type_var, i|
          accept type_var
          skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, node.type_vars)
            next_token_skip_space_or_newline
          end
        end
        write_token :"}"
        return false
      end

      accept name
      skip_space_or_newline

      write_token :"("
      skip_space_or_newline

      node.type_vars.each_with_index do |type_var, i|
        accept type_var
        skip_space_or_newline
        if @token.type == :","
          write ", " unless last?(i, node.type_vars)
          next_token_skip_space_or_newline
        end
      end

      write_token :")"

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
        accept type

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
        write_token :")"
        skip_space
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
      if !@token.keyword?(keyword) && node.else.is_a?(Nop)
        # Suffix if/unless
        accept node.then
        write_keyword " ", keyword, " "
        inside_cond do
          indent(@column, node.cond)
        end
        return false
      end

      # This is the case of `cond ? exp1 : exp2`
      if keyword == :if && !@token.keyword?(:if)
        accept node.cond
        skip_space_or_newline
        write_token " ", :"?", " "
        skip_space_or_newline
        accept node.then
        skip_space_or_newline
        write_token " ", :":", " "
        skip_space_or_newline
        accept node.else
        return false
      end

      write_keyword keyword, " "
      format_if_at_cond node

      false
    end

    def format_if_at_cond(node, check_end = true)
      inside_cond do
        indent(@column, node.cond)
      end

      indent(@indent + 2) { skip_space }
      skip_semicolon
      format_nested node.then
      indent(@indent + 2) { skip_space_or_newline last: true }
      jump_semicolon

      node_else = node.else

      if @token.keyword?(:else)
        write_indent
        write "else"
        next_token
        indent(@indent + 2) { skip_space }
        skip_semicolon
        format_nested node.else
      elsif node_else.is_a?(If) && @token.keyword?(:elsif)
        format_elsif node_else
      elsif node_else.is_a?(IfDef) && @token.keyword?(:elsif)
        format_elsif node_else
      end

      if check_end
        format_end @indent
      end
    end

    def format_elsif(node_else)
      write_indent
      write "elsif "
      next_token_skip_space_or_newline
      format_if_at_cond node_else, check_end: false
    end

    def visit(node : While)
      format_while_or_until node, :while
    end

    def visit(node : Until)
      format_while_or_until node, :until
    end

    def format_while_or_until(node, keyword)
      write_keyword keyword, " "
      inside_cond do
        indent(@column, node.cond)
      end

      format_nested_with_end node.body

      false
    end

    def format_nested(node, indent = @indent, write_end_line = true, write_indent = true)
      slash_is_regex!
      if node.is_a?(Nop)
        skip_nop(indent + 2)
      else
        if write_indent
          indent(indent + 2) do
            skip_space_write_line
            skip_space_or_newline
            write_indent(indent + 2, node)
            skip_space_write_line if write_end_line
          end
        else
          skip_space_write_line
          skip_space_or_newline
          accept node
          skip_space_write_line if write_end_line
        end
      end
    end

    def format_nested_with_end(node, column = @indent, write_end_line = true)
      indent(column + 2) { skip_space }

      if @token.type == :";"
        if node.is_a?(Nop)
          skip_semicolon_or_space_or_newline
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
      @def_indent = @indent
      @inside_def += 1

      if node.abstract
        write_keyword :abstract, " "
      end

      if node.macro_def?
        write_keyword :macro, " "
      end

      write_keyword :def, " ", skip_space_or_newline: false

      if receiver = node.receiver
        skip_space_or_newline
        accept receiver
        skip_space_or_newline
        write_token :"."
      end

      if @lexer.current_char == '%'
        @token.type = :"%"
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
        write_token " ", :":", " "
        skip_space_or_newline
        accept node.return_type.not_nil!
      end

      if node.macro_def?
        format_macro_body node
      else
        body = node.body

        if to_skip > 0
          body = node.body
          if body.is_a?(Expressions)
            body.expressions = body.expressions[to_skip..-1]
            if body.expressions.empty?
              body = Nop.new
            end
          else
            body = Nop.new
          end
        end

        unless node.abstract
          format_nested_with_end body
        end
      end

      @inside_def -= 1

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
            write_token "(", :"&"
            skip_space
            to_skip += 1 if at_skip?
            accept block_arg
            skip_space_or_newline
            write ")"
          end

          if variadic
            skip_space_or_newline
            write_token "(", :"...", ")"
            skip_space_or_newline
          end

          check :")"
          next_token
        elsif block_arg
          skip_space_or_newline
          write_token " ", :"&"
          skip_space
          to_skip += 1 if at_skip?
          accept block_arg
          skip_space
        end
      else
        prefix_size = @column + 1

        old_indent = @indent
        next_needs_indent = false
        has_parentheses = false
        found_comment = false

        if @token.type == :"("
          has_parentheses = true
          write "("
          next_token_skip_space
          if @token.type == :NEWLINE
            write_line
            indent(prefix_size) { skip_space_or_newline }
            next_needs_indent = true
          end
          skip_space_or_newline
        else
          write "("
        end

        args.each_with_index do |arg, i|
          if next_needs_indent
            write_indent(prefix_size)
          end

          if i == splat_index
            write_token :"*"
            skip_space_or_newline
          end

          to_skip += 1 if at_skip?
          indent(prefix_size, arg)
          skip_space
          if @token.type == :","
            write "," unless last?(i, args)
            next_token
            found_comment = skip_space
            if @token.type == :NEWLINE
              unless last?(i, args)
                indent(prefix_size) { consume_newlines }
                next_needs_indent = true
              end
            elsif found_comment
              next_needs_indent = true
            else
              next_needs_indent = false
              write " " unless last?(i, args)
            end
            skip_space_or_newline
          end
        end

        if block_arg
          write_token ", ", :"&"
          skip_space
          to_skip += 1 if at_skip?
          accept block_arg
          skip_space
        end

        if variadic
          write_token ", ", :"..."
          skip_space_or_newline
        end

        if has_parentheses
          skip_space_or_newline
          write_indent(prefix_size) if found_comment
          write_token :")"
        else
          write_indent(prefix_size) if found_comment
          write ")"
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
      write_keyword :fun, " "

      check :IDENT
      write node.name
      next_token_skip_space

      if @token.type == :"="
        write " = "
        next_token_skip_space
        if @token.type == :DELIMITER_START
          indent(@column, StringLiteral.new(node.real_name))
        else
          write node.real_name
          next_token_skip_space
        end
      end

      format_def_args node.args, nil, nil, node.varargs

      if return_type = node.return_type
        skip_space
        write_token " ", :":", " "
        skip_space_or_newline
        accept return_type
      end

      if body = node.body
        format_nested_with_end body
      end

      false
    end

    def visit(node : Macro)
      write_keyword :macro, " "

      check :IDENT
      write node.name
      next_token_skip_space

      format_def_args node
      format_macro_body node

      false
    end

    def format_macro_body(node)
      if @token.keyword?(:end)
        return format_macro_end
      end

      next_macro_token

      if @token.type == :MACRO_END
        return format_macro_end
      end

      body = node.body
      if body.is_a?(Expressions) && body.expressions.empty?
        while @token.type != :MACRO_END
          next_macro_token
        end
        return format_macro_end
      end

      inside_macro do
        no_indent do
          format_nested body, write_end_line: false, write_indent: false
        end
      end

      skip_space_or_newline
      check :MACRO_END
      write "end"
      next_token
    end

    def format_macro_end
      write_line
      write_indent
      write "end"
      next_token
      return false
    end

    def visit(node : MacroLiteral)
      write @token.raw
      next_macro_token
      false
    end

    def visit(node : MacroExpression)
      old_column = @column

      if node.output
        if inside_macro?
          check :MACRO_EXPRESSION_START
        else
          check :"{{"
        end
        write "{{"
      else
        case @token.type
        when :MACRO_CONTROL_START, :"{%"
          # OK
        else
          check :MACRO_CONTROL_START
        end
        write "{%"
      end
      macro_state = @macro_state
      next_token

      has_space = @token.type == :SPACE
      skip_space
      has_newline = @token.type == :NEWLINE
      skip_space_or_newline

      if (has_space || !node.output) && !has_newline
        write " "
      end

      old_indent = @indent
      @indent = @column
      if has_newline
        write_line
        write_indent
      end

      indent(@column, node.exp)

      @indent = old_indent

      skip_space_or_newline
      @macro_state = macro_state

      if node.output
        if has_space && !has_newline
          write " "
        elsif has_newline
          write_line
          write_indent(old_column)
        end
        check :"}"
        next_token
        check :"}"
        write "}}"
      else
        check :"%}"
        if has_newline
          write_line
          write_indent(old_column)
        else
          write " "
        end
        write "%}"
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
        next_token
      elsif @token.keyword?(:unless)
        # This is rewritten to `if !...`
        node.then, node.else = node.else, node.then
        write "unless "
        next_token_skip_space_or_newline

        outside_macro { indent(@column, node.cond) }
      else
        write_keyword :if, " "
        outside_macro { indent(@column, node.cond) }
      end

      format_macro_if_epilogue node, macro_state
    end

    def format_macro_if_epilogue(node, macro_state, check_end = true)
      skip_space_or_newline
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

        if @token.keyword?(:elsif)
          sub_if = node.else as MacroIf
          next_token_skip_space_or_newline
          write "{% elsif "
          outside_macro { indent(@column, sub_if.cond) }
          format_macro_if_epilogue sub_if, macro_state, check_end: false
        else
          check_keyword :else
          next_token_skip_space_or_newline
          check :"%}"

          write "{% else %}"
          check_macro_whitespace
          next_macro_token

          inside_macro { no_indent node.else }
        end
      end

      if check_end
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
      end

      false
    end

    def visit(node : MacroFor)
      if inside_macro?
        check :MACRO_CONTROL_START
      else
        check :"{%"
      end
      write "{% "

      macro_state = @macro_state
      next_token_skip_space_or_newline

      write_keyword :for, " "

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

      write_keyword " ", :in, " "

      outside_macro { indent(@column, node.exp) }
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

      if exps = node.exps
        next_token
        write_token :"{"
        skip_space_or_newline
        exps.each_with_index do |exp, i|
          indent(@column, exp)
          skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, exps)
            next_token_skip_space_or_newline
          end
        end
        check :"}"
        write :"}"
      end

      next_macro_token

      false
    end

    def visit(node : Arg)
      restriction = node.restriction

      if @inside_lib > 0
        # This is the case of `fun foo(Char)`
        if @token.type != :IDENT && restriction
          accept restriction
          return false
        end
      end

      write @token.value
      next_token

      if default_value = node.default_value
        skip_space_or_newline
        check_align = check_assign_length node
        write_token " ", :"=", " "
        before_column = @column
        skip_space_or_newline
        accept default_value
        check_assign_align before_column, default_value if check_align
      end

      if restriction
        skip_space_or_newline

        # This is for a case like `x, y : Int32`
        if @inside_struct_or_union && @token.type == :","
          @exp_needs_indent = false
          write ", "
          next_token
          return false
        end

        write_token " ", :":", " "
        skip_space_or_newline
        accept restriction
      end

      # This is the case of an enum member
      if 'A' <= node.name[0] <= 'Z' && @token.type == :","
        write ", "
        next_token_skip_space
        @exp_needs_indent = @token.type == :NEWLINE
      end

      false
    end

    def visit(node : Splat)
      write_token :"*"
      skip_space_or_newline
      accept node.exp

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
          accept input
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
      write_token :"->"

      if output = node.output
        write " "
        skip_space_or_newline
        accept output
      end

      if has_parentheses
        write_token :")"
      end

      false
    end

    def visit(node : Self)
      write_keyword :self
      false
    end

    def visit(node : Var)
      write node.name
      next_token
      false
    end

    def visit(node : InstanceVar)
      write node.name
      next_token
      false
    end

    def visit(node : ClassVar)
      write node.name
      next_token
      false
    end

    def visit(node : Global)
      write node.name
      next_token
      false
    end

    def visit(node : ReadInstanceVar)
      accept node.obj

      skip_space_or_newline
      write_token :"."
      skip_space_or_newline
      write node.name
      next_token

      false
    end

    def visit(node : Call)
      # This is the case of `...`
      if node.name == "`"
        accept node.args.first
        return false
      end

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

      write_token :"::" if node.global

      if obj
        {:"!", :"+", :"-", :"~"}.each do |op|
          if node.name == op.to_s && @token.type == op && node.args.empty?
            write op
            next_token_skip_space_or_newline
            accept obj
            return false
          end
        end

        accept obj

        if @token.type == :SPACE
          needs_space = true
        else
          needs_space = node.name != "*" && node.name != "/" && node.name != "**"
        end

        skip_space

        @dot_column = nil unless obj.is_a?(Call)

        # It's something like `foo.bar\n
        #                         .baz`
        if @token.type == :NEWLINE
          newline_indent = @dot_column || @indent + 2
          indent(newline_indent) { consume_newlines }
          write_indent(newline_indent)
        end

        if @token.type != :"."
          # It's an operator
          if @token.type == :"["
            write "["
            next_token_skip_space

            args = node.args

            if node.name == "[]="
              last_arg = args.pop
            end

            has_newlines, found_comment, _ = format_args args, true
            if @token.type == :"," || @token.type == :NEWLINE
              if has_newlines
                write ","
                write_line
                write_indent
              end
              next_token_skip_space_or_newline
            else
              skip_space_or_newline
            end
            write_token :"]"

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
                write_token " ", @token.type
                skip_space
                accept_assign_value_after_equals (last_arg as Call).args.last
                return false
              end

              write " ="
              next_token_skip_space
              accept_assign_value_after_equals last_arg
            end

            return false
          elsif @token.type == :"[]"
            write "[]"
            next_token

            if node.name == "[]="
              skip_space_or_newline
              write_token " ", :"=", " "
              skip_space_or_newline
              accept node.args.last
            end

            return false
          else
            write " " if needs_space
            write node.name

            # This is the case of a-1 and a+1
            if @token.type == :NUMBER
              @lexer.current_pos = @token.start + 1
            end

            slash_is_regex!
          end

          next_token
          found_comment = skip_space
          if found_comment || @token.type == :NEWLINE
            skip_space_write_line
            skip_space_or_newline
            write_indent(@indent + 2, node.args.last)
          else
            write " " if needs_space
            accept node.args.last
          end
          return false
        end

        next_token
        skip_space
        if @token.type == :NEWLINE
          newline_indent = @dot_column || @indent + 2
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
        write_token :"]"
        write_token :"?" if node.name == "[]?"
        return false
      end

      current_dot_column = @dot_column

      assignment = node.name.ends_with?('=') && node.name.chars.any?(&.alpha?)

      if assignment
        write node.name[0...-1]
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
          next_token_skip_space

          assign_arg = (node.args.last as Call).args.last
          accept_assign_value_after_equals assign_arg
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
          write_token :")"
        else
          write " ="
          skip_space
          accept_assign_value_after_equals node.args.last
        end

        @dot_column = current_dot_column
        return false
      end

      has_parentheses = false
      ends_with_newline = false
      has_args = !node.args.empty? || node.named_args

      column = @indent
      has_newlines = false
      found_comment = false

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
        has_newlines, found_comment = format_call_args(node, true)
        found_comment ||= skip_space
        if @token.type == :NEWLINE
          ends_with_newline = true
        end
        skip_space_or_newline
      elsif has_args || node.block_arg
        write " "
        skip_space
        has_newlines, found_comment = format_call_args(node, false)
      end

      if block = node.block
        needs_space = !has_parentheses || has_args
        skip_space
        if has_parentheses && @token.type == :")"
          write ")"
          next_token_skip_space_or_newline
          format_block block, needs_space
          @dot_column = current_dot_column
          return false
        end
        format_block block, needs_space
      end

      if has_args || node.block_arg
        finish_args(has_parentheses, has_newlines, ends_with_newline, found_comment, column)
      elsif has_parentheses
        write_token :")"
      end

      @dot_column = current_dot_column
      false
    end

    def format_call_args(node : ASTNode, has_parentheses)
      format_args node.args, has_parentheses, node.named_args, node.block_arg
    end

    def format_args(args : Array, has_parentheses, named_args = nil, block_arg = nil, needed_indent = @indent + 2, do_consume_newlines = false)
      has_newlines = false
      found_comment = false

      unless args.empty?
        has_newlines, found_comment, needed_indent = format_args_simple(args, needed_indent, do_consume_newlines)
      end

      if named_args
        has_newlines, named_args_found_comment, needed_indent = format_named_args(args, named_args, needed_indent) if named_args
        found_comment = true if args.empty? && named_args_found_comment
      end

      if block_arg
        has_newlines = format_block_arg(block_arg, needed_indent)
      end

      {has_newlines, found_comment, needed_indent}
    end

    def format_args_simple(args, needed_indent, do_consume_newlines)
      has_newlines = false
      found_comment = false

      if @token.type == :NEWLINE
        if do_consume_newlines
          indent(needed_indent) { consume_newlines }
          skip_space_or_newline
        else
          write_line
          indent(needed_indent) { next_token_skip_space_or_newline }
        end
        next_needs_indent = true
        has_newlines = true
      end

      skip_space_or_newline
      args.each_with_index do |arg, i|
        if next_needs_indent
          write_indent(needed_indent, arg)
        else
          indent(@indent, arg)
        end
        next_needs_indent = false
        unless last?(i, args)
          skip_space
          slash_is_regex!
          write_token :","
          found_comment = skip_space
          if found_comment
            write_indent(needed_indent)
          else
            if @token.type == :NEWLINE
              indent(needed_indent) { consume_newlines }
              next_needs_indent = true
              has_newlines = true
            else
              write " "
            end
          end
          skip_space_or_newline
        end
      end

      {has_newlines, found_comment, needed_indent}
    end

    def format_named_args(args, named_args, needed_indent)
      skip_space

      named_args_column = needed_indent

      if args.empty?
      else
        write_token :","
        skip_space
        if @token.type == :NEWLINE
        else
          write " "
        end
      end

      format_args named_args, false, needed_indent: named_args_column, do_consume_newlines: true
    end

    def format_block_arg(block_arg, needed_indent)
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
      write_token :"&"
      skip_space_or_newline
      accept block_arg
      has_newlines
    end

    def finish_args(has_parentheses, has_newlines, ends_with_newline, found_comment, column)
      skip_space

      if has_parentheses
        if @token.type == :","
          next_token
          skip_space(write_comma: true)
          skip_space_or_newline
          if has_newlines
            unless found_comment
              write ","
              write_line
            end
            write_indent(column)
          end
        elsif found_comment
          write_indent(column)
        end
        check :")"

        if ends_with_newline
          write_line
          write_indent(column)
        end
        write ")"
        next_token
      end
    end

    def format_parenthesized_args(args, named_args = nil)
      write "("
      next_token_skip_space
      has_newlines, found_comment, _ = format_args args, true, named_args: named_args
      skip_space
      ends_with_newline = @token.type == :NEWLINE
      finish_args(true, has_newlines, ends_with_newline, found_comment, @indent)
    end

    def visit(node : NamedArgument)
      write node.name
      next_token_skip_space_or_newline
      write_token :":", " "
      skip_space_or_newline
      accept node.value

      false
    end

    def format_block(node, needs_space)
      needs_comma = false
      @dot_column = nil

      if @token.type == :","
        needs_comma = true
        next_token_skip_space_or_newline
      end

      if @token.keyword?(:do)
        write " do"
        next_token_skip_space
        format_block_args node.args
        format_nested_with_end node.body
      elsif @token.type == :"{"
        write "," if needs_comma
        write " {"
        next_token_skip_space
        format_block_args node.args
        if @token.type == :NEWLINE
          format_nested node.body
          skip_space_or_newline
          write_indent
        else
          unless node.body.is_a?(Nop)
            write " "
            accept node.body
          end
          skip_space_or_newline
          write " "
        end
        write_token :"}"
      else
        # It's foo &.bar
        write "," if needs_comma
        write " " if needs_space
        write_token :"&"
        skip_space_or_newline
        write_token :"."
        skip_space_or_newline

        body = node.body
        case body
        when Call
          call = body
          clear_obj call

          if !call.obj && (call.name == "[]" || call.name == "[]?")
            case @token.type
            when :"["
              write_token :"["
              skip_space_or_newline
              format_call_args(call, false)
              skip_space_or_newline
              write_token :"]"
              write_token :"?" if call.name == "[]?"
            when :"[]", :"[]?"
              write_token @token.type
              skip_space_or_newline
              if @token.type == :"("
                write "("
                next_token_skip_space_or_newline
                format_call_args(call, true)
                skip_space_or_newline
                write_token :")"
              end
            else
              raise "Bug: expected `[`, `[]` or `[]?`"
            end
          elsif !call.obj && call.name == "[]="
            case @token.type
            when :"["
              last_arg = call.args.pop
              write_token :"["
              skip_space_or_newline
              format_call_args(call, false)
              skip_space_or_newline
              write_token :"]"
              skip_space
              write_token " ", :"=", " "
              skip_space_or_newline
              accept last_arg
            when :"[]="
              write_token @token.type
              skip_space_or_newline
              if @token.type == :"("
                write "("
                next_token_skip_space_or_newline
                format_call_args(call, true)
                skip_space_or_newline
                write_token :")"
              end
            else
              raise "Bug: expected `[` or `[]=`"
            end
          else
            indent(@indent, call)
          end
        when IsA
          call = Call.new(nil, "is_a?", args: [body.const] of ASTNode)
          accept call
        when RespondsTo
          call = Call.new(nil, "responds_to?", args: [SymbolLiteral.new(body.name.to_s)] of ASTNode)
          accept call
        else
          raise "Bug: expected Call, IsA or RespondsTo as &. argument, at #{node.location}"
        end
      end
    end

    def format_block_args(args)
      return if args.empty?

      write_token " ", :"|"
      skip_space_or_newline
      args.each_with_index do |arg, i|
        accept arg
        skip_space_or_newline
        if @token.type == :","
          next_token_skip_space_or_newline
          write ", " unless last?(i, args)
        end
      end
      skip_space_or_newline
      write_token :"|"
      skip_space
    end

    def visit(node : IsA)
      format_special_call(node, :is_a?) do
        accept node.const
        skip_space
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
      accept node.obj
      skip_space_or_newline
      write_token :"."
      skip_space_or_newline
      write_keyword keyword
      skip_space_or_newline

      has_parentheses = false
      if @token.type == :"("
        write "("
        next_token_skip_space_or_newline
        has_parentheses = true
      else
        write " "
      end

      yield

      write_token :")" if has_parentheses

      false
    end

    def visit(node : Or)
      format_binary node, :"||", :"||="
    end

    def visit(node : And)
      format_binary node, :"&&", :"&&="
    end

    def format_binary(node, token, alternative)
      accept node.left
      skip_space_or_newline

      # This is the case of `left ||= right`
      if @token.type == alternative
        write " "
        write alternative
        write " "
        next_token_skip_space
        case right = node.right
        when Assign
          accept_assign_value(right.value)
        when Call
          accept_assign_value(right.args.last)
        else
          raise "Bug: expected Assign or Call after op assign, at #{node.location}"
        end
        return false
      end

      write_token " ", token
      skip_space
      if @token.type == :NEWLINE
        next_token_skip_space_or_newline
        write_line
        next_indent = @inside_cond == 0 ? @indent + 2 : @indent
        write_indent(next_indent, node.right)
        return false
      end

      skip_space_or_newline
      write " "
      accept node.right

      false
    end

    def visit(node : Not)
      write_token :"!"
      skip_space_or_newline
      accept node.exp

      false
    end

    def visit(node : Assign)
      accept node.target
      skip_space_or_newline

      if @token.type == :"="
        check_align = check_assign_length node.target
        slash_is_regex!
        write_token " ", :"="
        skip_space
        accept_assign_value_after_equals node.value, check_align: check_align
      else
        # This is the case of `target op= value`
        write " "
        write @token.type
        next_token_skip_space
        value = (node.value as Call).args.last
        accept_assign_value_after_equals value
      end

      false
    end

    def accept_assign_value_after_equals(value, check_align = false)
      if @token.type == :NEWLINE
        next_token_skip_space_or_newline
        write_line
        write_indent(@indent + 2, value)
      else
        write " "
        accept_assign_value value, check_align: check_align
      end
    end

    def accept_assign_value(value, check_align = false)
      before_column = @column
      if @token.keyword?(:if) || @token.keyword?(:case)
        indent(@column, value)
      else
        accept value
      end
      check_assign_align before_column, value if check_align
    end

    def check_assign_length(exp)
      if assign_length = @assign_length
        target_length = assign_length(exp)
        gap = assign_length - target_length
        gap.times { write " " }
        @assign_length = nil
        true
      else
        false
      end
    end

    def check_assign_align(before_column, exp)
      if exp.is_a?(NumberLiteral)
        @assign_infos << AlignInfo.new(0, @line, before_column, @column, @column, true)
      end
    end

    def visit(node : Require)
      write_keyword :require, " "
      accept StringLiteral.new(node.string)

      false
    end

    def visit(node : VisibilityModifier)
      write_keyword node.modifier, " "
      accept node.exp

      false
    end

    def visit(node : MagicConstant)
      check node.name
      write node.name
      next_token

      false
    end

    def visit(node : ModuleDef)
      write_keyword :module, " "

      accept node.name
      format_type_vars node.type_vars

      format_nested_with_end node.body

      false
    end

    def visit(node : ClassDef)
      if node.abstract
        write_keyword :abstract, " "
      end

      if node.struct
        write_keyword :struct, " "
      else
        write_keyword :class, " "
      end

      accept node.name
      format_type_vars node.type_vars

      if superclass = node.superclass
        skip_space_or_newline
        write_token " ", :"<", " "
        skip_space_or_newline
        accept superclass
      end

      format_nested_with_end node.body

      false
    end

    def format_type_vars(type_vars)
      if type_vars
        skip_space
        write_token :"("
        skip_space_or_newline
        type_vars.each_with_index do |type_var, i|
          write type_var
          next_token_skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, type_vars)
            next_token_skip_space_or_newline
          end
        end
        write_token :")"
        skip_space
      end
    end

    def visit(node : StructOrUnionDef)
      keyword = node.is_a?(StructDef) ? :struct : :union
      write_keyword keyword, " "

      write node.name
      next_token

      @inside_struct_or_union += 1
      format_nested_with_end node.body
      @inside_struct_or_union -= 1

      false
    end

    def visit(node : Include)
      write_keyword :include, " "
      accept node.name

      false
    end

    def visit(node : Extend)
      write_keyword :extend, " "
      accept node.name

      false
    end

    def visit(node : LibDef)
      @inside_lib += 1

      write_keyword :lib, " "

      check :CONST
      write node.name
      next_token

      format_nested_with_end node.body

      @inside_lib -= 1

      false
    end

    def visit(node : EnumDef)
      write_keyword :enum, " "
      accept node.name

      if base_type = node.base_type
        skip_space
        write_token " ", :":", " "
        skip_space_or_newline
        accept base_type
      end

      format_nested_with_end Expressions.from(node.members)

      false
    end

    def visit(node : TypeDeclaration)
      accept node.var
      skip_space_or_newline
      check :":"
      next_token_skip_space_or_newline
      write " : "
      accept node.declared_type

      false
    end

    def visit(node : UninitializedVar)
      accept node.var
      skip_space_or_newline
      write_token " ", :"=", " "
      skip_space_or_newline
      write_keyword :"uninitialized", " "
      skip_space_or_newline
      accept node.declared_type
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
      write_keyword keyword

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
          format_args(exp.elements, has_parentheses)
          skip_space if has_parentheses
        else
          indent(@indent, exp)
          skip_space
        end
      end

      write_token :")" if has_parentheses

      false
    end

    def visit(node : Yield)
      if scope = node.scope
        write_keyword :with, " "
        accept scope
        skip_space_or_newline
        write " "
      end

      write_keyword :yield

      if @token.type == :"("
        format_parenthesized_args(node.exps)
      else
        write " " unless node.exps.empty?
        skip_space
        format_args node.exps, false
      end

      false
    end

    def visit(node : Case)
      slash_is_regex!
      write_keyword :case
      skip_space

      if cond = node.cond
        write " "
        accept cond
      end

      skip_space_write_line

      node.whens.each_with_index do |a_when, i|
        write_indent { format_when(node, a_when, last?(i, node.whens)) }
        indent(@indent + 2) { skip_space_or_newline }
      end

      skip_space_or_newline

      if a_else = node.else
        write_indent
        write_keyword :else
        found_comment = skip_space
        if @token.type == :NEWLINE || found_comment
          unless found_comment
            write_line
            next_token
          end
          indent(@indent + 2) { skip_space_or_newline }
          format_nested(a_else, @indent)
          indent(@indent + 2) { skip_space_or_newline }
        else
          @when_infos << AlignInfo.new(node.object_id, @line, @column, @column, @column, false)
          write " "
          accept a_else
          found_comment = skip_space_or_newline
          write_line unless found_comment
        end
      end

      check_end
      write_indent
      write "end"
      next_token

      false
    end

    def format_when(case_node, node, is_last)
      skip_space_or_newline

      slash_is_regex!
      write_keyword :when, " "
      base_indent = @column
      when_start_line = @line
      when_start_column = @column
      next_needs_indent = false
      node.conds.each_with_index do |cond, i|
        write_indent(base_indent) if next_needs_indent
        accept cond
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
              skip_space_or_newline
              next_needs_indent = true
            else
              write " "
            end
          end
        end
      end
      when_column_middle = @column
      indent { skip_space }
      if @token.type == :";" || @token.keyword?(:then)
        separator = @token.to_s
        slash_is_regex!
        if @token.type == :";"
          skip_semicolon_or_space
        else
          next_token_skip_space
        end
        if @token.type == :NEWLINE
          format_nested(node.body, @indent)
        else
          write " " if separator == "then"
          write separator
          write " "
          when_column_end = @column
          accept node.body
          if @line == when_start_line
            number = node.conds.size == 1 && node.conds.first.is_a?(NumberLiteral)
            @when_infos << AlignInfo.new(case_node.object_id, @line, when_start_column, when_column_middle, when_column_end, number)
          end
          found_comment = skip_space
          write_line unless found_comment
        end
      else
        format_nested(node.body, @indent)
      end

      false
    end

    def visit(node : ImplicitObj)
      false
    end

    def visit(node : Attribute)
      write_token :"@["
      skip_space_or_newline

      write @token
      next_token_skip_space

      if @token.type == :"("
        has_args = !node.args.empty? || node.named_args
        if has_args
          format_parenthesized_args(node.args, named_args: node.named_args)
        else
          next_token_skip_space_or_newline
          check :")"
          next_token_skip_space_or_newline
        end
      end

      write_token :"]"

      false
    end

    def visit(node : Cast)
      accept node.obj
      write_keyword " ", :as, " "
      accept node.to
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
      write_keyword keyword
      skip_space_or_newline
      write_token :"("
      skip_space_or_newline
      yield
      skip_space_or_newline
      write_token :")"

      false
    end

    def visit(node : Underscore)
      check :UNDERSCORE
      write "_"
      next_token

      false
    end

    def visit(node : MultiAssign)
      node.targets.each_with_index do |target, i|
        accept target
        skip_space_or_newline
        if @token.type == :","
          write ", " unless last?(i, node.targets)
          next_token_skip_space_or_newline
        end
      end

      write_token " ", :"="
      skip_space
      if @token.type == :NEWLINE && node.values.size == 1
        next_token_skip_space_or_newline
        write_line
        write_indent(@indent + 2, node.values.first)
      else
        write " "
        format_mutli_assign_values node.values
      end

      false
    end

    def format_mutli_assign_values(values)
      if values.size == 1
        accept_assign_value values.first
      else
        indent(@column) do
          values.each_with_index do |value, i|
            accept value
            unless last?(i, values)
              skip_space_or_newline
              if @token.type == :","
                write ", "
                next_token_skip_space_or_newline
              end
            end
          end
        end
      end
    end

    def visit(node : ExceptionHandler)
      column = @indent

      implicit_handler = false
      if node.implicit
        accept node.body
        skip_space_or_newline

        write_line
        implicit_handler = true
        column = @def_indent
      else
        if node.suffix
          accept node.body
          skip_space
          write " rescue "
          next_token_skip_space_or_newline
          accept node.rescues.not_nil!.first.not_nil!.body
          return false
        end
      end

      unless implicit_handler
        write_keyword :begin
        format_nested(node.body, column)
      end

      if node_rescues = node.rescues
        node_rescues.each_with_index do |node_rescue, i|
          skip_space_or_newline
          write_indent(column)
          write_keyword :rescue

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
              write_token " ", :":", " "
              skip_space_or_newline
            else
              write " "
            end
            types.each_with_index do |type, j|
              accept type
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
        write_indent(column)
        write_keyword :else
        format_nested(node_else, column)
      end

      if node_ensure = node.ensure
        skip_space_or_newline
        write_indent(column)
        write_keyword :ensure
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
      write_keyword keyword, " "

      write node.name
      next_token_skip_space_or_newline

      write_token " ", :"=", " "
      skip_space_or_newline

      accept value

      false
    end

    def visit(node : FunPointer)
      write_token :"->"
      skip_space_or_newline

      call = Call.new(node.obj, node.name, node.args)
      accept call

      false
    end

    def visit(node : FunLiteral)
      write_token :"->"
      skip_space_or_newline

      a_def = node.def

      if @token.type == :"("
        write "(" unless a_def.args.empty?
        next_token_skip_space_or_newline

        a_def.args.each_with_index do |arg, i|
          accept arg
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
        write_keyword :do
        is_do = true
      else
        write_token :"{"
      end
      skip_space

      if @token.type == :NEWLINE
        format_nested a_def.body
      else
        skip_space_or_newline
        unless a_def.body.is_a?(Nop)
          write " "
          accept a_def.body
          write " "
        end
      end

      skip_space_or_newline

      if is_do
        check_end
        write_indent
        write "end"
        next_token
      else
        if @wrote_newline
          write_indent
        end
        write_token :"}"
      end

      false
    end

    def visit(node : ExternalVar)
      check :GLOBAL
      write @token.value
      next_token_skip_space_or_newline

      if @token.type == :"="
        write " = "
        next_token_skip_space_or_newline
        write @token.value
        next_token_skip_space_or_newline
      end

      write_token " ", :":", " "
      skip_space_or_newline

      accept node.type_spec

      false
    end

    def visit(node : Out)
      write_keyword :out, " "
      accept node.exp

      false
    end

    def visit(node : Metaclass)
      accept node.name
      skip_space

      write_token :"."
      skip_space_or_newline
      write_keyword :class

      false
    end

    def visit(node : Virtual)
      accept node.name
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

    def visit(node : Asm)
      write_keyword :asm
      skip_space_or_newline

      column = @column
      has_newlines = false

      write_token :"("
      skip_space

      if @token.type == :NEWLINE
        consume_newlines
        has_newlines = true
      end
      skip_space_or_newline

      string = StringLiteral.new(node.text)

      if has_newlines
        write_indent(@indent + 2, string)
      else
        indent(@column, string)
      end

      skip_space

      if @token.type == :NEWLINE
        if node.output || node.inputs
          consume_newlines
          column += 4
          write_indent(column)
        end
      end

      skip_space_or_newline

      if @token.type == :"::"
        write " ::"
        next_token_skip_space_or_newline
      elsif @token.type == :":"
        dot_column = @column + 1
        space_after_output = true

        write " :"
        next_token

        skip_space_or_newline

        output = node.output
        if output
          write " "
          accept output
          skip_space
          if @token.type == :NEWLINE
            if node.inputs
              consume_newlines
              write_indent(dot_column)
              space_after_output = false
            else
              skip_space_or_newline
            end
          end
        end

        if @token.type == :":"
          write " " if output && space_after_output
          write ":"
          next_token_skip_space_or_newline
        end
      end

      if inputs = node.inputs
        write " "
        input_column = @column
        inputs.each_with_index do |input, i|
          accept input
          skip_space

          if @token.type == :","
            write "," unless last?(i, inputs)
            next_token_skip_space

            unless last?(i, inputs)
              if @token.type == :NEWLINE
                consume_newlines
                write_indent(input_column)
              else
                write " " unless last?(i, inputs)
              end
              skip_space_or_newline
            end
          end
        end
      end

      if clobbers = node.clobbers
        write_token :":"
        write " "
        skip_space_or_newline
        clobbers.each_with_index do |clobber, i|
          accept StringLiteral.new(clobber)
          skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, clobbers)
            next_token_skip_space_or_newline
          end
        end
      end

      if @token.type == :"::" || @token.type == :":"
        write " " if @token.type == :":"
        write @token.type
        write " "
        next_token_skip_space_or_newline
        while @token.type == :DELIMITER_START
          accept StringLiteral.new("")
          skip_space_or_newline
          if @token.type == :","
            write ", "
            next_token_skip_space_or_newline
          end
        end
      end

      skip_space_or_newline

      if has_newlines
        write_line
        write_indent
      end

      write_token :")"

      false
    end

    def visit(node : AsmOperand)
      accept StringLiteral.new(node.constraint)

      skip_space_or_newline
      write_token :"("
      skip_space_or_newline
      accept node.exp
      skip_space_or_newline
      write_token :")"

      false
    end

    def to_s(io)
      io << @output
    end

    def next_token
      current_line_number = @lexer.line_number
      @token = @lexer.next_token
      if @token.type == :DELIMITER_START
        increment_lines(@lexer.line_number - current_line_number)
      end
      @token
    end

    def next_string_token
      current_line_number = @lexer.line_number
      @token = @lexer.next_string_token(@token.delimiter_state)
      increment_lines(@lexer.line_number - current_line_number)
      @token
    end

    def next_string_array_token
      @token = @lexer.next_string_array_token
    end

    def next_macro_token
      current_line_number = @lexer.line_number

      char = @lexer.current_char
      @token = @lexer.next_macro_token(@macro_state, false)
      @macro_state = @token.macro_state

      increment_lines(@lexer.line_number - current_line_number)

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

    def skip_space_or_newline(last = false, at_least_one = false)
      just_wrote_line = @wrote_newline
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
        when :";"
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
          if newlines > 1
            write_line if !just_wrote_line && !@wrote_newline
            write_line
          elsif !@wrote_newline
            write_line
          elsif at_least_one
            write_line
          end
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

    def skip_semicolon_or_space
      found_comment = false
      while true
        case @token.type
        when :";"
          next_token
        when :SPACE
          found_comment ||= skip_space
        else
          break
        end
      end
      found_comment
    end

    def skip_semicolon_or_space_or_newline
      while true
        case @token.type
        when :";"
          next_token
        when :SPACE, :NEWLINE
          skip_space_or_newline
        else
          break
        end
      end
    end

    def jump_semicolon
      skip_space
      skip_semicolon
      skip_space_or_newline
    end

    def write_comment(needs_indent = true)
      while @token.type == :COMMENT
        empty_line = @line_output.to_s.strip.empty?
        if empty_line
          write_indent if needs_indent
        end

        value = @token.value.to_s.strip
        raw_after_comment_value = value[1..-1]
        after_comment_value = raw_after_comment_value.strip
        if after_comment_value.starts_with?("=>")
          value = "\# => #{after_comment_value[2..-1].strip}"
        else
          char_1 = value[1]?
          if char_1 && !char_1.whitespace?
            value = "\# #{value[1..-1].strip}"
          end
        end

        if !@last_write.empty? && !@last_write[-1].whitespace?
          write " "
        end

        unless @line_output.to_s.strip.empty?
          @comment_columns[-1] = @column
        end

        if empty_line
          current_doc_comment = @current_doc_comment

          if after_comment_value.starts_with?("```")
            if current_doc_comment
              current_doc_comment.end_line = @line - 1
              @doc_comments << current_doc_comment
              @current_doc_comment = nil
            else
              @current_doc_comment = CommentInfo.new(@line + 1, :backticks)
            end
          end
        end

        @wrote_comment = true
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

    def indent
      @indent += 2
      yield
      @indent -= 2
    end

    def indent(node : ASTNode)
      indent { accept node }
    end

    def indent(indent : Int)
      old_indent = @indent
      @indent = indent
      yield
      @indent = old_indent
    end

    def indent(indent : Int, node : ASTNode | HashLiteral::Entry)
      indent(indent) { accept node }
    end

    def no_indent(node : ASTNode)
      no_indent { accept node }
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

    def write_indent(indent, node)
      write_indent(indent)
      indent(indent, node)
    end

    def write_indent(indent = @indent)
      write_indent(indent)
      indent(indent) { yield }
    end

    def write(string : String)
      @output << string
      @line_output << string
      last_newline = string.rindex('\n')
      if last_newline
        @column = string.size - last_newline - 1
      else
        @column += string.size
      end
      @wrote_newline = false
      @last_write = string
    end

    def write(obj)
      write obj.to_s
    end

    def write_line
      @current_doc_comment = nil unless @wrote_comment
      @wrote_comment = false

      @output.puts
      @line_output.clear
      @column = 0
      @wrote_newline = true
      increment_line
      @last_write = ""
    end

    def increment_line
      @line += 1
      @comment_columns << nil
    end

    def increment_lines(count)
      count.times { increment_line }
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
      skip_space_or_newline last: true
      result = to_s.strip
      lines = result.split("\n")
      align_infos(lines, @when_infos)
      align_infos(lines, @hash_infos)
      align_infos(lines, @assign_infos)
      align_comments(lines)
      format_doc_comments(lines)
      lines.map!(&.rstrip)
      result = lines.join("\n") + '\n'
      result = "" if result == "\n"
      if @shebang
        result = result[0] + result[2..-1]
      end
      result
    end

    # Align series of successive inline when/else (in a case),
    # or hash literals (the left side of the =>)
    def align_infos(lines, align_infos)
      max_size = nil
      last_info = nil

      align_infos.each_with_index do |align_info, i|
        if max_size
          align_info lines, align_info, max_size
        else
          last_info, max_size = find_last_info(align_infos, align_info, i + 1)
          align_info lines, align_info, max_size
        end

        if last_info && align_info.line == last_info.line
          last_info = nil
          max_size = nil
        end
      end
    end

    def find_last_info(align_infos, base, i)
      max_size = base.size

      while i < align_infos.size
        current = align_infos[i]
        break unless current.id == base.id
        break unless base.line + 1 == current.line

        base = current
        max_size = base.size if base.size > 0 && base.size > max_size

        i += 1
      end

      {base, max_size}
    end

    def align_info(lines, info, max_size)
      gap = max_size - info.size
      return if gap == 0

      line = lines[info.line]

      if info.number
        middle = info.start_column
      else
        middle = info.middle_column
      end

      before = line[0...middle]
      after = line[middle..-1]
      result = String.build do |str|
        str << before
        gap.times { str << " " }
        str << after
      end

      lines[info.line] = result

      # Make sure to move the comment in this line too
      comment_column = @comment_columns[info.line]?
      if comment_column
        comment_column += gap
        @comment_columns[info.line] = comment_column
      end
    end

    # Align series of successive comments
    def align_comments(lines)
      max_column = nil

      lines.each_with_index do |line, i|
        comment_column = @comment_columns[i]?
        if comment_column
          if max_column
            lines[i] = align_comment line, i, comment_column, max_column
          else
            max_column = find_max_column(lines, i + 1, comment_column)
            lines[i] = align_comment line, i, comment_column, max_column
          end
        else
          max_column = nil
        end
      end
    end

    def find_max_column(lines, base, max)
      while base < @comment_columns.size
        comment_column = @comment_columns[base]?
        break unless comment_column

        max = comment_column if comment_column > max
        base += 1
      end

      max
    end

    def align_comment(line, i, comment_column, max_column)
      return line if comment_column == max_column

      source_line = line[0...comment_column]
      comment_line = line[comment_column..-1]
      gap = max_column - comment_column

      result = String.build do |str|
        str << source_line
        gap.times { str << " " }
        str << comment_line
      end
      result
    end

    def format_doc_comments(lines)
      @doc_comments.reverse_each do |doc_comment|
        next if doc_comment.start_line > doc_comment.end_line

        first_line = lines[doc_comment.start_line]
        sharp_index = first_line.index('#').not_nil!

        comment = String.build do |str|
          (doc_comment.start_line..doc_comment.end_line).each do |i|
            line = lines[i].strip[1..-1]
            line = line[1..-1] if line[0]? == ' '
            str << line
            str << '\n'
          end
        end

        begin
          formatted_comment = Formatter.format(comment)
          formatted_lines = formatted_comment.lines
          formatted_lines.map! do |line|
            String.build do |str|
              sharp_index.times { str << " " }
              str << "# "
              str << line
            end
          end
          lines[doc_comment.start_line..doc_comment.end_line] = formatted_lines
        rescue Crystal::SyntaxException
          # For now we don't care if doc comments have syntax errors,
          # they shouldn't prevent formatting the real code
        end
      end
    end

    def write_keyword(keyword : Symbol)
      check_keyword keyword
      write keyword
      next_token
    end

    def write_keyword(before : String, keyword : Symbol)
      write before
      write_keyword keyword
    end

    def write_keyword(keyword : Symbol, after : String, skip_space_or_newline = true)
      write_keyword keyword
      write after
      skip_space_or_newline() if skip_space_or_newline
    end

    def write_keyword(before : String, keyword : Symbol, after : String)
      skip_space_or_newline
      write before
      write_keyword keyword
      write after
      skip_space_or_newline
    end

    def write_token(type : Symbol)
      check type
      write type
      next_token
    end

    def write_token(before : String, type : Symbol)
      write before
      write_token type
    end

    def write_token(type : Symbol, after : String)
      write_token type
      write after
    end

    def write_token(before : String, type : Symbol, after : String)
      write before
      write_token type
      write after
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
        increment_line
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
