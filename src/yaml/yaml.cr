require "./*"

module Yaml
  alias Type = String | Hash(Type, Type) | Array(Type) | Nil

  def self.load(data)
    parser = Yaml::Parser.new(data)
    begin
      parser.parse
    ensure
      parser.close
    end
  end

  def self.load_all(data)
    parser = Yaml::Parser.new(data)
    begin
      parser.parse_all
    ensure
      parser.close
    end
  end
end
