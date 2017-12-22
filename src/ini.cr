class INI
  alias INIValue = String | Int64 | Float64 | Bool

  # Parses INI-style configuration from the given string.
  #
  # Booleans ("true", "false"), integers ("1", "432148765"),
  # and floats ("3.14", "1.6667") are all coerced into their
  # respective types (`Bool`, `Int64`, and `Float64`).
  #
  # ```
  # INI.parse("[foo]\na = 1") # => {"foo" => {"a" => 1}}
  # ```
  def self.parse(str) : Hash(String, Hash(String, INIValue))
    ini = {} of String => Hash(String, INIValue)

    section = ""
    str.each_line do |line|
      if line =~ /\s*(.*[^\s])\s*=\s*(.*[^\s])/
        ini[section] ||= {} of String => INIValue if section == ""
        ini[section][$1] = coerce $2
      elsif line =~ /\[(.*)\]/
        section = $1
        ini[section] = {} of String => INIValue
      end
    end
    ini
  end

  private def self.coerce(value)
    case value
    when "true"           then true
    when "false"          then false
    when /\A-?\d+\z/      then value.to_i64
    when /\A-?\d+\.\d+\z/ then value.to_f64
    else                       value
    end
  end
end
