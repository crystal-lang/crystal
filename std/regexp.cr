lib PCRE("pcre")
  fun compile = pcre_compile(pattern : Char*, options : Int32, errptr : Char**, erroffset : Int32*, tableptr : Int64) : Int64
  fun exec = pcre_exec(code : Int64, extra : Int64, subject : Char*, length : Int32, offset : Int32, options : Int32,
                ovector : Int32*, ovecsize : Int32) : Int32
  fun full_info = pcre_fullinfo(code : Int64, extra : Int64, what : Int32, where : Void*) : Int32

  INFO_CAPTURECOUNT = 2
end

class Regexp
  ANCHORED = 16

  def initialize(str)
    @source = str
    errptr = Pointer(Char).malloc(0)
    erroffset = 1
    @re = PCRE.compile(str, 8, errptr.ptr, erroffset.ptr, 0L)
    if @re == 0
      raise "#{String.from_cstr(errptr)} at #{erroffset}"
    end
    @captures = 0
    PCRE.full_info(@re, 0L, PCRE::INFO_CAPTURECOUNT, @captures.ptr.as(Void))
  end

  def match(str, pos = 0, options = 0)
    ovector_size = (@captures + 1) * 3
    ovector = Pointer(Int32).malloc(ovector_size * 4)
    ret = PCRE.exec(@re, 0L, str, str.length, pos, options, ovector, ovector_size)
    return nil unless ret > 0
    MatchData.new(self, str, pos, ovector)
  end

  def source
    @source
  end

  def to_s
    "/#{source}/"
  end
end

class MatchData
  def initialize(regex, string, pos, ovector)
    @regex = regex
    @string = string
    @pos = pos
    @ovector = ovector
  end

  def regex
    @regex
  end

  def begin(n)
    @ovector[n * 2]
  end

  def end(n)
    @ovector[n * 2 + 1]
  end

  def string
    @string
  end

  def [](index)
    @string[self.begin(index), self.end(index) - self.begin(index)]
  end
end