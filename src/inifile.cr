class IniFile
  # Parses INI-style configuration from the given string.
  #
  # ```
  # IniFile.load("[foo]\na = 1") # => {"foo" => {"a" => "1"}}
  # ```
  def self.load(str)
    ini = {} of String => Hash(String, String)

    section = ""
    str.lines.each do |line|
      if line =~ /\s*(.*[^\s])\s*=\s*(.*[^\s])/
        ini[section] ||= {} of String => String if section == ""
        ini[section][$1] = $2
      elsif line =~ /\[(.*)\]/
        section = $1
        ini[section] = {} of String => String
      end
    end
    ini
  end
end
