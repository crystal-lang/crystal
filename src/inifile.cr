class IniFile
  def self.load(str)
    ini = {} of String => Hash(String, String)

    section = ""
    str.lines.each do |line|
      if line =~ /\s*(.*[^\s])\s*=\s*(.*[^\s])/
        ini[section] ||= {} of String => String if section == ""
        ini[section][MatchData.last[1]] = MatchData.last[2]
      elsif line =~ /\[(.*)\]/
        section = MatchData.last[1]
        ini[section] = {} of String => String
      end
    end
    ini
  end
end
