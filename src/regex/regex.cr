require "./*"

class Regex
  @[Flags]
  enum Options
    IGNORE_CASE = 1
    MULTILINE = 4
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

  # TODO: remove this constructor after 0.7.3
  def self.new(source, options : Int32)
    new source, Options.new(options)
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
