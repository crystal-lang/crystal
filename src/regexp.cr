lib PCRE("pcre")
  type Pcre : Void*
  fun compile = pcre_compile(pattern : Char*, options : Int32, errptr : Char**, erroffset : Int32*, tableptr : Void*) : Pcre
  fun exec = pcre_exec(code : Pcre, extra : Void*, subject : Char*, length : Int32, offset : Int32, options : Int32,
                ovector : Int32*, ovecsize : Int32) : Int32
  fun full_info = pcre_fullinfo(code : Pcre, extra : Void*, what : Int32, where : Void*) : Int32

  INFO_CAPTURECOUNT = 2
end

class Regexp
  ANCHORED = 16

  def initialize(str)
    @source = str
    errptr = Pointer(Char).malloc(0)
    erroffset = 1
    @re = PCRE.compile(str, 0, pointerof(errptr), pointerof(erroffset), nil)
    if @re == 0
      raise "#{String.new(errptr)} at #{erroffset}"
    end
    @captures = 0
    PCRE.full_info(@re, nil, PCRE::INFO_CAPTURECOUNT, pointerof(@captures).as(Void))
  end

  def match(str, pos = 0, options = 0)
    ovector_size = (@captures + 1) * 3
    ovector = Pointer(Int32).malloc(ovector_size * 4)
    ret = PCRE.exec(@re, nil, str, str.length, pos, options, ovector, ovector_size)
    if ret > 0
      $~ = MatchData.new(self, str, pos, ovector, @captures)
    else
      $~ = MatchData::EMPTY
      nil
    end
  end

  def ===(other : String)
    !match(other).nil?
  end

  def source
    @source
  end

  def to_s
    "/#{source}/"
  end
end

class MatchData
  EMPTY = MatchData.new("", "", 0, Pointer(Int32).malloc(0), 0)

  def initialize(@regex, @string, @pos, @ovector, @length)
  end

  def length
    @length
  end

  def regex
    @regex
  end

  def begin(n)
    check_index_out_of_bounds n

    @ovector[n * 2]
  end

  def end(n)
    check_index_out_of_bounds n

    @ovector[n * 2 + 1]
  end

  def string
    @string
  end

  def [](n)
    check_index_out_of_bounds n

    start = @ovector[n * 2]
    finish = @ovector[n * 2 + 1]
    @string[start, finish - start]
  end

  # private

  def check_index_out_of_bounds(index)
    raise IndexOutOfBounds.new if index > @length
  end
end

$~ = MatchData::EMPTY
