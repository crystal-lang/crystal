class INI
  # Parses INI-style configuration from the given string.
  #
  # ```
  # INI.parse("[foo]\na = 1") # => {"foo" => {"a" => "1"}}
  # ```
  def self.parse(str) : Hash(String, Hash(String, String))
    ini = {} of String => Hash(String, String)

    section = ""
    str.each_line do |line|
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
