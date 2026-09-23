module Markd::Rule
  struct BlockQuote
    include Rule

    def match(parser : Parser, container : Node) : MatchValue
      if match?(parser)
        seek(parser)
        parser.close_unmatched_blocks
        if parser.gfm? && (match = parser.line.match(Rule::ADMONITION_START))
          node = parser.add_child(Node::Type::Alert, parser.next_nonspace)
          # This is an alert
          node.data["alert"] = match[1]
          node.data["title"] = (match[2]? && !match[2].strip.empty?) ? match[2].strip : match[1]
          parser.advance_offset(parser.line.size, false)
        else
          parser.add_child(Node::Type::BlockQuote, parser.next_nonspace)
        end

        MatchValue::Container
      else
        MatchValue::None
      end
    end

    def continue(parser : Parser, container : Node) : ContinueStatus
      if match?(parser)
        seek(parser)
        ContinueStatus::Continue
      else
        ContinueStatus::Stop
      end
    end

    def token(parser : Parser, container : Node) : Nil
      # do nothing
    end

    def can_contain?(type : Node::Type) : Bool
      !type.item?
    end

    def accepts_lines? : Bool
      false
    end

    private def match?(parser)
      !parser.indented && parser.line[parser.next_nonspace]? == '>'
    end

    private def seek(parser : Parser)
      parser.advance_next_nonspace
      parser.advance_offset(1, false)

      if space_or_tab?(parser.line[parser.offset]?)
        parser.advance_offset(1, true)
      end
    end
  end
end
