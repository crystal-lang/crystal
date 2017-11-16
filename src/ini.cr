class INI
  # Parses INI-style configuration from the given string.
  #
  # ```
  # INI.parse("[foo]\na = 1") # => {"foo" => {"a" => "1"}}
  # ```
  def self.parse(str) : Hash(String, Hash(String, String))
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

  # Generates an INI-style configuration from a given hash.
  #
  # ```
  # INI.build({"foo" => {"a" => "1"}}, " ") # => "[foo]\na = 1\n\n"
  # ```
  def self.build(ini, space : String = "") : String
    String.build do |str|
      build str, ini, space
    end
  end

  # Appends INI data to the given IO.
  #
  def self.build(io : IO, ini, space : String = "")
    ini.each do |section, contents|
      io << '[' << section << "]\n"
      contents.each do |key, value|
        io << key << space << '=' << space << value << '\n'
      end
      io.puts
    end
  end
end
