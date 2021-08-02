require "uri"

module Markd
  class HTMLRenderer < Renderer
    @disable_tag = 0
    @last_output = "\n"

    HEADINGS = %w(h1 h2 h3 h4 h5 h6)

    def heading(node : Node, entering : Bool)
      tag_name = HEADINGS[node.data["level"].as(Int32) - 1]
      if entering
        newline
        tag(tag_name, attrs(node))
        # toc(node) if @options.toc
      else
        tag(tag_name, end_tag: true)
        newline
      end
    end

    def code(node : Node, entering : Bool)
      tag("code") do
        output(node.text)
      end
    end

    def code_block(node : Node, entering : Bool)
      languages = node.fence_language ? node.fence_language.split : nil
      code_tag_attrs = attrs(node)
      pre_tag_attrs = if @options.prettyprint
                        {"class" => "prettyprint"}
                      else
                        nil
                      end

      if languages && languages.size > 0 && (lang = languages[0]) && !lang.empty?
        code_tag_attrs ||= {} of String => String
        code_tag_attrs["class"] = "language-#{escape(lang.strip)}"
      end

      newline
      tag("pre", pre_tag_attrs) do
        tag("code", code_tag_attrs) do
          output(node.text)
        end
      end
      newline
    end

    def thematic_break(node : Node, entering : Bool)
      newline
      tag("hr", attrs(node), self_closing: true)
      newline
    end

    def block_quote(node : Node, entering : Bool)
      newline
      if entering
        tag("blockquote", attrs(node))
      else
        tag("blockquote", end_tag: true)
      end
      newline
    end

    def list(node : Node, entering : Bool)
      tag_name = node.data["type"] == "bullet" ? "ul" : "ol"

      newline
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
      newline
    end

    def item(node : Node, entering : Bool)
      if entering
        tag("li", attrs(node))
      else
        tag("li", end_tag: true)
        newline
      end
    end

    def link(node : Node, entering : Bool)
      if entering
        attrs = attrs(node)
        destination = node.data["destination"].as(String)

        unless @options.safe && potentially_unsafe(destination)
          attrs ||= {} of String => String
          destination = resolve_uri(destination, node)
          attrs["href"] = escape(destination)
        end

        if (title = node.data["title"].as(String)) && !title.empty?
          attrs ||= {} of String => String
          attrs["title"] = escape(title)
        end

        tag("a", attrs)
      else
        tag("a", end_tag: true)
      end
    end

    private def resolve_uri(destination, node)
      base_url = @options.base_url
      return destination unless base_url

      uri = URI.parse(destination)
      return destination if uri.absolute?

      base_url.resolve(uri).to_s
    end

    def image(node : Node, entering : Bool)
      if entering
        if @disable_tag == 0
          destination = node.data["destination"].as(String)
          if @options.safe && potentially_unsafe(destination)
            literal(%(<img src="" alt=""))
          else
            destination = resolve_uri(destination, node)
            literal(%(<img src="#{escape(destination)}" alt="))
          end
        end
        @disable_tag += 1
      else
        @disable_tag -= 1
        if @disable_tag == 0
          if (title = node.data["title"].as(String)) && !title.empty?
            literal(%(" title="#{escape(title)}))
          end
          literal(%(" />))
        end
      end
    end

    def html_block(node : Node, entering : Bool)
      newline
      content = @options.safe ? "<!-- raw HTML omitted -->" : node.text
      literal(content)
      newline
    end

    def html_inline(node : Node, entering : Bool)
      content = @options.safe ? "<!-- raw HTML omitted -->" : node.text
      literal(content)
    end

    def paragraph(node : Node, entering : Bool)
      if (grand_parant = node.parent?.try &.parent?) && grand_parant.type.list?
        return if grand_parant.data["tight"]
      end

      if entering
        newline
        tag("p", attrs(node))
      else
        tag("p", end_tag: true)
        newline
      end
    end

    def emphasis(node : Node, entering : Bool)
      tag("em", end_tag: !entering)
    end

    def soft_break(node : Node, entering : Bool)
      literal("\n")
    end

    def line_break(node : Node, entering : Bool)
      tag("br", self_closing: true)
      newline
    end

    def strong(node : Node, entering : Bool)
      tag("strong", end_tag: !entering)
    end

    def text(node : Node, entering : Bool)
      output(node.text)
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
