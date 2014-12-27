class Crystal::Doc::MarkdownDocRenderer < Markdown::HTMLRenderer
  def initialize(@type, io)
    super(io)

    @inside_inline_code = false
    @found_inilne_method = false
    @inline_code_buffer = StringIO.new
    @inside_code = false
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

  def begin_code
    super
    @inside_code = true
  end

  def end_code
    super
    @inside_code = false
  end

  def text(text)
    if @inside_code
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
end
