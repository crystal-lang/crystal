lib PCRE("pcre")
  type CharPtr : ptr Char
  fun pcre_compile(pattern : ptr Char, options : Int, errptr : ptr CharPtr, erroffset : ptr Int, tableptr : Long) : Long
  fun pcre_exec(code : Long, extra : Long, subject : ptr Char, length : Int, offset : Int, options : Int,
                ovector : ptr Int, ovecsize : Int) : Int
end

class Regexp
  def initialize(str)
    errptr = Pointer.malloc(0).as(Char)
    erroffset = 1
    @re = PCRE.pcre_compile(str.cstr, 8, errptr.ptr.as(PCRE::CharPtr), erroffset.ptr, 0L)
    if @re == 0
      puts "#{errptr.as(String)} at #{erroffset}"
      exit 1
    end
  end

  def match(str, pos = 0)
    ovector = Pointer.malloc(3 * 4).as(Int)
    ret = PCRE.pcre_exec(@re, 0L, str.cstr, str.length, pos, 0, ovector, 3)
    if ret > 0
      MatchData.new(self, str, pos, ovector)
    else
      nil
    end
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
    @ovector[n * 2] + @pos
  end

  def end(n)
    @ovector[n * 2 + 1] + @pos
  end

  def string
    @string
  end

  def [](index)
    @string.slice(self.begin(index), self.end(index) - self.begin(index))
  end
end