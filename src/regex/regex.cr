require "./*"

class Regex
  @[Flags]
  enum Options
    IGNORE_CASE = 1
    # PCRE native PCRE_MULTILINE flag is 2, and PCRE_DOTALL is 4 ;
    # - PCRE_DOTALL changes the "." meaning,
    # - PCRE_MULTILINE changes "^" and "$" meanings)
    # Ruby modifies this meaning to have essentially one unique "m"
    # flag that activates both behviours, so here we do the same by
    # mapping MULTILINE to PCRE_MULTILINE | PCRE_DOTALL
    MULTILINE = 6
    EXTENDED = 8
    # :nodoc:
    ANCHORED      = 16
    # :nodoc:
    UTF_8         = 0x00000800
    # :nodoc:
    NO_UTF8_CHECK = 0x00002000
  end

  # Return a String representing the optional flags applied to the Regex.
  #
  # ```
  # /ab+c/ix.source #=> "IGNORE_CASE, EXTENDED"
  # ```
  getter options

  # Return the original String representation of the Regex pattern.
  #
  # ```
  # /ab+c/x.source #=> "ab+c"
  # ```
  getter source

  # Creates a new Regex out of the given source String.
  # 
  # ```
  # Regexp.new("^a-z+:\s+\w+") #=> /^a-z+:\s+\w+/
  # Regexp.new("cat", Regex::Options::IGNORE_CASE) #=> /cat/i
  # options = Regex::Options::IGNORE_CASE | Regex::Options::EXTENDED
  # Regexp.new("dog", options) #=> /dog/ix
  # ```
  def initialize(source, @options = Options::None : Options)
    # PCRE's pattern must have their null characters escaped
    source = source.gsub('\u{0}', "\\0")
    @source = source

    @re = LibPCRE.compile(@source, (options | Options::UTF_8 | Options::NO_UTF8_CHECK).value, out errptr, out erroffset, nil)
    raise ArgumentError.new("#{String.new(errptr)} at #{erroffset}") if @re.nil?
    @extra = LibPCRE.study(@re, 0, out studyerrptr)
    raise ArgumentError.new("#{String.new(studyerrptr)}") if @extra.nil? && studyerrptr
    LibPCRE.full_info(@re, nil, LibPCRE::INFO_CAPTURECOUNT, out @captures)
  end

  # Determines Regex's source validity. If it is, `nil` is returned.
  # If it's not, a String containing the error message is returned.
  #
  # ```
  # Regex.error("(foo|bar)") #=> nil
  # Regex.error("(foo|bar") #=> "missing ) at 8"
  # ```
  def self.error?(source)
    re = LibPCRE.compile(source, (Options::UTF_8 | Options::NO_UTF8_CHECK).value, out errptr, out erroffset, nil)
    if re
      nil
    else
      "#{String.new(errptr)} at #{erroffset}"
    end
  end

  # Returns a String constructed by escaping any metacharacters in `str`.
  #
  # ```
  # string = Regex.escape("\*?{}.") #=> "\\*\\?\\{\\}\\."
  # /#{string}/ #=> /\*\?\{\}\./
  # ```
  def self.escape(str)
    String.build do |result|
      str.each_byte do |byte|
        case byte.chr
        when ' ', '.', '\\', '+', '*', '?', '[',
             '^', ']', '$', '(', ')', '{', '}',
             '=', '!', '<', '>', '|', ':', '-'
          result << '\\'
          result.write_byte byte
        else
          result.write_byte byte
        end
      end
    end
  end

  # Equality. Two regexes are equal if their sources and options are the same.
  #
  # ```
  # /abc/ == /abc/i  #=> false
  # /abc/i == /ABC/i #=> false
  # /abc/i == /abc/i #=> true
  # ```
  def ==(other : Regex)
    source == other.source && options == other.options
  end

  # Case equality. This is equivalent to `#match` or `#=~` but only returns
  # `true` or `false`. Used in `case` expressions. The special variable
  # `$~` will contain a `MatchData` if there was a match, `nil` otherwise.
  #
  # ```
  # a = "HELLO"
  # b = case a
  #     when /^[a-z]*$/
  #       "Lower case"
  #     when /^[A-Z]*$/
  #       "Upper case"
  #     else
  #       "Mixed case"
  #     end
  # b #=> "Upper case"
  # ```
  def ===(other : String)
    match = match(other)
    $~ = match
    !match.nil?
  end

  # Match. Matches a regular expression against `other` and returns
  # the starting position of the match if `other` is a matching String,
  # otherwise `nil`. `$~` will contain a MatchData if there was a match,
  # `nil` otherwise.
  #
  # ```
  # /at/ =~ "input data"   #=> 7
  # /ax/ =~ "input data"   #=> nil
  # ```
  def =~(other : String)
    match = self.match(other)
    $~ = match
    match.try &.begin(0)
  end

  # Match. When the argument is not a String, always returns `nil`.
  #
  # ```
  # /at/ =~ "input data"   #=> 7
  # /ax/ =~ "input data"   #=> nil
  # ```
  def =~(other)
    nil
  end

  # Convert to String. Same as `to_s`.
  def inspect(io : IO)
    to_s io
  end

  # Match at character index. Matches a regular expression against String
  # `str`. Starts at the character index given by `pos` if given, otherwise at
  # the start of `str`. Returns a `MatchData` if `str` matched, otherwise
  # `nil`. `$~` will contain the same value that was returned.
  #
  # ```
  # /(.)(.)(.)/.match("abc").not_nil![2] #=> "b"
  # /(.)(.)/.match("abc", 1).not_nil![2] #=> "c"
  # /(.)(.)/.match("クリスタル", 3).not_nil![2] #=> "ル"
  # ```
  def match(str, pos = 0, options = Regex::Options::None)
    if byte_index = str.char_index_to_byte_index(pos)
      match = match_at_byte_index(str, byte_index, options)
    else
      match = nil
    end

    $~ = match
  end

  # Match at byte index. Matches a regular expression against String
  # `str`. Starts at the byte index given by `pos` if given, otherwise at
  # the start of `str`. Returns a MatchData if `str` matched, otherwise
  # `nil`. `$~` will contain the same value that was returned.
  #
  # ```
  # /(.)(.)(.)/.match_at_byte_index("abc").not_nil![2] #=> "b"
  # /(.)(.)/.match_at_byte_index("abc", 1).not_nil![2] #=> "c"
  # /(.)(.)/.match_at_byte_index("クリスタル", 3).not_nil![2] #=> "ス"
  # ```
  def match_at_byte_index(str, byte_index = 0, options = Regex::Options::None)
    return ($~ = nil) if byte_index > str.bytesize

    ovector_size = (@captures + 1) * 3
    ovector = Pointer(Int32).malloc(ovector_size)
    ret = LibPCRE.exec(@re, @extra, str, str.bytesize, byte_index, (options | Options::NO_UTF8_CHECK).value, ovector, ovector_size)
    if ret > 0
      match = MatchData.new(self, @re, str, byte_index, ovector, @captures)
    else
      match = nil
    end

    $~ = match
  end

  # Returns a Hash where the values are the names of capture groups and the
  # keys are their indexes. Non-named capture groups will not have entries in
  # the Hash. Capture groups are indexed starting from 1.
  #
  # ```
  # /(.)/.name_table                         #=> {}
  # /(?<foo>.)/.name_table                   #=> {1 => "foo"}
  # /(?<foo>.)(?<bar>.)/.name_table          #=> {2 => "bar", 1 => "foo"}
  # /(.)(?<foo>.)(.)(?<bar>.)(.)/.name_table #=> {4 => "bar", 2 => "foo"}
  # ```
  def name_table
    LibPCRE.full_info(@re, @extra, LibPCRE::INFO_NAMECOUNT,     out name_count)
    LibPCRE.full_info(@re, @extra, LibPCRE::INFO_NAMEENTRYSIZE, out name_entry_size)
    table_pointer = Pointer(UInt8).null
    LibPCRE.full_info(@re, @extra, LibPCRE::INFO_NAMETABLE, pointerof(table_pointer) as Pointer(Int32))
    name_table = table_pointer.to_slice(name_entry_size*name_count)

    lookup = Hash(UInt16,String).new

    name_count.times do |i|
      capture_offset = i * name_entry_size
      capture_number = (name_table[capture_offset].to_u16 << 8) | name_table[capture_offset+1].to_u16

      name_offset = capture_offset + 2
      name = String.new( (name_table + name_offset).pointer(name_entry_size-3) )

      lookup[capture_number] = name
    end

    lookup
  end

  # Convert to String. Returns the source as a String in Regex literal
  # format, delimited in forward slashes (`/`), with any optional flags
  # included.
  #
  # ```
  # /ab+c/ix.to_s #=> "/ab+c/ix"
  # ```
  def to_s(io : IO)
    io << "/"
    io << source
    io << "/"
    io << "i" if options.includes?(Options::IGNORE_CASE)
    io << "m" if options.includes?(Options::MULTILINE)
    io << "x" if options.includes?(Options::EXTENDED)
  end
end
