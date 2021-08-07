module Markd::Parser
  class Block
    include Parser

    def self.parse(source : String, options = Options.new)
      new(options).parse(source)
    end

    RULES = {
      Node::Type::Document      => Rule::Document.new,
      Node::Type::BlockQuote    => Rule::BlockQuote.new,
      Node::Type::Heading       => Rule::Heading.new,
      Node::Type::CodeBlock     => Rule::CodeBlock.new,
      Node::Type::HTMLBlock     => Rule::HTMLBlock.new,
      Node::Type::ThematicBreak => Rule::ThematicBreak.new,
      Node::Type::List          => Rule::List.new,
      Node::Type::Item          => Rule::Item.new,
      Node::Type::Paragraph     => Rule::Paragraph.new,
    }

    property! tip : Node?
    property offset, column

    getter line, current_line, blank, inline_lexer,
      indent, indented, next_nonspace, refmap

    def initialize(@options : Options)
      @inline_lexer = Inline.new(@options)

      @document = Node.new(Node::Type::Document)
      @tip = @document
      @oldtip = @tip
      @last_matched_container = @tip

      @line = ""

      @current_line = 0
      @offset = 0
      @column = 0
      @last_line_length = 0

      @next_nonspace = 0
      @next_nonspace_column = 0

      @indent = 0
      @indented = false
      @blank = false
      @partially_consumed_tab = false
      @all_closed = true
      @refmap = {} of String => Hash(String, String) | String
    end

    def parse(source : String)
      Utils.timer("block parsing", @options.time) do
        parse_blocks(source)
      end

      Utils.timer("inline parsing", @options.time) do
        process_inlines
      end

      @document
    end

    private def parse_blocks(source)
      lines_size = 0
      source.each_line do |line|
        process_line(line)
        lines_size += 1
      end

      # ignore last blank line created by final newline
      lines_size -= 1 if source.ends_with?('\n')

      while tip = tip?
        token(tip, lines_size)
      end
    end

    private def process_line(line : String)
      container = @document
      @oldtip = tip
      @offset = 0
      @column = 0
      @blank = false
      @partially_consumed_tab = false
      @current_line += 1

      line = line.gsub(Char::ZERO, '\u{FFFD}')
      @line = line

      while (last_child = container.last_child?) && last_child.open?
        container = last_child

        find_next_nonspace

        case RULES[container.type].continue(self, container)
        when Rule::ContinueStatus::Continue
          # we've matched, keep going
        when Rule::ContinueStatus::Stop
          # we've failed to match a block
          # back up to last matching block
          container = container.parent
          break
        when Rule::ContinueStatus::Return
          # we've hit end of line for fenced code close and can return
          @last_line_length = line.size
          return
        end
      end

      @all_closed = (container == @oldtip)
      @last_matched_container = container

      matched_leaf = !container.type.paragraph? && RULES[container.type].accepts_lines?

      while !matched_leaf
        find_next_nonspace

        # this is a little performance optimization
        unless @indented
          first_char = @line[@next_nonspace]?
          unless first_char && (Rule::MAYBE_SPECIAL.includes?(first_char) || first_char.ascii_number?)
            advance_next_nonspace
            break
          end
        end

        matched = RULES.each_value do |rule|
          case rule.match(self, container)
          when Rule::MatchValue::Container
            container = tip
            break true
          when Rule::MatchValue::Leaf
            container = tip
            matched_leaf = true
            break true
          else
            false
          end
        end

        # nothing matched
        unless matched
          advance_next_nonspace
          break
        end
      end

      if !@all_closed && !@blank && tip.type.paragraph?
        # lazy paragraph continuation
        add_line
      else
        # not a lazy continuation
        close_unmatched_blocks
        if @blank && (last_child = container.last_child?)
          last_child.last_line_blank = true
        end

        container_type = container.type
        last_line_blank = @blank &&
                          !(container_type.block_quote? ||
                            (container_type.code_block? && container.fenced?) ||
                            (container_type.item? && !container.first_child? && container.source_pos[0][0] == @current_line))

        cont = container
        while cont
          cont.last_line_blank = last_line_blank
          cont = cont.parent?
        end

        if RULES[container_type].accepts_lines?
          add_line

          # if HtmlBlock, check for end condition
          if (container_type.html_block? && match_html_block?(container))
            token(container, @current_line)
          end
        elsif @offset < line.size && !@blank
          # create paragraph container for line
          add_child(Node::Type::Paragraph, @offset)
          advance_next_nonspace
          add_line
        end

        @last_line_length = line.size
      end

      nil
    end

    private def process_inlines
      walker = @document.walker
      @inline_lexer.refmap = @refmap
      while (event = walker.next)
        node, entering = event
        if !entering && (node.type.paragraph? || node.type.heading?)
          @inline_lexer.parse(node)
        end
      end

      nil
    end

    def token(container : Node, line_number : Int32)
      container_parent = container.parent?

      container.open = false
      container.source_pos = {
        container.source_pos[0],
        {line_number, @last_line_length},
      }
      RULES[container.type].token(self, container)

      @tip = container_parent

      nil
    end

    private def add_line
      if @partially_consumed_tab
        @offset += 1 # skip over tab
        # add space characters
        chars_to_tab = Rule::CODE_INDENT - (@column % 4)
        tip.text += " " * chars_to_tab
      end

      tip.text += @line[@offset..-1] + "\n"

      nil
    end

    def add_child(type : Node::Type, offset : Int32) : Node
      while !RULES[tip.type].can_contain?(type)
        token(tip, @current_line - 1)
      end

      column_number = offset + 1 # offset 0 = column 1

      node = Node.new(type)
      node.source_pos = { {@current_line, column_number}, {0, 0} }
      node.text = ""
      tip.append_child(node)
      @tip = node

      node
    end

    def close_unmatched_blocks
      unless @all_closed
        while (oldtip = @oldtip) && oldtip != @last_matched_container
          parent = oldtip.parent?
          token(oldtip, @current_line - 1)
          @oldtip = parent
        end
        @all_closed = true
      end
      nil
    end

    private def find_next_nonspace
      offset = @offset
      column = @column

      if @line.empty?
        @blank = true
      else
        while char = @line[offset]?
          case char
          when ' '
            offset += 1
            column += 1
          when '\t'
            offset += 1
            column += (4 - (column % 4))
          else
            break
          end
        end

        @blank = {nil, '\n', '\r'}.includes?(char)
      end

      @next_nonspace = offset
      @next_nonspace_column = column
      @indent = @next_nonspace_column - @column
      @indented = @indent >= Rule::CODE_INDENT

      nil
    end

    def advance_offset(count, columns = false)
      line = @line
      while count > 0 && (char = line[@offset]?)
        if char == '\t'
          chars_to_tab = Rule::CODE_INDENT - (@column % 4)
          if columns
            @partially_consumed_tab = chars_to_tab > count
            chars_to_advance = chars_to_tab > count ? count : chars_to_tab
            @column += chars_to_advance
            @offset += @partially_consumed_tab ? 0 : 1
            count -= chars_to_advance
          else
            @partially_consumed_tab = false
            @column += chars_to_tab
            @offset += 1
            count -= 1
          end
        else
          @partially_consumed_tab = false
          @column += 1 # assume ascii; block starts are ascii
          @offset += 1
          count -= 1
        end
      end

      nil
    end

    def advance_next_nonspace
      @offset = @next_nonspace
      @column - @next_nonspace_column
      @partially_consumed_tab = false

      nil
    end

    private def match_html_block?(container : Node)
      if block_type = container.data["html_block_type"]
        block_type = block_type.as(Int32)
        block_type >= 0 && block_type <= 4 && Rule::HTML_BLOCK_CLOSE[block_type].match(@line[@offset..-1])
      else
        false
      end
    end
  end
end
