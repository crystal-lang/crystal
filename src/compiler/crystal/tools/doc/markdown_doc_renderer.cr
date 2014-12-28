class Crystal::Doc::MarkdownDocRenderer < Markdown::HTMLRenderer
  def initialize(@type, io)
    super(io)

    @inside_inline_code = false
    @found_inilne_method = false
    @inline_code_buffer = StringIO.new
    @inside_code = false
    @inside_link = false
  end

  # For inline code we search if there's a method with that name in
  # the current type (it's usual to refer to these as `method`).
  #
  # If there is a match, we output the link without the <code>...</code>
  # tag (looks better). If there isn't a match, we want to preserve the code tag.
  def begin_inline_code
    super
    @inside_inline_code = true
    @inline_code_buffer.clear
    @found_inilne_method = true
  end

  def end_inline_code
    super
    @inside_inline_code = false

    if @found_inilne_method
      @io << @inline_code_buffer
    else
      @io << "<code>"
      @io << @inline_code_buffer
      @io << "</code>"
    end
  end

  def begin_code(language = nil)
    super
    @inside_code = true
  end

  def end_code
    super
    @inside_code = false
  end

  def begin_link(url)
    @io << %(<a href=")
    @io << url
    @io << %(" target="_blank">)
    @inside_link = true
  end

  def end_link
    super
    @inside_link = false
  end

  def text(text)
    if @inside_code
      text = highlight text
      super text
      return
    end

    if @inside_link
      super
      return
    end

    # Check #method(...) reference
    if @inside_inline_code
      if text =~ /(\w+(?:\?|\!)?)(\(.+?\))?/
        name = $1
        args = $2

        method = lookup_method @type, name, args
        if method
          text = method_link @type, method, "##{text}"
        else
          @found_inilne_method = false
        end
      else
        @found_inilne_method = false
      end

      @inline_code_buffer << text
      return
    end

    # Check Type#method(...) or Type or #method(...)
    text = text.gsub /\b
      ([A-Z]\w+(?:\:\:[A-Z]\w+)?\#\w+(?:\?|\!)?(?:\(.+?\))?)
        |
      ([A-Z]\w+(?:\:\:[A-Z]\w+)?)
        |
      (\#\w+(?:\?|\!)?(?:\(.+?\))?)
      /x do |match_text, match|

      # Type#method(...)
      unless match[1].empty?
        sharp_index = match_text.index('#').not_nil!
        type_name = match_text[0 ... sharp_index]

        paren_index = match_text.index('(')

        if paren_index
          method_name = match_text[sharp_index + 1 ... paren_index]
          method_args = match_text[paren_index + 1 .. -2]
        else
          method_name = match_text[sharp_index + 1 .. -1]
          method_args = ""
        end

        another_type = @type.lookup_type(type_name.split("::"))
        if another_type
          method = lookup_method another_type, method_name, method_args
          if method
            next method_link another_type, method, match_text
          end
        end
      end

      # Type
      unless match[2].empty?
        another_type = @type.lookup_type(match_text.split("::"))
        if another_type
          next type_link another_type, match_text
        end
      end

      # #method(...)
      unless match[3].empty?
        paren_index = match_text.index('(')

        if paren_index
          method_name = match_text[1 ... paren_index]
          method_args = match_text[paren_index + 1 .. -2]
        else
          method_name = match_text[1 .. -1]
          method_args = ""
        end

        method = lookup_method @type, method_name, method_args
        if method
          next method_link @type, method, match_text
        end
      end

      match_text
    end

    super(text)
  end

  def type_link(type, text)
    %(<a href="#{type.path_from(@type)}">#{text}</a>)
  end

  def method_link(type, method, text)
    %(<a href="#{type.path_from(@type)}##{method.anchor}">#{text}</a>)
  end

  def lookup_method(type, name, args)
    case args
    when ""
      args_count = nil
    when "()"
      args_count = 0
    else
      args_count = args.chars.count(',') + 1
    end

    type.lookup_method(name, args_count)
  end

  def highlight(text)
    lexer = Lexer.new(text)
    lexer.comments_enabled = true
    lexer.count_whitespace = true

    String.build do |io|
      begin
        highlight_normal_state lexer, io
      rescue Crystal::SyntaxException
      end
    end
  end

  def highlight_normal_state(lexer, io, break_on_rcurly = false)
    last_is_def = false

    while true
      token = lexer.next_token
      case token.type
      when :NEWLINE
        io << '\n'
      when :SPACE
        io << token.value
      when :COMMENT
        highlight token, "c", io
      when :NUMBER
        highlight token, "n", io
      when :CONST, :"::"
        highlight token, "t", io
      when :DELIMITER_START
        highlight_delimiter_state lexer, token, io
      when :EOF
        break
      when :IDENT
        if last_is_def
          last_is_def = false
          highlight token, "m", io
        else
          case token.value
          when :def, :if, :else, :elsif, :end,
               :class, :module, :include, :extend,
               :while, :until, :do, :yield, :return, :unless, :next, :break, :begin,
               :lib, :fun, :type, :struct, :union, :enum, :macro, :ptr, :out, :require,
               :case, :when, :then, :of, :abstract, :rescue, :ensure, :is_a?,
               :alias, :pointerof, :sizeof, :instance_sizeof, :ifdef, :as, :typeof, :for, :in,
               :undef, :with, :self, :super, :private, :protected
            highlight token, "k", io
          when :true, :false, :nil
            highlight token, "n", io
          else
            io << token
          end
        end
      when :"+", :"-", :"*", :"/", :"=", :"==", :"<", :"<=", :">", :">=", :"!", :"!=", :"=~", :"!~", :"&", :"|", :"^", :"~", :"**", :">>", :"<<", :"%", :"[]", :"[]?", :"[]=", :"<=>", :"==="
        highlight token, "o", io
      when :"}"
        if break_on_rcurly
          break
        else
          io << token
        end
      else
        io << token
      end

      unless token.type == :SPACE
        last_is_def = token.keyword? :def
      end
    end
  end

  def highlight_delimiter_state(lexer, token, io)
    start_highlight_klass "s", io

    delimiter_end = token.delimiter_state.end
    case delimiter_end
    when '"' then io << '"'
    when '`' then io << '`'
    when ')' then io << "%("
    end

    while true
      token = lexer.next_string_token(token.delimiter_state)
      case token.type
      when :DELIMITER_END
        io << delimiter_end
        end_highlight_klass io
        break
      when :INTERPOLATION_START
        io << "\#{"
        end_highlight_klass io
        highlight_normal_state lexer, io, break_on_rcurly: true
        start_highlight_klass "s", io
        io << "}"
      when :EOF
        break
      else
        io << token
      end
    end
  end

  def highlight(token, klass, io)
    start_highlight_klass klass, io
    io << token
    end_highlight_klass io
  end

  def start_highlight_klass(klass, io)
    io << %(<span class=")
    io << klass
    io << %(">)
  end

  def end_highlight_klass(io)
    io << %(</span>)
  end
end
