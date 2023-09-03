module Markd::Rule
  struct List
    include Rule

    BULLET_LIST_MARKERS  = {'*', '+', '-'}
    ORDERED_LIST_MARKERS = {'.', ')'}

    def match(parser : Parser, container : Node) : MatchValue
      if (!parser.indented || container.type.list?)
        data = parse_list_marker(parser, container)
        return MatchValue::None unless data && !data.empty?

        parser.close_unmatched_blocks
        if !parser.tip.type.list? || !list_match?(container.data, data)
          list_node = parser.add_child(Node::Type::List, parser.next_nonspace)
          list_node.data = data
        end

        item_node = parser.add_child(Node::Type::Item, parser.next_nonspace)
        item_node.data = data

        MatchValue::Container
      else
        MatchValue::None
      end
    end

    def continue(parser : Parser, container : Node) : ContinueStatus
      ContinueStatus::Continue
    end

    def token(parser : Parser, container : Node) : Nil
      item = container.first_child?
      while item
        if ends_with_blankline?(item) && item.next?
          container.data["tight"] = false
          break
        end

        subitem = item.first_child?
        while subitem
          if ends_with_blankline?(subitem) && (item.next? || subitem.next?)
            container.data["tight"] = false
            break
          end

          subitem = subitem.next?
        end

        item = item.next?
      end
    end

    def can_contain?(type)
      type.item?
    end

    def accepts_lines? : Bool
      false
    end

    private def list_match?(list_data, item_data)
      list_data["type"] == item_data["type"] &&
        list_data["delimiter"] == item_data["delimiter"] &&
        list_data["bullet_char"] == item_data["bullet_char"]
    end

    private def parse_list_marker(parser : Parser, container : Node) : Node::DataType
      line = parser.line[parser.next_nonspace..-1]

      empty_data = {} of String => Node::DataValue
      data = {
        "delimiter"     => 0,
        "marker_offset" => parser.indent,
        "bullet_char"   => "",
        "tight"         => true, # lists are tight by default
        "start"         => 1,
      } of String => Node::DataValue

      if BULLET_LIST_MARKERS.includes?(line[0])
        data["type"] = "bullet"
        data["bullet_char"] = line[0].to_s
        first_match_size = 1
      else
        pos = 0
        while line[pos]?.try &.ascii_number?
          pos += 1
        end
        number = pos >= 1 ? line[0..pos - 1].to_i : -1
        if pos >= 1 && pos <= 9 && ORDERED_LIST_MARKERS.includes?(line[pos]?) &&
           (!container.type.paragraph? || number == 1)
          data["type"] = "ordered"
          data["start"] = number
          data["delimiter"] = line[pos].to_s
          first_match_size = pos + 1
        else
          return empty_data
        end
      end

      next_char = parser.line[parser.next_nonspace + first_match_size]?
      unless next_char.nil? || space_or_tab?(next_char)
        return empty_data
      end

      if container.type.paragraph? &&
         parser.line[(parser.next_nonspace + first_match_size)..-1].each_char.all? &.ascii_whitespace?
        return empty_data
      end

      parser.advance_next_nonspace
      parser.advance_offset(first_match_size, true)
      spaces_start_column = parser.column
      spaces_start_offset = parser.offset

      loop do
        parser.advance_offset(1, true)
        next_char = parser.line[parser.offset]?

        break unless parser.column - spaces_start_column < 5 && space_or_tab?(next_char)
      end

      blank_item = parser.line[parser.offset]?.nil?
      spaces_after_marker = parser.column - spaces_start_column
      if spaces_after_marker >= 5 || spaces_after_marker < 1 || blank_item
        data["padding"] = first_match_size + 1
        parser.column = spaces_start_column
        parser.offset = spaces_start_offset

        parser.advance_offset(1, true) if space_or_tab?(parser.line[parser.offset]?)
      else
        data["padding"] = first_match_size + spaces_after_marker
      end

      data
    end

    private def ends_with_blankline?(container : Node) : Bool
      while container
        return true if container.last_line_blank?

        break unless container.type == Node::Type::List || container.type == Node::Type::Item
        container = container.last_child?
      end

      false
    end
  end
end
