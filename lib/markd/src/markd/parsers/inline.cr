require "html"
require "uri"

module Markd::Parser
  class Inline
    include Parser

    property refmap
    private getter! brackets

    @delimiters : Delimiter?

    def initialize(@options : Options)
      @text = ""
      @pos = 0
      @refmap = {} of String => Hash(String, String) | String
    end

    def parse(node : Node)
      @pos = 0
      @delimiters = nil
      @text = node.text.strip

      loop do
        break unless process_line(node)
      end

      node.text = ""
      process_delimiters(nil)
    end

    private def process_line(node : Node)
      char = char_at?(@pos)
      return false unless char && char != Char::ZERO

      res = case char
            when '\n'
              newline(node)
            when '\\'
              backslash(node)
            when '`'
              backtick(node)
            when '*', '_'
              handle_delim(char, node)
            when '~'
              if @options.gfm?
                handle_delim(char, node)
              else
                string(node)
              end
            when '\'', '"'
              @options.smart? && handle_delim(char, node)
            when '['
              open_bracket(node)
            when '!'
              bang(node)
            when ']'
              close_bracket(node)
            when '<'
              auto_link(node) || html_tag(node)
            when 'w'
              # Catch www. autolinks for GFM
              # Do not match if it's http://www
              if @options.autolink? && (@pos == 0 || char_at?(@pos - 1) != '/')
                auto_link(node)
              else
                false
              end
            when 'h'
              # Catch http:// and https:// autolinks for GFM
              # Do not match ![http:// ... because that was matched by '!']
              if @options.autolink? && (@pos == 0 || char_at?(@pos - 1) != '[')
                auto_link(node)
              else
                false
              end
            when 'f'
              # Catch ftp:// autolinks for GFM
              # Do not match if it's <ftp:// ... because that was matched by '<'
              if @options.autolink? && (@pos == 0 || char_at?(@pos - 1) != '<')
                auto_link(node)
              else
                false
              end
            when 'x'
              # Catch xmpp: autolinks for GFM
              if @options.autolink? && (@pos == 0 || char_at?(@pos - 1) != '<')
                auto_link(node)
              else
                false
              end
            when 'm'
              # Catch mailto: autolinks for GFM
              if @options.autolink? && (@pos == 0 || char_at?(@pos - 1) != '<')
                auto_link(node)
              else
                false
              end
            when '&'
              entity(node)
            when ':'
              emoji(node)
            else
              if @options.autolink? && node.text.includes? '@'
                # Catch email autolinks for GFM
                auto_link(node)
              else
                string(node)
              end
            end

      unless res
        @pos += 1
        node.append_child(text(char))
      end

      true
    end

    private def newline(node : Node)
      @pos += 1 # assume we're at a \n
      last_child = node.last_child?
      # check previous node for trailing spaces
      if last_child && last_child.type.text? &&
         last_child.text.ends_with?(' ')
        hard_break = if last_child.text.size == 1
                       false # Must be space
                     else
                       last_child.text[-2]? == ' '
                     end
        last_child.text = last_child.text.rstrip ' '
        node.append_child(Node.new(hard_break ? Node::Type::LineBreak : Node::Type::SoftBreak))
      else
        node.append_child(Node.new(Node::Type::SoftBreak))
      end

      # gobble leading spaces in next line
      while char_at?(@pos) == ' '
        @pos += 1
      end

      true
    end

    private def backslash(node : Node)
      @pos += 1

      char = @pos < @text.bytesize ? char_at(@pos).to_s : nil
      child = if char_at?(@pos) == '\n'
                @pos += 1
                Node.new(Node::Type::LineBreak)
              elsif char && char.match(Rule::ESCAPABLE)
                c = text(char)
                @pos += 1
                c
              else
                text("\\")
              end

      node.append_child(child)

      true
    end

    private def backtick(node : Node)
      start_pos = @pos
      while char_at?(@pos) == '`'
        @pos += 1
      end
      return false if start_pos == @pos

      num_ticks = @pos - start_pos
      after_open_ticks = @pos
      while (text = match(Rule::TICKS))
        if text.bytesize == num_ticks
          child = Node.new(Node::Type::Code)
          child_text = @text.byte_slice(after_open_ticks, (@pos - num_ticks) - after_open_ticks).gsub(Rule::LINE_ENDING, " ")
          if child_text.bytesize >= 2 && child_text[0] == ' ' && child_text[-1] == ' ' && child_text.matches?(/[^ ]/)
            child_text = child_text.byte_slice(1, child_text.bytesize - 2)
          end
          child.text = child_text
          node.append_child(child)

          return true
        end
      end

      @pos = after_open_ticks
      node.append_child(text("`" * num_ticks))

      true
    end

    private def bang(node : Node)
      start_pos = @pos
      @pos += 1
      if char_at?(@pos) == '['
        @pos += 1
        child = text("![")
        node.append_child(child)

        add_bracket(child, start_pos + 1, true)
      else
        node.append_child(text("!"))
      end

      true
    end

    private def add_bracket(node : Node, index : Int32, image = false)
      brackets.bracket_after = true if brackets?
      @brackets = Bracket.new(node, @brackets, @delimiters, index, image, true)
    end

    private def remove_bracket
      @brackets = brackets.previous?
    end

    private def open_bracket(node : Node)
      start_pos = @pos
      @pos += 1

      child = text("[")
      node.append_child(child)

      add_bracket(child, start_pos, false)

      true
    end

    private def close_bracket(node : Node)
      title = ""
      dest = ""
      matched = false
      @pos += 1
      start_pos = @pos

      # get last [ or ![
      opener = @brackets
      unless opener
        # no matched opener, just return a literal
        node.append_child(text("]"))
        return true
      end

      unless opener.active?
        # no matched opener, just return a literal
        node.append_child(text("]"))
        # take opener off brackets stack
        remove_bracket
        return true
      end

      # If we got here, open is a potential opener
      is_image = opener.image?

      # Check to see if we have a link/image
      save_pos = @pos

      # Inline link?
      if char_at?(@pos) == '('
        @pos += 1
        if spnl && (dest = link_destination) &&
           spnl && (char_at?(@pos - 1).try(&.whitespace?) &&
           (title = link_title) || true) && spnl &&
           char_at?(@pos) == ')'
          @pos += 1
          matched = true
        else
          @pos = save_pos
        end
      end

      ref_label = nil
      unless matched
        # Next, see if there's a link label
        before_label = @pos
        label_size = link_label
        if label_size > 2
          ref_label = normalize_reference(@text.byte_slice(before_label, label_size + 1))
        elsif !opener.bracket_after?
          # Empty or missing second label means to use the first label as the reference.
          # The reference must not contain a bracket. If we know there's a bracket, we don't even bother checking it.
          byte_count = start_pos - opener.index
          ref_label = byte_count > 0 ? normalize_reference(@text.byte_slice(opener.index, byte_count)) : nil
        end

        if label_size == 0
          # If shortcut reference link, rewind before spaces we skipped.
          @pos = save_pos
        end

        if ref_label && @refmap[ref_label]?
          # lookup rawlabel in refmap
          link = @refmap[ref_label].as(Hash)
          dest = link["destination"] if link["destination"]
          title = link["title"] if link["title"]
          matched = true
        end
      end

      if matched
        child = Node.new(is_image ? Node::Type::Image : Node::Type::Link)
        child.data["destination"] = dest.not_nil!
        child.data["title"] = title || ""

        tmp = opener.node.next?
        while tmp
          next_node = tmp.next?
          tmp.unlink
          child.append_child(tmp)
          tmp = next_node
        end

        node.append_child(child)
        process_delimiters(opener.previous_delimiter)
        remove_bracket
        opener.node.unlink

        unless is_image
          opener = @brackets
          while opener
            opener.active = false unless opener.image?
            opener = opener.previous?
          end
        end
      else
        remove_bracket
        @pos = start_pos
        node.append_child(text("]"))
      end

      true
    end

    private def process_delimiters(delimiter : Delimiter?)
      # find first closer above stack_bottom:
      closer = @delimiters
      while closer
        previous = closer.previous?
        break if previous == delimiter
        closer = previous
      end

      if closer
        openers_bottom = {
          '_'  => delimiter,
          '*'  => delimiter,
          '\'' => delimiter,
          '"'  => delimiter,
        } of Char => Delimiter?

        openers_bottom['~'] = delimiter if @options.gfm?

        # move forward, looking for closers, and handling each
        while closer
          closer_char = closer.char

          unless closer.can_close?
            closer = closer.next?
            next
          end

          # found emphasis closer. now look back for first matching opener:
          opener = closer.previous?
          opener_found = false
          while opener && opener != delimiter && opener != openers_bottom[closer_char]
            odd_match = (closer.can_open? || opener.can_close?) &&
                        closer.orig_delims % 3 != 0 &&
                        (opener.orig_delims + closer.orig_delims) % 3 == 0
            if opener.char == closer.char && opener.can_open? && !odd_match
              opener_found = true
              break
            end
            opener = opener.previous?
          end
          opener = nil unless opener_found

          old_closer = closer

          case closer_char
          when '*', '_', '~'
            if closer_char != '~' || (closer_char == '~' && @options.gfm?)
              if opener
                # calculate actual number of delimiters used from closer
                use_delims = (closer.num_delims >= 2 && opener.num_delims >= 2) ? 2 : 1

                if closer_char == '~' && (
                     closer.num_delims > 2 ||
                     opener.num_delims > 2 ||
                     closer.num_delims != opener.num_delims
                   )
                  closer = closer.next?
                  next
                end

                opener_inl = opener.node
                closer_inl = closer.node

                # remove used delimiters from stack elts and inlines
                opener.num_delims -= use_delims
                closer.num_delims -= use_delims

                opener_inl.text = opener_inl.text[0..(-use_delims - 1)]
                closer_inl.text = closer_inl.text[0..(-use_delims - 1)]

                if closer_char == '~'
                  emph = Node.new(Node::Type::Strikethrough)
                else
                  # build contents for new emph element
                  emph = Node.new((use_delims == 1) ? Node::Type::Emphasis : Node::Type::Strong)
                end

                tmp = opener_inl.next?
                while tmp && tmp != closer_inl
                  next_node = tmp.next?
                  tmp.unlink
                  emph.append_child(tmp)
                  tmp = next_node
                end

                opener_inl.insert_after(emph)

                # remove elts between opener and closer in delimiters stack
                remove_delimiter_between(opener, closer)

                # if opener has 0 delims, remove it and the inline
                if opener.num_delims == 0
                  opener_inl.unlink
                  remove_delimiter(opener)
                end

                if closer.num_delims == 0
                  closer_inl.unlink
                  tmp_stack = closer.next?
                  remove_delimiter(closer)
                  closer = tmp_stack
                end
              else
                closer = closer.next?
              end
            end
          when '\''
            closer.node.text = "\u{2019}"
            if opener
              opener.node.text = "\u{2018}"
            end
            closer = closer.next?
          when '"'
            closer.node.text = "\u{201D}"
            if opener
              opener.node.text = "\u{201C}"
            end
            closer = closer.next?
          end

          if !opener && !odd_match
            openers_bottom[closer_char] = old_closer.previous?
            remove_delimiter(old_closer) if !old_closer.can_open?
          end
        end
      end

      # remove all delimiters
      while (curr_delimiter = @delimiters) && curr_delimiter != delimiter
        remove_delimiter(curr_delimiter)
      end
    end

    private def auto_link(node : Node)
      if (matched_text = match(Rule::EMAIL_AUTO_LINK))
        node.append_child(link(matched_text, true))
        return true
      elsif (matched_text = match(Rule::AUTO_LINK))
        node.append_child(link(matched_text, false))
        return true
      elsif @options.autolink?
        # These are all the extended autolinks from the
        # autolink extension

        if (matched_text = match(Rule::WWW_AUTO_LINK))
          clean_text = autolink_cleanup(matched_text)
          if clean_text.empty?
            node.append_child(text(matched_text))
          else
            _, post = @text.split(clean_text, 2)
            node.append_child(link(clean_text, false, true))
            node.append_child(text(post)) if post.size > 0 && matched_text != clean_text
          end
          return true
        elsif (matched_text = (
                match(Rule::PROTOCOL_AUTO_LINK) ||
                match(Rule::XMPP_AUTO_LINK) ||
                match(Rule::MAILTO_AUTO_LINK)
              ))
          clean_text = autolink_cleanup(matched_text)
          if clean_text.empty?
            node.append_child(text(matched_text))
          else
            _, post = @text.split(clean_text, 2)
            node.append_child(link(clean_text, false, false))
            node.append_child(text(post)) if post.size > 0 && matched_text != clean_text
          end
          return true
        elsif (matched_text = match(Rule::EXTENDED_EMAIL_AUTO_LINK))
          # Emails that end in - or _ are declared not to be links by the spec:
          #
          # `.`, `-`, and `_` can occur on both sides of the `@`, but only `.` may occur at
          # the end of the email address, in which case it will not be considered part of
          # the address:

          # a.b-c_d@a.b_  => <p>a.b-c_d@a.b_</p>

          if "-_".includes?(matched_text[-1])
            node.append_child(text(matched_text))
          else
            node.append_child(link(matched_text, true, false))
          end
          return true
        end
      end

      false
    end

    private def html_tag(node : Node)
      if (text = match(Rule::HTML_TAG))
        child = Node.new(Node::Type::HTMLInline)

        if @options.tagfilter?
          text = Rule::HTMLBlock.escape_disallowed_html(text)
        end

        child.text = text
        node.append_child(child)
        true
      else
        false
      end
    end

    private def entity(node : Node)
      if char_at?(@pos) == '&'
        if char_at?(@pos + 1) == '#'
          text = match(Rule::NUMERIC_HTML_ENTITY) || return false
          text = text.byte_slice(1, text.bytesize - 2)
        else
          pos = @pos + 1
          loop do
            char = char_at?(pos)
            pos += 1
            case char
            when ';'
              break
            when Char::ZERO, nil
              return false
            end
          end
          text = @text.byte_slice((@pos + 1), (pos - 1) - (@pos + 1))
          @pos = pos
        end

        decoded_text = HTML.decode_entity text
        node.append_child(text(decoded_text))
        true
      else
        false
      end
    end

    private def emoji(node : Node)
      return false unless @options.emoji?

      if char_at?(@pos) == ':'
        pos = @pos + 1
        loop do
          char = char_at?(pos)
          pos += 1

          case char
          when ':'
            break
          when Char::ZERO, nil
            return false
          when 'a'..'z', 'A'..'Z', '0'..'9', '+', '-', '_'
            nil
          else
            return false
          end
        end

        text = @text.byte_slice((@pos + 1), (pos - 1) - (@pos + 1))
        if (emoji = EmojiEntities::EMOJI_MAPPINGS[text]?)
          @pos = pos
          node.append_child(text(emoji))

          true
        else
          false
        end
      else
        false
      end
    end

    private def string(node : Node)
      if (text = match_main)
        if @options.smart?
          text = text.gsub(Rule::ELLIPSIS, '\u{2026}')
            .gsub(Rule::DASH) do |chars|
              en_count = em_count = 0
              chars_length = chars.size

              if chars_length % 3 == 0
                em_count = chars_length // 3
              elsif chars_length % 2 == 0
                en_count = chars_length // 2
              elsif chars_length % 3 == 2
                en_count = 1
                em_count = (chars_length - 2) // 3
              else
                en_count = 2
                em_count = (chars_length - 4) // 3
              end

              "\u{2014}" * em_count + "\u{2013}" * en_count
            end
        end
        node.append_child(text(text))
        true
      else
        false
      end
    end

    private def link(match : String, email = false, add_proto = false) : Node
      dest = match.lstrip("<").rstrip(">")
      destination = email ? "mailto:#{dest}" : dest
      if add_proto
        destination = "http://#{destination}"
      end

      node = Node.new(Node::Type::Link)
      node.data["title"] = ""
      node.data["destination"] = normalize_uri(destination)
      node.append_child(text(dest))
      node
    end

    private def link_label
      text = match(Rule::LINK_LABEL)
      if text && text.size <= 1001 && (!text.ends_with?("\\]") || text[-3]? == '\\')
        text.bytesize - 1
      else
        0
      end
    end

    private def link_title
      title = match(Rule::LINK_TITLE)
      return unless title

      Utils.decode_entities_string(title[1..-2])
    end

    private def link_destination
      dest = if (text = match(Rule::LINK_DESTINATION_BRACES))
               text[1..-2]
             elsif char_at?(@pos) != '<'
               save_pos = @pos
               open_parens = 0
               while (char = char_at?(@pos))
                 case char
                 when '\\'
                   @pos += 1
                   match(Rule::ESCAPABLE)
                 when '('
                   @pos += 1
                   open_parens += 1
                 when ')'
                   break if open_parens < 1

                   @pos += 1
                   open_parens -= 1
                 when .ascii_whitespace?
                   break
                 else
                   @pos += 1
                 end
               end

               @text.byte_slice(save_pos, @pos - save_pos)
             end

      normalize_uri(Utils.decode_entities_string(dest)) if dest
    end

    private def handle_delim(char : Char, node : Node)
      res = scan_delims(char)
      return false unless res

      num_delims = res[:num_delims]
      start_pos = @pos
      @pos += num_delims
      text = case char
             when '\''
               "\u{2019}"
             when '"'
               "\u{201C}"
             else
               @text.byte_slice(start_pos, @pos - start_pos)
             end

      child = text(text)
      node.append_child(child)

      delimiter = Delimiter.new(char, num_delims, num_delims, child, @delimiters, nil, res[:can_open], res[:can_close])

      if (prev = delimiter.previous?)
        prev.next = delimiter
      end

      @delimiters = delimiter

      true
    end

    private def remove_delimiter(delimiter : Delimiter)
      if (prev = delimiter.previous?)
        prev.next = delimiter.next?
      end

      if (nxt = delimiter.next?)
        nxt.previous = delimiter.previous?
      else
        # top of stack
        @delimiters = delimiter.previous?
      end
    end

    private def remove_delimiter_between(bottom : Delimiter, top : Delimiter)
      if bottom.next? != top
        bottom.next = top
        top.previous = bottom
      end
    end

    private def scan_delims(char : Char)
      num_delims = 0
      start_pos = @pos
      if char == '\'' || char == '"'
        num_delims += 1
        @pos += 1
      else
        while char_at?(@pos) == char
          num_delims += 1
          @pos += 1
        end
      end

      return if num_delims == 0

      char_before = start_pos == 0 ? '\n' : previous_unicode_char_at(start_pos)
      char_after = unicode_char_at?(@pos) || '\n'

      # Match ASCII code 160 => \xA0 (See http://www.adamkoch.com/2009/07/25/white-space-and-character-160/)
      after_is_whitespace = char_after.ascii_whitespace? || char_after == '\u00A0'
      after_is_punctuation = !!char_after.to_s.match(Rule::PUNCTUATION)
      before_is_whitespace = char_before.ascii_whitespace? || char_after == '\u00A0'
      before_is_punctuation = !!char_before.to_s.match(Rule::PUNCTUATION)

      left_flanking = !after_is_whitespace &&
                      (!after_is_punctuation || before_is_whitespace || before_is_punctuation)
      right_flanking = !before_is_whitespace &&
                       (!before_is_punctuation || after_is_whitespace || after_is_punctuation)

      case char
      when '_'
        can_open = left_flanking && (!right_flanking || before_is_punctuation)
        can_close = right_flanking && (!left_flanking || after_is_punctuation)
      when '\'', '"'
        can_open = left_flanking && !right_flanking
        can_close = right_flanking
      else
        can_open = left_flanking
        can_close = right_flanking
      end

      @pos = start_pos

      {
        num_delims: num_delims,
        can_open:   can_open,
        can_close:  can_close,
      }
    end

    def reference(text : String, refmap)
      @text = text
      @pos = 0

      startpos = @pos
      match_chars = link_label

      # label
      return 0 if match_chars == 0
      raw_label = @text.byte_slice(0, match_chars + 1)

      # colon
      if char_at?(@pos) == ':'
        @pos += 1
      else
        @pos = startpos
        return 0
      end

      # link url
      spnl

      save_pos = @pos
      dest = link_destination

      if !dest || (dest.size == 0 && !(@pos == save_pos + 2 && @text.byte_slice(save_pos, 2) == "<>"))
        @pos = startpos
        return 0
      end

      before_title = @pos
      spnl
      if @pos != before_title
        title = link_title
      end

      unless title
        title = ""
        @pos = before_title
      end

      at_line_end = true
      unless space_at_end_of_line?
        if title.empty?
          at_line_end = false
        else
          title = ""
          @pos = before_title
          at_line_end = space_at_end_of_line?
        end
      end

      unless at_line_end
        @pos = startpos
        return 0
      end

      normal_label = normalize_reference(raw_label)
      if normal_label.empty?
        @pos = startpos
        return 0
      end

      unless refmap[normal_label]?
        refmap[normal_label] = {
          "destination" => dest,
          "title"       => title,
        }
      end

      @pos - startpos
    end

    private def space_at_end_of_line?
      while char_at?(@pos) == ' '
        @pos += 1
      end

      case char_at?(@pos)
      when '\n'
        @pos += 1
      when Char::ZERO
      else
        return false
      end

      true
    end

    # Parse zero or more space characters, including at most one newline
    private def spnl
      seen_newline = false
      while (c = char_at?(@pos))
        if !seen_newline && c == '\n'
          seen_newline = true
        elsif c != ' '
          break
        end

        @pos += 1
      end

      true
    end

    private def match(regex : Regex) : String?
      text = @text.byte_slice(@pos)
      if (match = text.match(regex))
        @pos += match.byte_end.not_nil!
        return match[0]
      end
    end

    # This function advances @pos as far as possible until it finds a
    # "special" character, such as '<', ']', or a special string (like a URL).
    #
    # Then it returns the chunk before it found that match, or in the case
    # of special strings, the chunk matched.

    private def match_main : String?
      start_pos = @pos
      while (char = char_at?(@pos))
        # If we detected a special string (like a URL), and it's
        # not the beggining of the string, we need to break right away.
        #
        # If we are at the beginning of the string, then we return
        # the chunk matched
        if @options.autolink?
          advance = special_string?(@text, @pos)
          if advance > 0
            if @pos > start_pos
              break
            else
              @pos += advance
              break
            end
          end
        end

        # If we detect a special character, we need to break
        break if !main_char?(char)
        @pos += 1
      end

      if start_pos == @pos
        nil
      else
        @text.byte_slice(start_pos, @pos - start_pos)
      end
    end

    # Identify "special" strings by matching against
    # regular expressions. It returns the number of characters
    # that were matched.

    private def special_string?(full_text : String, pos : Int) : Int
      text = full_text.byte_slice(pos)
      # All such recognized autolinks can only come at the beginning of
      # a line, after whitespace, or any of the delimiting characters `*`, `_`, `~`,
      # and `(`.
      if pos > 0 && !("*_~( \n\t".includes? char_at(pos - 1))
        0
      elsif text.starts_with?("http://") || text.starts_with?("https://") || text.starts_with?("ftp://")
        # This should not be an autolink:
        # < ftp://example.com >
        if full_text[...pos].includes?("<") && full_text[...pos].matches?(/<\s*$/)
          return 0
        end

        m = autolink_cleanup(text.match(Rule::PROTOCOL_AUTO_LINK).to_s)
        m.size
      elsif text.starts_with?("www.") && text.matches?(Rule::WWW_AUTO_LINK)
        m = autolink_cleanup(text.match(Rule::WWW_AUTO_LINK).to_s)
        m.size
      elsif text.includes?("@") && text.matches?(Rule::EXTENDED_EMAIL_AUTO_LINK)
        # m = autolink_cleanup(text.match(Rule::EMAIL_AUTO_LINK).to_s)
        matched_text = text.match(Rule::EMAIL_AUTO_LINK).to_s

        # `.`, `-`, and `_` can occur on both sides of the `@`, but only `.` may occur at
        # the end of the email address, in which case it will not be considered part of
        # the address:

        if "-_".includes? char_at(pos + matched_text.size + 1)
          return 0
        end
        matched_text.size
      else
        0
      end
    end

    # These cleanups are defined in the spec

    private def autolink_cleanup(text : String) : String
      return text if text.empty?
      # When an autolink ends in `)`, we scan the entire autolink for the total number
      # of parentheses.  If there is a greater number of closing parentheses than
      # opening ones, we don't consider the unmatched trailing parentheses part of the
      # autolink, in order to facilitate including an autolink inside a parenthesis:
      while text.ends_with?(")") && text.count(")") != text.count("(")
        text = text[0..-2]
      end

      # Trailing punctuation (specifically, `?`, `!`, `.`, `,`, `:`, `*`, `_`, and `~`)
      # will not be considered part of the autolink, though they may be included in the
      # interior of the link
      while "\"'?!.,:*~_".includes?(text[-1])
        text = text[0..-2]
      end

      # If an autolink ends in a semicolon (`;`), we check to see if it appears to
      # resemble an [entity reference][entity references]; if the preceding text is `&`
      # followed by one or more alphanumeric characters.  If so, it is excluded from
      # the autolink:

      if text.ends_with?(";") && text.includes?("&")
        parts = text.split("&")
        if "&#{parts[-1]}".matches?(Rule::HTML_ENTITY)
          text = parts[0..-2].join("&")
        end
      end

      # If the autolink has a domain and the last component has a `_` then
      # it's invalid.
      if text.starts_with?("www.")
        uri = URI.parse("http://#{text}")
      else
        uri = URI.parse(text)
      end
      if uri.host && !uri.host.to_s.match(Rule::VALID_DOMAIN_NAME)
        text = ""
      end

      text
    end

    # This is the same as match(/^[^\n`\[\]\\!<&*_'":]+/m) but done manually (faster)
    private def main_char?(char)
      case char
      when '\n', '`', '[', ']', '\\', '!', '<', '&', '*', '_', '\'', '"', ':', 'w'
        false
      when '~'
        !@options.gfm?
      else
        true
      end
    end

    private def text(text) : Node
      node = Node.new(Node::Type::Text)
      node.text = text.to_s
      node
    end

    private def char_at?(byte_index)
      @text.byte_at?(byte_index).try &.unsafe_chr
    end

    private def char_at(byte_index)
      @text.byte_at(byte_index).unsafe_chr
    end

    private def previous_unicode_char_at(byte_index)
      reader = Char::Reader.new(@text, byte_index)
      reader.previous_char
    end

    private def unicode_char_at?(byte_index)
      if byte_index < @text.bytesize
        reader = Char::Reader.new(@text, byte_index)
        reader.current_char
      end
    end

    # Normalize reference label: collapse internal whitespace
    # to single space, remove leading/trailing whitespace, case fold.
    def normalize_reference(text : String)
      text[1..-2].strip.downcase.gsub("\n", " ")
    end

    private RESERVED_CHARS = ['&', '+', ',', '(', ')', '\'', '#', '*', '!', '#', '$', '/', ':', ';', '?', '@', '=']

    def normalize_uri(uri : String)
      String.build(capacity: uri.bytesize) do |io|
        URI.encode(decode_uri(uri), io) do |byte|
          URI.unreserved?(byte) || RESERVED_CHARS.includes?(byte.chr)
        end
      end
    end

    def decode_uri(text : String)
      decoded = URI.decode(text)
      if decoded.includes?('&') && decoded.includes?(';')
        decoded = decoded.gsub(/^&(\w+);$/) { |chars| HTML.decode_entities(chars) }
      end
      decoded
    end

    class Bracket
      property node : Node
      property! previous : Bracket?
      property previous_delimiter : Delimiter?
      property index : Int32
      property? image : Bool
      property? active : Bool
      property? bracket_after : Bool

      def initialize(@node, @previous, @previous_delimiter, @index, @image, @active = true)
        @bracket_after = false
      end
    end

    class Delimiter
      property char : Char
      property num_delims : Int32
      property orig_delims : Int32
      property node : Node
      property! previous : Delimiter?
      property! next : Delimiter?
      property? can_open : Bool
      property? can_close : Bool

      def initialize(@char, @num_delims, @orig_delims, @node,
                     @previous, @next, @can_open, @can_close)
      end
    end
  end
end
