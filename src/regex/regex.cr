require "./*"

class Regex
  IGNORE_CASE = 1
  MULTILINE = 4
  EXTENDED = 8
  ANCHORED = 16
  UTF_8 = 0x00000800

  getter source

  def initialize(@source, modifiers = 0)
    @re = LibPCRE.compile(@source, modifiers | UTF_8, out errptr, out erroffset, nil)
    raise ArgumentError.new("#{String.new(errptr)} at #{erroffset}") if @re.nil?
    LibPCRE.full_info(@re, nil, LibPCRE::INFO_CAPTURECOUNT, out @captures)
  end

  def match(str, pos = 0, options = 0)
    ovector_size = (@captures + 1) * 3
    ovector = Pointer(Int32).malloc(ovector_size * 4)
    ret = LibPCRE.exec(@re, nil, str, str.bytesize, pos, options, ovector, ovector_size)
    if ret > 0
      match = MatchData.new(self, @re, str, pos, ovector, @captures)
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
