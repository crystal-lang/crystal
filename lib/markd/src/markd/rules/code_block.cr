module Markd::Rule
  struct CodeBlock
    include Rule

    CODE_FENCE         = /^`{3,}(?!.*`)|^~{3,}(?!.*~)/
    CLOSING_CODE_FENCE = /^(?:`{3,}|~{3,})(?= *$)/

    def match(parser : Parser, container : Node) : MatchValue
      if !parser.indented &&
         (match = parser.line[parser.next_nonspace..-1].match(CODE_FENCE))
        # fenced
        fence_length = match[0].size

        parser.close_unmatched_blocks
        node = parser.add_child(Node::Type::CodeBlock, parser.next_nonspace)
        node.fenced = true
        node.fence_length = fence_length
        node.fence_char = match[0][0].to_s
        node.fence_offset = parser.indent

        parser.advance_next_nonspace
        parser.advance_offset(fence_length, false)

        MatchValue::Leaf
      elsif parser.indented && !parser.blank && (tip = parser.tip) &&
            !tip.type.paragraph? &&
            (!container.type.list? || container.data["padding"].as(Int32) >= 4)
        # indented
        parser.advance_offset(Rule::CODE_INDENT, true)
        parser.close_unmatched_blocks
        parser.add_child(Node::Type::CodeBlock, parser.offset)

        MatchValue::Leaf
      else
        MatchValue::None
      end
    end

    def continue(parser : Parser, container : Node) : ContinueStatus
      line = parser.line
      indent = parser.indent
      if container.fenced?
        # fenced
        match = indent <= 3 &&
                line[parser.next_nonspace]? == container.fence_char[0] &&
                line[parser.next_nonspace..-1].match(CLOSING_CODE_FENCE)

        if match && match.as(Regex::MatchData)[0].size >= container.fence_length
          # closing fence - we're at end of line, so we can return
          parser.token(container, parser.current_line)
          return ContinueStatus::Return
        else
          # skip optional spaces of fence offset
          index = container.fence_offset
          while index > 0 && space_or_tab?(parser.line[parser.offset]?)
            parser.advance_offset(1, true)
            index -= 1
          end
        end
      else
        # indented
        if indent >= Rule::CODE_INDENT
          parser.advance_offset(Rule::CODE_INDENT, true)
        elsif parser.blank
          parser.advance_next_nonspace
        else
          return ContinueStatus::Stop
        end
      end

      ContinueStatus::Continue
    end

    def token(parser : Parser, container : Node) : Nil
      if container.fenced?
        # fenced
        first_line, _, text = container.text.partition('\n')

        container.fence_language = Utils.decode_entities_string(first_line.strip)
        container.text = text
      else
        # indented
        container.text = container.text.gsub(/(\n *)+$/, "\n")
      end
    end

    def can_contain?(type)
      false
    end

    def accepts_lines? : Bool
      true
    end
  end
end
