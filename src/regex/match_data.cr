class Regex
  # `Regex::MatchData` is the type of the special variable `$~`, and is the type
  # returned by `Regex#match` and `String#match`. It encapsulates all the
  # results of a regular expression match.
  #
  # `Regex#match` and `String#match` can return `nil`, to represent an
  # unsuccessful match, but there are overloads of both methods that accept a
  # block. These overloads are convenient to access the `Regex::MatchData` of a
  # successful match, since the block argument can't be `nil`.
  #
  # ```
  # "Crystal".match(/[p-s]/).size # => undefined method 'size' for Nil
  #
  # "Crystal".match(/[p-s]/) do |md|
  #   md.string # => "Crystal"
  #   md[0]     # => "r"
  #   md[1]?    # => nil
  # end
  # ```
  #
  # Many `Regex::MatchData` methods deal with capture groups, and accept an integer
  # argument to select the desired capture group. Capture groups are numbered
  # starting from `1`, so that `0` can be used to refer to the entire regular
  # expression without needing to capture it explicitly.
  class MatchData
    # Returns the original regular expression.
    #
    # ```
    # "Crystal".match(/[p-s]/) { |md| md.regex } # => /[p-s]/
    # ```
    getter regex

    # Returns the number of capture groups, including named capture groups.
    #
    # ```
    # "Crystal".match(/[p-s]/) { |md| md.size }          # => 0
    # "Crystal".match(/r(ys)/) { |md| md.size }          # => 1
    # "Crystal".match(/r(ys)(?<ok>ta)/) { |md| md.size } # => 2
    # ```
    getter size

    # Returns the original string.
    #
    # ```
    # "Crystal".match(/[p-s]/) { |md| md.string } # => "Crystal"
    # ```
    getter string

    # :nodoc:
    def initialize(@regex, @code, @string, @pos, @ovector, @size)
    end

    # Return the position of the first character of the `n`th match.
    #
    # When `n` is `0` or not given, uses the match of the entire `Regex`.
    # Otherwise, uses the match of the `n`th capture group.
    #
    # ```
    # "Crystal".match(/r/) { |md| md.begin(0) }     # => 1
    # "Crystal".match(/r(ys)/) { |md| md.begin(1) } # => 2
    # "クリスタル".match(/リ(ス)/) { |md| md.begin(0) }    # => 1
    # ```
    def begin(n = 0)
      byte_index_to_char_index byte_begin(n)
    end

    # Return the position of the next character after the match.
    #
    # When `n` is `0` or not given, uses the match of the entire `Regex`.
    # Otherwise, uses the match of the `n`th capture group.
    #
    # ```
    # "Crystal".match(/r/) { |md| md.end(0) }     # => 2
    # "Crystal".match(/r(ys)/) { |md| md.end(1) } # => 4
    # "クリスタル".match(/リ(ス)/) { |md| md.end(0) }    # => 3
    # ```
    def end(n = 0)
      byte_index_to_char_index byte_end(n)
    end

    # Return the position of the first byte of the `n`th match.
    #
    # When `n` is `0` or not given, uses the match of the entire `Regex`.
    # Otherwise, uses the match of the `n`th capture group.
    #
    # ```
    # "Crystal".match(/r/) { |md| md.byte_begin(0) }     # => 1
    # "Crystal".match(/r(ys)/) { |md| md.byte_begin(1) } # => 4
    # "クリスタル".match(/リ(ス)/) { |md| md.byte_begin(0) }    # => 3
    # ```
    def byte_begin(n = 0)
      check_index_out_of_bounds n
      @ovector[n * 2]
    end

    # Return the position of the next byte after the match.
    #
    # When `n` is `0` or not given, uses the match of the entire `Regex`.
    # Otherwise, uses the match of the `n`th capture group.
    #
    # ```
    # "Crystal".match(/r/) { |md| md.byte_end(0) }     # => 2
    # "Crystal".match(/r(ys)/) { |md| md.byte_end(1) } # => 4
    # "クリスタル".match(/リ(ス)/) { |md| md.byte_end(0) }    # => 9
    # ```
    def byte_end(n = 0)
      check_index_out_of_bounds n
      @ovector[n * 2 + 1]
    end

    # Returns the match of the `n`th capture group, or `nil` if there isn't
    # an `n`th capture group.
    #
    # When `n` is `0`, returns the match for the entire `Regex`.
    #
    # ```
    # "Crystal".match(/r(ys)/) { |md| md[0]? } # => "rys"
    # "Crystal".match(/r(ys)/) { |md| md[1]? } # => "ys"
    # "Crystal".match(/r(ys)/) { |md| md[2]? } # => nil
    # ```
    def []?(n)
      return unless valid_group?(n)

      start = @ovector[n * 2]
      finish = @ovector[n * 2 + 1]
      return if start < 0
      @string.byte_slice(start, finish - start)
    end

    # Returns the match of the `n`th capture group, or raises an `IndexError`
    # if there is no `n`th capture group.
    #
    # ```
    # "Crystal".match(/r(ys)/) { |md| md[1]? } # => "ys"
    # "Crystal".match(/r(ys)/) { |md| md[2]? } # => raises IndexError
    # ```
    def [](n)
      check_index_out_of_bounds n

      self[n]?.not_nil!
    end

    # Returns the match of the capture group named by `group_name`, or
    # `nil` if there is no such named capture group.
    #
    # ```
    # "Crystal".match(/r(?<ok>ys)/) { |md| md["ok"]? } # => "ys"
    # "Crystal".match(/r(?<ok>ys)/) { |md| md["ng"]? } # => nil
    # ```
    def []?(group_name : String)
      ret = LibPCRE.get_stringnumber(@code, group_name)
      return if ret < 0
      self[ret]?
    end

    # Returns the match of the capture group named by `group_name`, or
    # raises an `ArgumentError` if there is no such named capture group.
    #
    # ```
    # "Crystal".match(/r(?<ok>ys)/) { |md| md["ok"] } # => "ys"
    # "Crystal".match(/r(?<ok>ys)/) { |md| md["ng"] } # => raises ArgumentError
    # ```
    def [](group_name : String)
      match = self[group_name]?
      unless match
        raise ArgumentError.new("Match group named '#{group_name}' does not exist")
      end
      match
    end

    # Returns the part of the original string before the match. If the match
    # starts at the start of the string, returns the empty string.
    #
    # ```
    # "Crystal".match(/yst/) { |md| md.pre_match } # => "Cr"
    # ```
    def pre_match
      @string.byte_slice(0, byte_begin(0))
    end

    # Returns the part of the original string after the match. If the match ends
    # at the end of the string, returns the empty string.
    #
    # ```
    # "Crystal".match(/yst/) { |md| md.post_match } # => "al"
    # ```
    def post_match
      @string.byte_slice(byte_end(0))
    end

    def inspect(io : IO)
      to_s(io)
    end

    def to_s(io : IO)
      name_table = @regex.name_table

      io << "#<Regex::MatchData "
      self[0].inspect(io)
      if size > 0
        io << " "
        size.times do |i|
          io << " " if i > 0
          io << name_table.fetch(i + 1) { i + 1 }
          io << ":"
          self[i + 1]?.inspect(io)
        end
      end
      io << ">"
    end

    private def byte_index_to_char_index(index)
      reader = Char::Reader.new(@string)
      i = 0
      reader.each do |char|
        break if reader.pos == index
        i += 1
      end
      i
    end

    private def check_index_out_of_bounds(index)
      raise IndexError.new unless valid_group?(index)
    end

    private def valid_group?(index)
      index <= @size
    end
  end
end
