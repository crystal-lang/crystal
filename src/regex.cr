lib PCRE("pcre")
  type Pcre : Void*
  fun compile = pcre_compile(pattern : UInt8*, options : Int32, errptr : UInt8**, erroffset : Int32*, tableptr : Void*) : Pcre
  fun exec = pcre_exec(code : Pcre, extra : Void*, subject : UInt8*, length : Int32, offset : Int32, options : Int32,
                ovector : Int32*, ovecsize : Int32) : Int32
  fun full_info = pcre_fullinfo(code : Pcre, extra : Void*, what : Int32, where : Void*) : Int32
  fun get_named_substring = pcre_get_named_substring(code : Pcre, subject : UInt8*, ovector : Int32*, string_count : Int32, string_name : UInt8*, string_ptr : UInt8**) : Int32

  INFO_CAPTURECOUNT = 2
end

class Regex
  IGNORE_CASE = 1
  MULTILINE = 4
  EXTENDED = 8
  ANCHORED = 16

  getter source

  def initialize(@source, modifiers = 0)
    errptr = Pointer(UInt8).malloc(0)
    erroffset = 1
    @re = PCRE.compile(@source, modifiers, pointerof(errptr), pointerof(erroffset), nil)
    if @re == 0
      raise "#{String.new(errptr)} at #{erroffset}"
    end
    @captures = 0
    PCRE.full_info(@re, nil, PCRE::INFO_CAPTURECOUNT, pointerof(@captures) as Void*)
  end

  def match(str, pos = 0, options = 0)
    ovector_size = (@captures + 1) * 3
    ovector = Pointer(Int32).malloc(ovector_size * 4)
    ret = PCRE.exec(@re, nil, str, str.length, pos, options, ovector, ovector_size)
    if ret > 0
      $~ = MatchData.new(self, @re, str, pos, ovector, @captures)
    else
      $~ = MatchData::EMPTY
      nil
    end
  end

  def ===(other : String)
    !match(other).nil?
  end

  def to_s(io)
    io << "/"
    io << source
    io << "/"
  end
end

class MatchData
  EMPTY = MatchData.new("", nil, "", 0, Pointer(Int32).null, 0)

  getter regex
  getter length
  getter string

  def initialize(@regex, @code, @string, @pos, @ovector, @length)
  end

  def begin(n)
    check_index_out_of_bounds n

    @ovector[n * 2]
  end

  def end(n)
    check_index_out_of_bounds n

    @ovector[n * 2 + 1]
  end

  def [](n)
    check_index_out_of_bounds n

    start = @ovector[n * 2]
    finish = @ovector[n * 2 + 1]
    @string[start, finish - start]
  end

  def [](group_name : String)
    PCRE.get_named_substring(@code.not_nil!, @string, @ovector, @length + 1, group_name, out value)
    String.new(value)
  end

  def to_s(io)
    io << "MatchData("
    @string.inspect(io)
    if length > 0
      io << " ["
      length.times do |i|
        io << ", " if i > 0
        self[i + 1].inspect(io)
      end
      io << "]"
    end
    io << ")"
  end

  # private

  def check_index_out_of_bounds(index)
    raise IndexOutOfBounds.new if index > @length
  end
end

$~ = MatchData::EMPTY
