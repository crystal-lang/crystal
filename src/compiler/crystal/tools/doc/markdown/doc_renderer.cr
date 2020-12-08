require "./*"

class Crystal::Doc::Markdown::DocRenderer < Crystal::Doc::Markdown::HTMLRenderer
  def self.new(obj : Constant | Macro | Method, io)
    new obj.type, io
  end

  @type : Crystal::Doc::Type

  def initialize(@type : Crystal::Doc::Type, io)
    super(io)

    @inside_inline_code = false
    @code_buffer = IO::Memory.new
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
    @code_buffer.clear
  end

  def end_inline_code
    @inside_inline_code = false

    @io << expand_code_links(@code_buffer.to_s)
    super
  end

  def expand_code_links(text : String) : String
    # Check method reference (without #, but must be the whole text)
    if text =~ /\A([\w<=>+\-*\/\[\]&|?!^~]+[?!]?)(?:\((.*?)\))?\Z/
      name = $1
      args = $2? || ""

      method = lookup_method @type, name, args
      if method
        return method_link method, "#{method.prefix}#{text}"
      end
    end

    # Check Type#method(...) or Type or #method(...)
    text.gsub %r(
      ((?:\B::)?\b[A-Z]\w+(?:\:\:[A-Z]\w+)*|\B|(?<=\bself))([#.])([\w<=>+\-*\/\[\]&|?!^~]+[?!]?)(?:\((.*?)\))?
        |
      ((?:\B::)?\b[A-Z]\w+(?:\:\:[A-Z]\w+)*)
      )x do |match_text|
      if $5?
        # Type
        another_type = @type.lookup_path(match_text)
        if another_type && another_type.must_be_included?
          next type_link another_type, match_text
        end
        next match_text
      end

      type_name = $1.presence
      kind = $2 == "#" ? :instance : :class
      method_name = $3
      method_args = $4? || ""

      if type_name
        # Type#method(...)
        another_type = @type.lookup_path(type_name)
        if another_type && @type.must_be_included?
          method = lookup_method another_type, method_name, method_args, kind
          if method
            next method_link method, match_text
          end
        end
      else
        # #method(...)
        method = lookup_method @type, method_name, method_args, kind
        if method && method.must_be_included?
          next method_link method, match_text
        end
      end

      match_text
    end
  end

  def begin_code(language = nil)
    super

    if !language || language == "crystal"
      @inside_code = true
      @code_buffer.clear
    end
  end

  def end_code
    if @inside_code
      text = Highlighter.highlight(@code_buffer.to_s)
      @io << text
    end

    @inside_code = false

    super
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
      @code_buffer << text
      return
    end

    if @inside_link
      super
      return
    end

    if @inside_inline_code
      @code_buffer << text
      return
    end

    super(text)
  end

  def type_link(type, text)
    %(<a href="#{type.path_from(@type)}">#{text}</a>)
  end

  def method_link(method, text)
    %(<a href="#{method.type.path_from(@type)}#{method.anchor}">#{text}</a>)
  end

  def lookup_method(type, name, args, kind = nil)
    case args
    when ""
      args_count = nil
    when "()"
      args_count = 0
    else
      args_count = args.chars.count(',') + 1
    end

    base_match =
      case kind
      when :class
        type.lookup_class_method(name, args_count) || type.lookup_method(name, args_count)
      else
        type.lookup_method(name, args_count) || type.lookup_class_method(name, args_count)
      end
    base_match ||
      type.lookup_macro(name, args_count) ||
      type.program.lookup_macro(name, args_count)
  end
end
