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

  getter source

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

  def options
    @options
  end

  def match(str, pos = 0, options = Regex::Options::None)
    if byte_index = str.char_index_to_byte_index(pos)
      match = match_at_byte_index(str, byte_index, options)
    else
      match = nil
    end

    $~ = match
  end

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

  def ===(other : String)
    match = match(other)
    $~ = match
    !match.nil?
  end

  def =~(other : String)
    match = self.match(other)
    $~ = match
    match.try &.begin(0)
  end

  def =~(other)
    nil
  end

  def to_s(io : IO)
    io << "/"
    io << source
    io << "/"
    io << "i" if options.includes?(Options::IGNORE_CASE)
    io << "m" if options.includes?(Options::MULTILINE)
    io << "x" if options.includes?(Options::EXTENDED)
  end

  def inspect(io : IO)
    to_s io
  end

  def ==(other : Regex)
    source == other.source && options == other.options
  end

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
end
