class Crystal::Doc::MarkdownDocRenderer < Crystal::Doc::Markdown::HTMLRenderer
  def initialize(@type : Crystal::Doc::Type, options)
    super(options)
  end

  def self.new(obj : Constant | Macro | Method, options)
    new obj.type, options
  end

  def code_body(text)
    # Check method reference (without #, but must be the whole text)
    if text =~ /\A((?:\w|\<|\=|\>|\+|\-|\*|\/|\[|\]|\&|\||\?|\!|\^|\~)+(?:\?|\!)?)(\(.+?\))?\Z/
      name = $1
      args = $~.not_nil![2]? || ""

      method = lookup_method @type, name, args
      if method
        text = method_link method, "#{method.prefix}#{text}"
        return lit(text)
      end
    end

    # Check Type#method(...) or Type or #method(...)
    text = text.gsub /\b
      ((?:\:\:)?[A-Z]\w+(?:\:\:[A-Z]\w+)*(?:\#|\.)(?:\w|\<|\=|\>|\+|\-|\*|\/|\[|\]|\&|\||\?|\!|\^|\~)+(?:\?|\!)?(?:\(.+?\))?)
        |
      ((?:\:\:)?[A-Z]\w+(?:\:\:[A-Z]\w+)*)
        |
      ((?:\#|\.)(?:\w|\<|\=|\>|\+|\-|\*|\/|\[|\]|\&|\||\?|\!|\^|\~)+(?:\?|\!)?(?:\(.+?\))?)
      /x do |match_text, match|
      sharp_index = match_text.index('#')
      dot_index = match_text.index('.')
      kind = sharp_index ? :instance : :class

      # Type#method(...)
      if match[1]?
        separator_index = (sharp_index || dot_index).not_nil!
        type_name = match_text[0...separator_index]

        paren_index = match_text.index('(')

        if paren_index
          method_name = match_text[separator_index + 1...paren_index]
          method_args = match_text[paren_index + 1..-2]
        else
          method_name = match_text[separator_index + 1..-1]
          method_args = ""
        end

        another_type = @type.lookup_path(type_name)
        if another_type && @type.must_be_included?
          method = lookup_method another_type, method_name, method_args, kind
          if method
            next method_link method, match_text
          end
        end
      end

      # Type
      if match[2]?
        another_type = @type.lookup_path(match_text)
        if another_type && another_type.must_be_included?
          next type_link another_type, match_text
        end
      end

      # #method(...)
      if match[3]?
        paren_index = match_text.index('(')

        if paren_index
          method_name = match_text[1...paren_index]
          method_args = match_text[paren_index + 1..-2]
        else
          method_name = match_text[1..-1]
          method_args = ""
        end

        method = lookup_method @type, method_name, method_args, kind
        if method && method.must_be_included?
          next method_link method, match_text
        end
      end

      match_text
    end

    lit(text)
  end

  def code_block_body(text, language)
    if !language || language == "crystal"
      lit(Highlighter.highlight text)
    else
      out(text)
    end
  end

  def link_tag(tag_name, attrs)
    attrs ||= {} of String => String
    attrs["target"] = "_blank"
    tag(tag_name, attrs)
  end

  private def type_link(type, text)
    %(<a href="#{type.path_from(@type)}">#{text}</a>)
  end

  private def method_link(method, text)
    %(<a href="#{method.type.path_from(@type)}#{method.anchor}">#{text}</a>)
  end

  private def lookup_method(type, name, args, kind = nil)
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
