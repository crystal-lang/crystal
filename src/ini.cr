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
  # INI.build({"foo" => {"a" => "1"}}, true) # => "[foo]\na = 1\n\n"
  # ```
  def self.build(ini, space : Bool = false) : String
    String.build { |str| build str, ini, space }
  end

  # Appends INI data to the given IO.
  def self.build(io : IO, ini, space : Bool = false)
    ini.each do |section, contents|
      io << '[' << section << "]\n"
      contents.each do |key, value|
        io << key << (space ? " = " : '=') << value << '\n'
      end
      io.puts
    end
  end
end
