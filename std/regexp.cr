lib C
  struct Regex
    magic : Int
    nsub : Long
    endp : String
    guts : Long
  end

  struct Regmatch
    start_match : Long
    end_match : Long
  end

  fun regcomp(re : ptr Regex, str : ptr Char, flags : Int) : Int
  fun regexec(re : ptr Regex, str : ptr Char, nmatch : Long, pmatch : ptr Regmatch, flags : Int) : Int
end

class Regexp
  def initialize(str)
    @re = C::Regex.new
    unless C.regcomp(@re.ptr, str.cstr, 1) == 0
      puts "Error compiling regex: #{str}"
      exit 1
    end
  end

  def match(str, pos = 0)
    matches = Pointer.malloc(16 * (@re.nsub + 1)).as(C::Regmatch)
    if C.regexec(@re.ptr, str.cstr + pos, @re.nsub + 1, matches, 0) != 0
      nil
    else
      MatchData.new self, str, pos, matches
    end
  end
end

class MatchData
  def initialize(regexp, string, pos, matches)
    @regexp = regexp
    @string = string
    @pos = pos
    @matches = matches
  end

  def regexp
    @regexp
  end

  def begin(n)
    @matches[n].start_match + @pos
  end

  def end(n)
    @matches[n].end_match + @pos
  end

  def string
    @string
  end

  def [](index)
    m = @matches[index]
    @string.slice(m.start_match.to_i + @pos, (m.end_match - m.start_match).to_i + @pos)
  end
end