module Markd::Rule
  struct Item
    include Rule

    def match(parser : Parser, container : Node) : MatchValue
      # match and parse in Rule::List
      MatchValue::None
    end

    def continue(parser : Parser, container : Node) : ContinueStatus
      indent_offset = container.data["marker_offset"].as(Int32) + container.data["padding"].as(Int32)

      if parser.blank
        if container.first_child?
          parser.advance_next_nonspace
        else
          # Blank line after empty list item
          return ContinueStatus::Stop
        end
      elsif parser.indent >= indent_offset
        parser.advance_offset(indent_offset, true)
      else
        return ContinueStatus::Stop
      end

      ContinueStatus::Continue
    end

    def token(parser : Parser, container : Node) : Nil
      # do nothing
    end

    def can_contain?(type : Node::Type)
      !type.item?
    end

    def accepts_lines? : Bool
      false
    end
  end
end
