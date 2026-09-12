module Markd
  abstract class Renderer
    def initialize(@options = Options.new)
      @output_io = String::Builder.new
      @last_output = "\n"
    end

    def output(string : String)
      literal(escape(string))
    end

    def literal(string : String)
      @output_io << string
      @last_output = string
    end

    # render a Line Feed character
    def newline
      literal("\n") if @last_output != "\n"
    end

    private ESCAPES = {
      '&' => "&amp;",
      '"' => "&quot;",
      '<' => "&lt;",
      '>' => "&gt;",
    }

    def escape(text)
      # If we can determine that the text has no escape chars
      # then we can return the text as is, avoiding an allocation
      # and a lot of processing in `String#gsub`.
      if has_escape_char?(text)
        text.gsub(ESCAPES)
      else
        text
      end
    end

    private def has_escape_char?(text)
      text.each_byte do |byte|
        case byte
        when '&', '"', '<', '>'
          return true
        else
          next
        end
      end
      false
    end

    abstract def heading(node : Node, entering : Bool) : Nil
    abstract def list(node : Node, entering : Bool) : Nil
    abstract def item(node : Node, entering : Bool) : Nil
    abstract def block_quote(node : Node, entering : Bool) : Nil
    abstract def alert(node : Node, entering : Bool) : Nil
    abstract def thematic_break(node : Node, entering : Bool) : Nil
    abstract def code_block(node : Node, entering : Bool, formatter : T?) : Nil forall T
    abstract def code(node : Node, entering : Bool) : Nil
    abstract def html_block(node : Node, entering : Bool) : Nil
    abstract def html_inline(node : Node, entering : Bool) : Nil
    abstract def paragraph(node : Node, entering : Bool) : Nil
    abstract def emphasis(node : Node, entering : Bool) : Nil
    abstract def soft_break(node : Node, entering : Bool) : Nil
    abstract def line_break(node : Node, entering : Bool) : Nil
    abstract def strong(node : Node, entering : Bool) : Nil
    abstract def strikethrough(node : Node, entering : Bool) : Nil
    abstract def link(node : Node, entering : Bool) : Nil
    abstract def image(node : Node, entering : Bool) : Nil
    abstract def text(node : Node, entering : Bool) : Nil
    abstract def table(node : Node, entering : Bool) : Nil
    abstract def table_row(node : Node, entering : Bool) : Nil
    abstract def table_cell(node : Node, entering : Bool) : Nil

    def render(document : Node, formatter : T?) forall T
      Utils.timer("rendering", @options.time?) do
        walker = document.walker
        while (event = walker.next)
          node, entering = event

          case node.type
          when Node::Type::Heading
            heading(node, entering)
          when Node::Type::List
            list(node, entering)
          when Node::Type::Item
            item(node, entering)
          when Node::Type::BlockQuote
            block_quote(node, entering)
          when Node::Type::Alert
            alert(node, entering)
          when Node::Type::ThematicBreak
            thematic_break(node, entering)
          when Node::Type::CodeBlock
            code_block(node, entering, formatter)
          when Node::Type::Code
            code(node, entering)
          when Node::Type::HTMLBlock
            html_block(node, entering)
          when Node::Type::HTMLInline
            html_inline(node, entering)
          when Node::Type::Paragraph
            paragraph(node, entering)
          when Node::Type::Emphasis
            emphasis(node, entering)
          when Node::Type::SoftBreak
            soft_break(node, entering)
          when Node::Type::LineBreak
            line_break(node, entering)
          when Node::Type::Strong
            strong(node, entering)
          when Node::Type::Strikethrough
            strikethrough(node, entering)
          when Node::Type::Link
            link(node, entering)
          when Node::Type::Image
            image(node, entering)
          when Node::Type::Table
            table(node, entering)
          when Node::Type::TableRow
            table_row(node, entering)
          when Node::Type::TableCell
            table_cell(node, entering)
          else
            text(node, entering)
          end
        end
      end

      @output_io.to_s.sub("\n", "")
    end
  end
end

require "./renderers/*"
