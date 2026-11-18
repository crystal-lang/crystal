module Markd::Rule
  struct Table
    include Rule

    # Detects the first row of a table, if the parser is in gfm mode

    def match(parser : Parser, container : Node) : MatchValue
      # Looks like the 1st line of a table and we have gfm enabled
      if parser.gfm? && match?(parser)
        parser.close_unmatched_blocks
        parser.add_child(Node::Type::Table, 0)

        MatchValue::Leaf
      else
        MatchValue::None
      end
    end

    # Decides if the table continues or if it ended before the current line

    def continue(parser : Parser, container : Node) : ContinueStatus
      # Only continue if line looks like a divider or a table row
      if match_continuation?(parser)
        ContinueStatus::Continue
      else
        ContinueStatus::Stop
      end
    end

    # Because of `match` and `continue` the `container` has
    # all the text of the table. We parse it here and
    # insert all `TableRow` and `TableCell` nodes from parsing.
    #
    # First, it will perform a sanity check, and if the
    # table is broken it will be converted into a `Paragraph`

    def token(parser : Parser, container : Node) : Nil
      lines = container.text.strip.split("\n")

      row_sizes = lines[...2].map do |line|
        strip_pipe(line.strip).split(TABLE_CELL_SEPARATOR).size
      end.uniq!

      # Do we have a real table?
      # * At least two lines
      # * Second line is a divider
      # * First two lines have the same number of cells

      if lines.size < 2 || !lines[1].match(TABLE_HEADING_SEPARATOR) ||
         row_sizes.size != 1
        # Not enough table or a broken table.
        # We need to convert it into a paragraph
        # I am fairly sure this is not supposed to work
        container.type = Node::Type::Paragraph
        return
      end

      max_row_size = row_sizes[0]
      has_body = lines.size > 2
      container.data["has_body"] = has_body

      alignments = strip_pipe(lines[1].strip).split(TABLE_CELL_SEPARATOR).map do |cell|
        cell = cell.strip
        if cell.starts_with?(":") && cell.ends_with?(":")
          "center"
        elsif cell.starts_with?(":")
          "left"
        elsif cell.ends_with?(":")
          "right"
        else
          ""
        end
      end

      # Each line maps to a table row
      lines.each_with_index do |line, i|
        next if i == 1
        row = Node.new(Node::Type::TableRow)
        row.data["heading"] = i == 0
        row.data["has_body"] = has_body
        container.append_child(row)
        # This splits on | but not on \| (escaped |)
        cells = strip_pipe(line.strip).split(TABLE_CELL_SEPARATOR)[...max_row_size]

        # Each row should have exactly the same size as the header.
        while cells.size < max_row_size
          cells << ""
        end

        # Create cells with text and metadata
        cells.each_with_index do |text, j|
          cell = Node.new(Node::Type::TableCell)
          # Cell text should be stripped and escaped pipes unescaped
          cell.text = text.strip.gsub("\\|", "|")
          cell.data["align"] = alignments[j]
          cell.data["heading"] = i == 0
          row.append_child(cell)
        end
      end
    end

    # Not really used because of how parsing is done
    def can_contain?(type : Node::Type) : Bool
      !type.container?
    end

    # Tables are multi-line
    def accepts_lines? : Bool
      true
    end

    # Match only lines that look like the first line of a table:
    # * Start with a | or look like multiple cells separated by |
    # * Is at least 3 characters long (smallest table starts are "|a|" or "a|b")

    private def match?(parser)
      !parser.indented && \
         (parser.line[0]? == '|' || parser.line.match(TABLE_CELL_SEPARATOR)) &&
          parser.line.size > 2
    end

    # Match only lines that look like a table separator
    # or start with a | or look like multiple cells separated by |
    private def match_continuation?(parser : Parser)
      !parser.indented && (parser.line[0]? == '|' ||
        parser.line.match(TABLE_HEADING_SEPARATOR) ||
        parser.line.match(TABLE_CELL_SEPARATOR)) ||
        # Lines that are not empty and are not the start of a
        # block-level structure are ALSO continuations (see gfm-spec.txt:3397)
        !(parser.line.strip.empty? || parser.line.matches?(/^(?:>|\#{1,6}|`{3}|\t{1}|\s{4}|(?:[*-+]\s)+|[0-9]+\.)+/))
    end

    private def strip_pipe(text : String) : String
      if text.ends_with?("\\|")
        text.lstrip("|")
      else
        text.strip("|")
      end
    end
  end
end
