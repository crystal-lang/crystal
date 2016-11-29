class Regex
  # `Regex::MatchData` is the type of the special variable `$~`, and is the type
  # returned by `Regex#match` and `String#match`. It encapsulates all the
  # results of a regular expression match.
  #
  # ```
  # if md = "Crystal".match(/[p-s]/)
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
    # "Crystal".match(/[p-s]/).not_nil!.regex # => /[p-s]/
    # ```
    getter regex : Regex

    # Returns the number of capture groups, including named capture groups.
    #
    # ```
    # "Crystal".match(/[p-s]/).not_nil!.size          # => 0
    # "Crystal".match(/r(ys)/).not_nil!.size          # => 1
    # "Crystal".match(/r(ys)(?<ok>ta)/).not_nil!.size # => 2
    # ```
    getter size : Int32

    # Returns the original string.
    #
    # ```
    # "Crystal".match(/[p-s]/).not_nil!.string # => "Crystal"
    # ```
    getter string : String

    # :nodoc:
    def initialize(@regex : Regex, @code : LibPCRE::Pcre, @string : String, @pos : Int32, @ovector : Int32*, @size : Int32)
    end

    # Return the position of the first character of the `n`th match.
    #
    # When `n` is `0` or not given, uses the match of the entire `Regex`.
    # Otherwise, uses the match of the `n`th capture group.
    #
    # ```
    # "Crystal".match(/r/).not_nil!.begin(0)     # => 1
    # "Crystal".match(/r(ys)/).not_nil!.begin(1) # => 2
    # "クリスタル".match(/リ(ス)/).not_nil!.begin(0)    # => 1
    # ```
    def begin(n = 0)
      @string.byte_index_to_char_index byte_begin(n)
    end

    # Return the position of the next character after the match.
    #
    # When `n` is `0` or not given, uses the match of the entire `Regex`.
    # Otherwise, uses the match of the `n`th capture group.
    #
    # ```
    # "Crystal".match(/r/).not_nil!.end(0)     # => 2
    # "Crystal".match(/r(ys)/).not_nil!.end(1) # => 4
    # "クリスタル".match(/リ(ス)/).not_nil!.end(0)    # => 3
    # ```
    def end(n = 0)
      @string.byte_index_to_char_index byte_end(n)
    end

    # Return the position of the first byte of the `n`th match.
    #
    # When `n` is `0` or not given, uses the match of the entire `Regex`.
    # Otherwise, uses the match of the `n`th capture group.
    #
    # ```
    # "Crystal".match(/r/).not_nil!.byte_begin(0)     # => 1
    # "Crystal".match(/r(ys)/).not_nil!.byte_begin(1) # => 4
    # "クリスタル".match(/リ(ス)/).not_nil!.byte_begin(0)    # => 3
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
    # "Crystal".match(/r/).not_nil!.byte_end(0)     # => 2
    # "Crystal".match(/r(ys)/).not_nil!.byte_end(1) # => 4
    # "クリスタル".match(/リ(ス)/).not_nil!.byte_end(0)    # => 9
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
    # "Crystal".match(/r(ys)/).not_nil![0]? # => "rys"
    # "Crystal".match(/r(ys)/).not_nil![1]? # => "ys"
    # "Crystal".match(/r(ys)/).not_nil![2]? # => nil
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
    # "Crystal".match(/r(ys)/).not_nil![1] # => "ys"
    # "Crystal".match(/r(ys)/).not_nil![2] # => raises IndexError
    # ```
    def [](n)
      check_index_out_of_bounds n

      self[n]?.not_nil!
    end

    # Returns the match of the capture group named by `group_name`, or
    # `nil` if there is no such named capture group.
    #
    # ```
    # "Crystal".match(/r(?<ok>ys)/).not_nil!["ok"]? # => "ys"
    # "Crystal".match(/r(?<ok>ys)/).not_nil!["ng"]? # => nil
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
    # "Crystal".match(/r(?<ok>ys)/).not_nil!["ok"] # => "ys"
    # "Crystal".match(/r(?<ok>ys)/).not_nil!["ng"] # => raises ArgumentError
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
    # "Crystal".match(/yst/).not_nil!.pre_match # => "Cr"
    # ```
    def pre_match
      @string.byte_slice(0, byte_begin(0))
    end

    # Returns the part of the original string after the match. If the match ends
    # at the end of the string, returns the empty string.
    #
    # ```
    # "Crystal".match(/yst/).not_nil!.post_match # => "al"
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

    def dup
      self
    end

    def clone
      self
    end

    private def check_index_out_of_bounds(index)
      raise IndexError.new unless valid_group?(index)
    end

    private def valid_group?(index)
      index <= @size
    end
  end
end
