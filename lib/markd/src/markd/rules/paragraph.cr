module Markd::Rule
  struct Paragraph
    include Rule

    def match(parser : Parser, container : Node) : MatchValue
      MatchValue::None
    end

    def continue(parser : Parser, container : Node) : ContinueStatus
      parser.blank ? ContinueStatus::Stop : ContinueStatus::Continue
    end

    def token(parser : Parser, container : Node) : Nil
      has_reference_defs = false

      while container.text[0]? == '[' &&
            (pos = parser.inline_lexer.reference(container.text, parser.refmap)) && pos > 0
        container.text = container.text.byte_slice(pos)
        has_reference_defs = true
      end

      container.unlink if has_reference_defs && container.text.each_char.all? &.ascii_whitespace?
    end

    def can_contain?(type)
      false
    end

    def accepts_lines? : Bool
      true
    end
  end
end
