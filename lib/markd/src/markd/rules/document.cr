module Markd::Rule
  struct Document
    include Rule

    def match(parser : Parser, container : Node) : MatchValue
      MatchValue::None
    end

    def continue(parser : Parser, container : Node) : ContinueStatus
      ContinueStatus::Continue
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
  end
end
