class File < IO::FileDescriptor
  class BadPatternError < Exception
  end

  # Matches *path* against *pattern*.
  #
  # The pattern syntax is similar to shell filename globbing. It may contain the following metacharacters:
  #
  # * `*` matches an unlimited number of arbitrary characters, excluding any directory separators.
  #   * `"*"` matches all regular files.
  #   * `"c*"` matches all files beginning with `c`.
  #   * `"*c"` matches all files ending with `c`.
  #   * `"*c*"` matches all files that have `c` in them (including at the beginning or end).
  # * `**` matches directories recursively if followed by `/`.
  #   If this path segment contains any other characters, it is the same as the usual `*`.
  # * `?` matches one arbitrary character, excluding any directory separators.
  # * character sets:
  #   * `[abc]` matches any one of these characters.
  #   * `[^abc]` matches any one character other than these.
  #   * `[a-z]` matches any one character in the range.
  # * `{a,b}` matches subpattern `a` or `b`.
  # * `\\` escapes the next character.
  #
  # If *path* is a `Path`, all directory separators supported by *path* are
  # recognized, according to the path's kind. If *path* is a `String`, only `/`
  # is considered a directory separator.
  #
  # NOTE: Only `/` in *pattern* matches directory separators in *path*.
  def self.match?(pattern : String, path : Path | String) : Bool
    expanded_patterns = [] of String
    File.expand_brace_pattern(pattern, expanded_patterns)

    if path.is_a?(Path)
      separators = Path.separators(path.@kind)
      path = path.to_s
    else
      separators = Path.separators(Path::Kind::POSIX)
    end

    expanded_patterns.each do |expanded_pattern|
      return true if match_single_pattern(expanded_pattern, path, separators)
    end
    false
  end

  private def self.match_single_pattern(pattern : String, path : String, separators)
    # linear-time algorithm adapted from https://research.swtch.com/glob
    preader = Char::Reader.new(pattern)
    sreader = Char::Reader.new(path)
    next_ppos = 0
    next_spos = 0
    strlen = path.bytesize
    escaped = false

    while true
      pnext = preader.has_next?
      snext = sreader.has_next?

      return true unless pnext || snext

      if pnext
        pchar = preader.current_char
        char = sreader.current_char

        case {pchar, escaped}
        when {'\\', false}
          escaped = true
          preader.next_char
          next
        when {'?', false}
          if snext && !char.in?(separators)
            preader.next_char
            sreader.next_char
            next
          end
        when {'*', false}
          double_star = preader.peek_next_char == '*'
          if char.in?(separators) && !double_star
            preader.next_char
            next_spos = 0
            next
          else
            next_ppos = preader.pos
            next_spos = sreader.pos + sreader.current_char_width
            preader.next_char
            preader.next_char if double_star
            next
          end
        when {'[', false}
          pnext = preader.has_next?

          character_matched = false
          character_set_open = true
          escaped = false
          inverted = false
          case preader.peek_next_char
          when '^'
            inverted = true
            preader.next_char
          when ']'
            raise BadPatternError.new "Invalid character set: empty character set"
          else
            # Nothing
            # TODO: check if this branch is fine
          end

          while pnext
            pchar = preader.next_char
            case {pchar, escaped}
            when {'\\', false}
              escaped = true
            when {']', false}
              character_set_open = false
              break
            when {'-', false}
              raise BadPatternError.new "Invalid character set: missing range start"
            else
              escaped = false
              if preader.has_next? && preader.peek_next_char == '-'
                preader.next_char
                range_end = preader.next_char
                case range_end
                when ']'
                  raise BadPatternError.new "Invalid character set: missing range end"
                when '\\'
                  range_end = preader.next_char
                else
                  # Nothing
                  # TODO: check if this branch is fine
                end
                range = (pchar..range_end)
                character_matched = true if range.includes?(char)
              elsif char == pchar
                character_matched = true
              end
            end
            pnext = preader.has_next?
            false
          end
          raise BadPatternError.new "Invalid character set: unterminated character set" if character_set_open

          if character_matched != inverted && snext
            preader.next_char
            sreader.next_char
            next
          end
        else
          escaped = false

          if snext && sreader.current_char == pchar
            preader.next_char
            sreader.next_char
            next
          end
        end
      end

      if 0 < next_spos <= strlen
        preader.pos = next_ppos
        sreader.pos = next_spos
        next
      end

      raise BadPatternError.new "Empty escape character" if escaped

      return false
    end
  end

  # :nodoc:
  def self.expand_brace_pattern(pattern : String, expanded) : Array(String)?
    reader = Char::Reader.new(pattern)

    lbrace = nil
    rbrace = nil
    alt_start = nil

    alternatives = [] of String

    nest = 0
    escaped = false
    reader.each do |char|
      case {char, escaped}
      when {'{', false}
        lbrace = reader.pos if nest == 0
        nest += 1
      when {'}', false}
        nest -= 1

        if nest == 0
          rbrace = reader.pos
          start = (alt_start || lbrace).not_nil! + 1
          alternatives << pattern.byte_slice(start, reader.pos - start)
          break
        end
      when {',', false}
        if nest == 1
          start = (alt_start || lbrace).not_nil! + 1
          alternatives << pattern.byte_slice(start, reader.pos - start)
          alt_start = reader.pos
        end
      when {'\\', false}
        escaped = true
      else
        escaped = false
      end
    end

    if lbrace && rbrace
      front = pattern.byte_slice(0, lbrace)
      back = pattern.byte_slice(rbrace + 1)

      alternatives.each do |alt|
        brace_pattern = {front, alt, back}.join

        expand_brace_pattern brace_pattern, expanded
      end
    else
      expanded << pattern
    end
  end
end
