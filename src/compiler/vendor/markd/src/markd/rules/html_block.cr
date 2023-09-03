module Markd::Rule
  struct HTMLBlock
    include Rule

    def match(parser : Parser, container : Node) : MatchValue
      if !parser.indented && parser.line[parser.next_nonspace]? == '<'
        text = parser.line[parser.next_nonspace..-1]
        block_type_size = Rule::HTML_BLOCK_OPEN.size - 1

        Rule::HTML_BLOCK_OPEN.each_with_index do |regex, index|
          if (text.match(regex) &&
             (index < block_type_size || !container.type.paragraph?))
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
      container.text = container.text.gsub(/(\n *)+$/, "")
    end

    def can_contain?(type)
      false
    end

    def accepts_lines? : Bool
      true
    end
  end
end
