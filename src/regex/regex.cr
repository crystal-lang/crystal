require "./*"

class Regex
  IGNORE_CASE   = 1
  MULTILINE     = 4
  EXTENDED      = 8
  ANCHORED      = 16
  UTF_8         = 0x00000800
  NO_UTF8_CHECK = 0x00002000

  getter source

  def initialize(@source, modifiers = 0)
    @re = LibPCRE.compile(@source, modifiers | UTF_8 | NO_UTF8_CHECK, out errptr, out erroffset, nil)
    raise ArgumentError.new("#{String.new(errptr)} at #{erroffset}") if @re.nil?
    @extra = LibPCRE.study(@re, 0, out studyerrptr)
    raise ArgumentError.new("#{String.new(studyerrptr)}") if @extra.nil? && studyerrptr
    LibPCRE.full_info(@re, nil, LibPCRE::INFO_CAPTURECOUNT, out @captures)
  end

  def match(str, pos = 0, options = 0)
    if byte_index = str.char_index_to_byte_index(pos)
      match = match_at_byte_index(str, byte_index, options)
    else
      match = nil
    end

    $~ = match
  end

  def match_at_byte_index(str, byte_index = 0, options = 0)
    ovector_size = (@captures + 1) * 3
    ovector = Pointer(Int32).malloc(ovector_size * 4)
    ret = LibPCRE.exec(@re, @extra, str, str.bytesize, byte_index, options | NO_UTF8_CHECK, ovector, ovector_size)
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
end
