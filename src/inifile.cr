class IniFile
  def self.load(str)
    ini = Hash(String, Hash(String, String)).new do |h, k|
      h[k] = {} of String => String
    end

    section = ""
    str.lines.each do |line|
      if line =~ /\s*(.*[^\s])\s*=\s*(.*[^\s])/
        ini[section][$1] = $2
      elsif line =~ /\[(.*)\]/
        section = $1
      end
    end
    ini
  end
end
