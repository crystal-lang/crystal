module Markd::Rule
  struct HTMLBlock
    include Rule

    def match(parser : Parser, container : Node) : MatchValue
      if !parser.indented && parser.line[parser.next_nonspace]? == '<'
        text = parser.line[parser.next_nonspace..-1]
        block_type_size = Rule::HTML_BLOCK_OPEN.size - 1

        Rule::HTML_BLOCK_OPEN.each_with_index do |regex, index|
          if text.match(regex) &&
             (index < block_type_size || !container.type.paragraph?)
            parser.close_unmatched_blocks
            # We don't adjust parser.offset;
            # spaces are part of the HTML block:
            node = parser.add_child(Node::Type::HTMLBlock, parser.offset)
            node.data["html_block_type"] = index

            return MatchValue::Leaf
          end
        end
      end

      MatchValue::None
    end

    def continue(parser : Parser, container : Node) : ContinueStatus
      (parser.blank && {5, 6}.includes?(container.data["html_block_type"])) ? ContinueStatus::Stop : ContinueStatus::Continue
    end

    def token(parser : Parser, container : Node) : Nil
      text = container.text.gsub(/(\n *)+$/, "")

      if parser.tagfilter?
        text = self.class.escape_disallowed_html(text)
      end

      container.text = text
    end

    def can_contain?(type)
      false
    end

    def accepts_lines? : Bool
      true
    end

    def self.escape_disallowed_html(text : String) : String
      String.build do |string|
        pos = 0

        text.scan(/<\/?\s*(#{GFM_DISALLOWED_HTML_TAGS.join('|')})\b/i) do |match|
          start = text.index(match[0], pos)
          next if start.nil?

          string << text[pos...start] << "&lt;#{match[0][1..]}"
          pos = start + match[0].size
        end

        string << text[pos..-1]
      end
    end
  end
end
