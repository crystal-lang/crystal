require "../syntax/ast"
require "../syntax/to_s"

class Crystal::Browser
  def self.open(node)
    browser = Browser.new(node)
    server, port = create_server
    puts "Browser open at http://0.0.0.0:#{port}"
    ifdef darwin
      system "open http://localhost:#{port}"
    end
    while true
      server.accept do |sock|
        if request = HTTP::Request.from_io(sock)
          html = browser.handle(request.path)

          response = HTTP::Response.new(200, html, HTTP::Headers{"Content-Type": "text/html"})
          response.to_io sock
        end
      end
    end
  end

  private def self.create_server(port = 4000)
    {TCPServer.new(port), port}
  rescue
    create_server(port + 1)
  end

  def initialize(@node)
    @nodes = {} of typeof(object_id) => ASTNode
  end

  def handle(path)
    object_id = path[1 .. -1].to_u64 { 0_u64 }
    case object_id
    when 0
      render_html @node
    else
      node = @nodes[object_id]?
      if node
        render_html node
      else
        "Undefined node: #{object_id}"
      end
    end
  end

  def render_html(node : Def)
    render_html do
      String.build do |str|
        str << "<h2>"
        owner = node.owner?
        if owner && !owner.is_a?(Program)
          if owner.metaclass?
            str << "<span class=\"path\">#{owner.instance_type}</span>::"
          else
            str << "<span class=\"path\">#{owner}</span>#"
          end
        end
        str << "<span class=\"def-name\">#{node.name}</span>"
        str << "</h2>"
        if node_type = node.type?
          node.return_type = TypeNode.new(node_type)
        end
        str << to_html(node)
      end
    end
  end

  def render_html(node : Call)
    render_html do
      String.build do |str|
        str << "<h2>"
        str << "Dispatch: "
        str << to_html(node)
        str << "</h2>"
        str << "<ul>"
        node.target_defs.not_nil!.each do |target_def|
          register target_def
          str << "<li>"
          str << "<span class=\"keyword\">def</span> "
          str << "<a href=\"#{target_def.object_id}\">#{target_def.name}</a>"
          str << "("
          target_def.args.each do |arg|
            str << to_html(arg)
          end
          str << ")"
          str << "</li>"
        end
        str << "</ul>"
      end
    end
  end

  def render_html(node : ASTNode)
    render_html { to_html(node) }
  end

  def render_html
    %(
    <html>
      <head>
        <style>
          body {
            font-family: "Lucida Sans", "Lucida Grande", Verdana, Arial, sans-serif;
            background-color: #f7f7f7;
            color: #333;
            font-size: 14px;
          }
          .singleton {
            color: #0086b3;
          }
          .symbol {
            color: #0086b3;
          }
          .keyword {
            color: #a71d5d;
          }
          .def-name {
            color: #795da3;
          }
          .char {
            color: #183691;
          }
          .string {
            color: #183691;
          }
          .regex {
            color: #183691;
          }
          .path {
            color: #0086b3;
          }
          .comment {
            color: #969896;
          }
        </style>
      </head>
      <body><code>
        #{yield}
      <code></body>
    </html>
    )
  end

  def to_html(node)
    visitor = ToHtmlVisitor.new(self)
    node.accept visitor
    visitor.to_s
  end

  def register(node)
    @nodes[node.object_id] ||= node
  end

  class ToHtmlVisitor < ToSVisitor
    def initialize(@browser)
      super(StringIO.new)
    end

    def visit(node : LibDef)
      false
    end

    def visit(node : ClassDef)
      false
    end

    def visit(node : ModuleDef)
      false
    end

    def visit(node : Attribute)
      false
    end

    def visit(node : NumberLiteral)
      @str << "<span class=\"singleton\""
      if type = node.type?
        @str << " title=\"#{type}\""
      end
      @str << ">"
      super(node)
      @str << "</span>"
    end

    def visit(node : CharLiteral)
      @str << "<span class=\"char\""
      if type = node.type?
        @str << " title=\"#{type}\""
      end
      @str << ">"
      super(node)
      @str << "</span>"
    end

    def visit(node : StringLiteral)
      @str << "<span class=\"string\""
      if type = node.type?
        @str << " title=\"#{type}\""
      end
      @str << ">"
      super(node)
      @str << "</span>"
    end

    def visit(node : RegexLiteral)
      @str << "<span class=\"regex\""
      if type = node.type?
        @str << " title=\"#{type}\""
      end
      @str << ">"
      super(node)
      @str << "</span>"
    end

    def visit(node : SymbolLiteral)
      @str << "<span class=\"symbol\""
      if type = node.type?
        @str << " title=\"#{type}\""
      end
      @str << ">"
      super(node)
      @str << "</span>"
    end

    def visit(node : Path)
      @str << "<span class=\"path\">"
      super(node)
      @str << "</span>"
    end

    def visit(node : Require)
      @str << keyword("require")
      @str << " "
      @str << "<span class=\"string\">"
      @str << "\""
      @str << node.string
      @str << "\""
      @str << "</span>"
      false
    end

    def visit(node : TypeNode)
      @str << "<span class=\"path\">"
      node.type.to_s(@str)
      @str << "</span>"
      false
    end

    def visit(node : Primitive)
      @str << "<span class=\"comment\"># primitive: #{node.name}</span>"
    end

    def call_needs_parens(node)
      node.args.length > 0 || node.block_arg
    end

    def decorate_var(node, str)
      if type = node.type?
        "<a title=\"#{type}\">#{str}</a>"
      else
        str
      end
    end

    def decorate_arg(node, str)
      decorate_var node, str
    end

    def decorate_instance_var(node, str)
      if type = node.type?
        "<a title=\"#{type}\">#{str}</a>"
      else
        str
      end
    end

    def decorate_class_var(node, str)
      if type = node.type?
        "<a title=\"#{type}\">#{str}</a>"
      else
        str
      end
    end

    def decorate_call(node, str)
      target_defs = node.target_defs
      if target_defs
        case target_defs.length
        when 0
          str
        when 1
          target_def = target_defs.first
          @browser.register target_def
          "<a href=\"/#{target_def.object_id}\" title=\"#{node.type?}\">#{str}</a>"
        else
          @browser.register node
          "<a href=\"/#{node.object_id}\" title=\"#{node.type?}\">#{str}</a>"
        end
      else
        str
      end
    end

    def keyword(str)
      span_with_class str, "keyword"
    end

    def def_name(str)
      span_with_class str, "def-name"
    end

    def decorate_singleton(node, str)
      span_with_class str, "singleton"
    end

    def span_with_class(str, klass)
      "<span class=\"#{klass}\">#{str}</span>"
    end

    def newline
      str = @str
      return if str.is_a?(StringIO) && str.empty?
      str << "<br/>"
    end

    def indent_string
      "&nbsp;&nbsp;"
    end
  end
end
