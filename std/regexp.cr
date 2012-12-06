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

  fun regcomp(re : ptr Regex, str : String, flags : Int) : Int
  fun regexec(re : ptr Regex, str : String, nmatch : Long, pmatch : ptr Regmatch, flags : Int) : Int
end

class Regexp
  def initialize(str)
    @re = Pointer.malloc(100).as(C::Regex)
    unless C.regcomp(@re, str, 1) == 0
      puts "Error compiling regex: #{str}"
      exit 1
    end
  end

  def match(str)
    matches = Pointer.malloc(16 * (@re.value.nsub + 1)).as(C::Regmatch)
    if C.regexec(@re, str, @re.value.nsub + 1, matches, 0) != 0
      nil
    else
      MatchData.new self, str, matches
    end
  end
end

class MatchData
  def initialize(regexp, string, matches)
    @regexp = regexp
    @string = string
    @matches = matches
  end

  def regexp
    @regexp
  end

  def begin(n)
    @matches[n].start_match
  end

  def end(n)
    @matches[n].end_match
  end

  def string
    @string
  end

  def [](index)
    m = @matches[index]
    @string.slice(m.start_match.to_i, (m.end_match - m.start_match).to_i)
  end
end