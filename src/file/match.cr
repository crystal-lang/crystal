# This implementation of glob matching for `File.match?` is a port from the Rust
# crate https://github.com/devongovett/glob-match, which is adapted from the
# linear-time algorithm described in https://research.swtch.com/glob

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
    if path.is_a?(Path)
      separators = Path.separators(path.@kind)
      path = path.to_s
    else
      separators = Path.separators(Path::Kind::POSIX)
    end

    match_internal(pattern, path, separators)
  end

  private def self.match_internal(glob_str, path_str, separators)
    glob = glob_str.to_slice
    state = State.new(separators: separators.to_static_array.to_slice)

    # Store the state when we see an opening '{' brace in a stack.
    # Up to 10 nested braces are supported.
    brace_stack_data = uninitialized StaticArray({UInt32, UInt32}, 10)
    brace_stack = BraceStack.new(brace_stack_data.to_slice)

    # First, check if the pattern is negated with a leading '!' character.
    # Multiple negations can occur.
    negated = false

    # TODO: Enable negation
    # while state.glob_index < glob.size && glob[state.glob_index] === '!'
    #   negated = !negated
    #   state.glob_index += 1
    # end

    matched = state.match_from(glob_str, path_str, 0, brace_stack)

    matched != negated
  end

  private record State,
    separators : Slice(Char),
    path_index = 0_u64,
    glob_index = 0_u64,
    brace_depth = 0_u64,
    wildcard = Wildcard.new,
    globstar = Wildcard.new

  private record Wildcard,
    glob_index = 0_u32,
    path_index = 0_u32,
    brace_depth = 0_u32 do
    setter path_index
  end

  struct BraceStack(T)
    def initialize(@slice : Slice(T), @size = 0)
    end

    getter size

    @[AlwaysInline]
    def push(item : T)
      @slice[@size] = item
      @size += 1
    end

    @[AlwaysInline]
    def pop : T
      @size -= 1
      @slice[@size]
    end

    def to_slice
      @slice[0, @size]
    end
  end

  struct State
    @[AlwaysInline]
    def backtrack
      @glob_index = @wildcard.glob_index.to_u64
      @path_index = @wildcard.path_index.to_u64
      @brace_depth = @wildcard.brace_depth.to_u64
    end

    # Coalesce multiple ** segments into one.
    @[AlwaysInline]
    private def skip_globstars(glob)
      glob_index = @glob_index + 2
      while glob_index + 4 <= glob.size && glob[glob_index, 4] == "/**/".to_slice
        glob_index += 3
      end

      if glob[glob_index..] == "/**".to_slice
        glob_index += 3
      end

      @glob_index = glob_index - 2
    end

    @[AlwaysInline]
    def skip_to_separator(path, is_end_invalid)
      if @path_index == path.size
        @wildcard.path_index += 1
        return
      end

      path_index = @path_index
      while path_index < path.size && !separators.includes?(path[path_index].unsafe_chr)
        path_index += 1
      end

      if is_end_invalid || path_index != path.size
        path_index += 1
      end

      @wildcard.path_index = path_index.to_u32!
      @globstar = @wildcard
    end

    @[AlwaysInline]
    def skip_branch(glob)
      in_brackets = false
      end_brace_depth = @brace_depth - 1

      while @glob_index < glob.size
        c = glob[@glob_index]
        # Skip nested braces.
        if c === '{' && !in_brackets
          @brace_depth += 1
        elsif c === '}' && !in_brackets
          @brace_depth -= 1
          if @brace_depth == end_brace_depth
            @glob_index += 1
            return
          end
        elsif c === '[' && !in_brackets
          in_brackets = true
        elsif c === ']'
          in_brackets = false
        elsif c === '\\'
          @glob_index += 1
        end
        @glob_index += 1
      end
    end

    def match_brace_branch(
      glob : String,
      path : String,
      open_brace_index,
      branch_index,
      brace_stack,
    )
      brace_stack.push({open_brace_index.to_u32!, branch_index})

      branch_state = self.copy_with(
        glob_index: branch_index.to_u64,
        brace_depth: brace_stack.size.to_u64
      )

      matched = branch_state.match_from(glob, path, branch_index, brace_stack)

      brace_stack.pop

      matched
    end

    def match_brace(glob : String, path : String, brace_stack)
      brace_depth = 0
      in_brackets = false
      open_brace_index = @glob_index
      branch_index = 0_u32

      while @glob_index < glob.bytesize
        c = glob.to_slice[@glob_index]
        # Skip nested braces.
        if c === '{' && !in_brackets
          brace_depth += 1
          if brace_depth == 1
            branch_index = (@glob_index + 1).to_u32!
          end
        elsif c === '}' && !in_brackets
          brace_depth -= 1
          if brace_depth == 0
            return true if match_brace_branch(glob, path, open_brace_index, branch_index, brace_stack)
            break
          end
        elsif c === ',' && brace_depth == 1
          return true if match_brace_branch(glob, path, open_brace_index, branch_index, brace_stack)
          branch_index = (@glob_index + 1).to_u32!
        elsif c === '[' && !in_brackets
          in_brackets = true
        elsif c === ']'
          in_brackets = false
        elsif c === '\\'
          @glob_index += 1
        end
        @glob_index += 1
      end
      false
    end

    def match_from(glob_str, path_str, match_start, brace_stack)
      glob = glob_str.to_slice
      path = path_str.to_slice

      while @glob_index < glob.size || @path_index < path.size
        if @glob_index < glob.size
          g = glob[@glob_index]
          if '*' === g
            is_globstar = @glob_index + 1 < glob.size && glob[@glob_index + 1] === '*'

            if is_globstar
              skip_globstars(glob)
            end

            @wildcard = Wildcard.new(
              @glob_index.to_u32!,
              @path_index.to_u32! + 1,
              @brace_depth.to_u32!
            )

            in_globstar = false
            # `**` allows path separators, whereas `*` does not.
            # However, `**` must be a full path component, i.e. `a/**/b` not `a**b`.
            if is_globstar
              @glob_index += 2
              is_end_invalid = @glob_index != glob.size

              if (@glob_index.to_i64 - match_start < 3 || glob[@glob_index - 3] === '/') && (!is_end_invalid || glob[@glob_index] === '/')
                if is_end_invalid
                  @glob_index += 1
                end

                skip_to_separator(path, is_end_invalid)
                in_globstar = true
              end
            else
              @glob_index += 1
            end

            if !in_globstar && @path_index < path.size && separators.includes?(path[@path_index].unsafe_chr)
              @wildcard = @globstar
            end

            next
          elsif '?' === g && @path_index < path.size
            if !separators.includes?(path[@path_index].unsafe_chr)
              @glob_index += 1
              _, @path_index = consume_unicode_character(path_str, @path_index)
              next
            end
          elsif '[' === g && @path_index < path.size
            @glob_index += 1

            # Check if the character class is negated.
            negated_class = false
            if @glob_index < glob.size && glob[@glob_index] === '^'
              negated_class = true
              @glob_index += 1
            end

            # Try each range.
            first = true
            is_match = false

            c, new_path_index = consume_unicode_glob_character(path_str, @path_index)

            while @glob_index < glob.size && (first || !(']' === glob[@glob_index]))
              low, @glob_index = consume_unicode_glob_character(glob_str, @glob_index)

              # If there is a - and the following character is not ], read the range end character.
              if @glob_index + 1 < glob.size &&
                 glob[@glob_index] === '-' &&
                 !(glob[@glob_index + 1] === ']')
                @glob_index += 1
                high, @glob_index = consume_unicode_glob_character(glob_str, @glob_index)
              else
                high = low
              end

              if low <= c <= high
                is_match = true
              end

              first = false
            end
            if @glob_index >= glob.size
              raise BadPatternError.new "unterminated character set"
            end
            @glob_index += 1
            if is_match != negated_class
              @path_index = new_path_index
              next
            end
          elsif g === '{'
            if brace_stack_entry = brace_stack.to_slice.find { |open_brace_index, _| open_brace_index == @glob_index }
              _, branch_index = brace_stack_entry
              @glob_index = branch_index.to_u64
              @brace_depth += 1
              next
            end

            return match_brace(glob_str, path_str, brace_stack)
          elsif (g === '}' || g === ',') && @brace_depth > 0
            skip_branch(glob)
            next
          elsif @path_index < path.size
            c = g
            # Match escaped characters as literals.
            if !unescape(pointerof(c), glob, pointerof(@glob_index))
              raise BadPatternError.new "Empty escape character"
            end

            is_match = if c === '/'
                         separators.includes?(path[@path_index].unsafe_chr)
                       else
                         path[@path_index] == c
                       end

            if is_match
              @glob_index += 1
              @path_index += 1

              if c === '/'
                @wildcard = @globstar
              end

              next
            end
          end
        end

        # If we didn't match, restore state to the previous star pattern.
        if @wildcard.path_index > 0 && @wildcard.path_index.to_u32! <= path.size
          backtrack
          next
        end

        return false
      end

      true
    end
  end
end

@[AlwaysInline]
private def unescape(c, glob, glob_index) : Bool
  if '\\' === c.value
    glob_index.value += 1
    if glob_index.value >= glob.size
      # Invalid pattern!
      return false
    end
    c.value = case escaped_char = glob[glob_index.value]
              when 'a' then 0x61_u8
              when 'b' then 0x08_u8
              when 'n' then '\n'.ord.to_u8!
              when 'r' then '\r'.ord.to_u8!
              when 't' then '\t'.ord.to_u8!
              else          escaped_char
              end
  end

  true
end

@[AlwaysInline]
private def consume_unicode_character(string, index) : {Char, UInt64}
  reader = Char::Reader.new(string, index)
  {reader.current_char, index + reader.current_char_width}
end

@[AlwaysInline]
private def consume_unicode_glob_character(string, index) : {Char, UInt64}
  c = string.to_unsafe[index]

  if !unescape(pointerof(c), string.to_slice, pointerof(index))
    raise File::BadPatternError.new("Invalid pattern")
  end

  if c < 0x80
    {c.unsafe_chr, index + 1}
  else
    consume_unicode_character(string, index)
  end
end
