require "uri"

module Markdown
  # :nodoc:
  class HTMLRenderer < Renderer
    @disable_tag = 0
    @last_output = "\n"

    private HEADINGS = %w(h1 h2 h3 h4 h5 h6)

    def heading(node : Node, entering : Bool)
      tag_name = HEADINGS[node.data["level"].as(Int32) - 1]
      if entering
        cr
        tag(tag_name, attrs(node))
      else
        tag(tag_name, end_tag: true)
        cr
      end
    end

    def code(node : Node, entering : Bool)
      tag("code") do
        code_body(node.text)
      end
    end

    def code_body(text)
      out(text)
    end

    def code_block(node : Node, entering : Bool)
      languages = node.fence_language ? node.fence_language.split : nil
      code_tag_attrs = attrs(node)
      pre_tag_attrs = if @options.prettyprint
                        {"class" => "prettyprint"}
                      else
                        nil
                      end

      language = languages.try &.first?.try &.strip
      language = nil if language.try &.empty?

      if language
        code_tag_attrs ||= {} of String => String
        code_tag_attrs["class"] = "language-#{language}"
      end

      cr
      tag("pre", pre_tag_attrs) do
        tag("code", code_tag_attrs) do
          code_block_body(node.text, language)
        end
      end
      cr
    end

    def code_block_body(text, language)
      out(text)
    end

    def thematic_break(node : Node, entering : Bool)
      cr
      tag("hr", attrs(node), self_closing: true)
      cr
    end

    def block_quote(node : Node, entering : Bool)
      cr
      if entering
        tag("blockquote", attrs(node))
      else
        tag("blockquote", end_tag: true)
      end
      cr
    end

    def list(node : Node, entering : Bool)
      tag_name = node.data["type"] == "bullet" ? "ul" : "ol"

      cr
      if entering
        attrs = attrs(node)

        if (start = node.data["start"].as(Int32)) && start != 1
          attrs ||= {} of String => String
          attrs["start"] = start.to_s
        end

        tag(tag_name, attrs)
      else
        tag(tag_name, end_tag: true)
      end
      cr
    end

    def item(node : Node, entering : Bool)
      if entering
        tag("li", attrs(node))
      else
        tag("li", end_tag: true)
        cr
      end
    end

    def link(node : Node, entering : Bool)
      if entering
        attrs = attrs(node)
        if !(@options.safe && potentially_unsafe(node.data["destination"].as(String)))
          attrs ||= {} of String => String
          attrs["href"] = escape(node.data["destination"].as(String))
        end

        if (title = node.data["title"].as(String)) && !title.empty?
          attrs ||= {} of String => String
          attrs["title"] = escape(title)
        end

        link_tag("a", attrs)
      else
        tag("a", end_tag: true)
      end
    end

    def link_tag(tag_name, attrs)
      tag(tag_name, attrs)
    end

    def image(node : Node, entering : Bool)
      if entering
        if @disable_tag == 0
          if @options.safe && potentially_unsafe(node.data["destination"].as(String))
            lit(%(<img src="" alt=""))
          else
            lit(%(<img src="#{escape(node.data["destination"].as(String))}" alt="))
          end
        end
        @disable_tag += 1
      else
        @disable_tag -= 1
        if @disable_tag == 0
          if (title = node.data["title"].as(String)) && !title.empty?
            lit(%(" title="#{escape(title)}))
          end
          lit(%(" />))
        end
      end
    end

    def html_block(node : Node, entering : Bool)
      cr
      content = @options.safe ? "<!-- raw HTML omitted -->" : node.text
      lit(content)
      cr
    end

    def html_inline(node : Node, entering : Bool)
      content = @options.safe ? "<!-- raw HTML omitted -->" : node.text
      lit(content)
    end

    def paragraph(node : Node, entering : Bool)
      if (grand_parant = node.parent?.try &.parent?) && grand_parant.type.list?
        return if grand_parant.data["tight"]
      end

      if entering
        cr
        tag("p", attrs(node))
      else
        tag("p", end_tag: true)
        cr
      end
    end

    def emphasis(node : Node, entering : Bool)
      tag("em", end_tag: !entering)
    end

    def soft_break(node : Node, entering : Bool)
      lit("\n")
    end

    def line_break(node : Node, entering : Bool)
      tag("br", self_closing: true)
      cr
    end

    def strong(node : Node, entering : Bool)
      tag("strong", end_tag: !entering)
    end

    def text(node : Node, entering : Bool)
      out(node.text)
    end

    private def tag(name : String, attrs = nil, self_closing = false, end_tag = false)
      return if @disable_tag > 0

      @output_io << "<"
      @output_io << "/" if end_tag
      @output_io << name
      attrs.try &.each do |key, value|
        @output_io << ' ' << key << '=' << '"' << value << '"'
      end

      @output_io << " /" if self_closing
      @output_io << ">"
      @last_output = ">"
    end

    private def tag(name : String, attrs = nil)
      tag(name, attrs)
      yield
      tag(name, end_tag: true)
    end

    private def potentially_unsafe(url : String)
      url.match(Rule::UNSAFE_PROTOCOL) && !url.match(Rule::UNSAFE_DATA_PROTOCOL)
    end

    private def toc(node : Node)
      return unless node.type.heading?

      title = URI.encode(node.text)

      @output_io << %(<a id="anchor-) << title << %(" class="anchor" href="#) << title %("></a>)
      @last_output = ">"
    end

    private def attrs(node : Node)
      if @options.source_pos && (pos = node.source_pos)
        {"data-source-pos" => "#{pos[0][0]}:#{pos[0][1]}-#{pos[1][0]}:#{pos[1][1]}"}
      else
        nil
      end
    end
  end
end
