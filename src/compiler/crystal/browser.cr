require "to_s"

class Crystal::Browser
  def initialize(@node)
    @nodes = {} of typeof(object_id) => ASTNode
  end

  def handle(path)
    object_id = path[1 .. -1].to_u64
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
        owner = node.owner
        if owner && !owner.is_a?(Program)
          if owner.metaclass?
            str << "<span class=\"path\">#{owner.instance_type}</span>::"
          else
            str << "<span class=\"path\">#{owner}</span>#"
          end
        end
        str << "<span class=\"def-name\">#{node.name}</span>"
        str << "</h2>"
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
    "
    <html>
      <head>
        <style>
          @import url('http://fonts.googleapis.com/css?family=Open+Sans:400,700,300');
          @import url('http://fonts.googleapis.com/css?family=Cousine:400,700');
          body {
            font-weight: bold;
            font-family: 'Cousine', sans-serif;
            background-color: #E5E5E5;
          }
          .singleton {
            color: #7644E4;
          }
          .symbol {
            color: #7644E4;
          }
          .keyword {
            color: #C7285E;
          }
          .def-name {
            color: #41822D;
          }
          .instance-var {
            color: #5F868F;
          }
          .class-var {
            color: #5F868F;
          }
          .char {
            color: #728B14;
          }
          .string {
            color: #728B14;
          }
          .regex {
            color: #728B14;
          }
          .path {
            color: #5F868F;
          }
          .comment {
            color: #8C8C8C;
          }
        </style>
      </head>
      <body>
        #{yield}
      </body>
    </html>
    "
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
      super(StringBuilder.new)
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
        "<a title=\"#{type}\" class=\"instance-var\">#{str}</a>"
      else
        span_with_class str, "instance-var"
      end
    end

    def decorate_class_var(node, str)
      if type = node.type?
        "<a title=\"#{type}\" class=\"class-var\">#{str}</a>"
      else
        span_with_class str, "class-var"
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
      "<br/>"
    end

    def indent_string
      "&nbsp;&nbsp;"
    end
  end
end
