lib C
  struct Regex
    re_magic : Int
    re_endp : String
    re_guts : Long
  end

  struct Regmatch
    rm_so : Long
    rm_eo : Long
  end

  fun regcomp(re : Regex, str : String, flags : Int) : Int
  fun regexec(re : Regex, str : String, nmatch : Int, pmatch : Regmatch, flags : Int) : Int
end

class Regexp
  def initialize(str)
    @re = C::Regex.new
    unless C.regcomp(@re, str, 1) == 0
      puts "Error compiling regex: #{str}"
      exit 1
    end
  end

  def match(str)
    match = C::Regmatch.new
    if C.regexec(@re, str, 1, match, 0) != 0
      nil
    else
      MatchData.new self, str, [match]
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
    @matches[n].rm_so
  end

  def end(n)
    @matches[n].rm_eo
  end

  def string
    @string
  end

  def [](index)
    m = @matches[index]
    @string.slice(m.rm_so.to_i, (m.rm_eo - m.rm_so).to_i)
  end
end