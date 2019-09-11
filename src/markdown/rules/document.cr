module Markdown::Rule
  # :nodoc:
  struct Document
    include Rule

    def match(parser : Parser, container : Node)
      MatchValue::None
    end

    def continue(parser : Parser, container : Node)
      ContinueStatus::Continue
    end

    def token(parser : Parser, container : Node)
      # do nothing
    end

    def can_contain?(type : Node::Type) : Bool
      !type.item?
    end

    def accepts_lines?
      false
    end
  end
end
