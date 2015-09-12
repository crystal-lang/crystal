require "./*"

module YAML
  # Exception thrown on a YAML parse error.
  class ParseException < Exception
    getter line_number
    getter column_number

    def initialize(message, @line_number, @column_number)
      super "#{message} at #{@line_number}:#{@column_number}"
    end
  end

  alias Type = String | Hash(Type, Type) | Array(Type) | Nil
  alias EventKind = LibYAML::EventType

  def self.load(data)
    parser = YAML::Parser.new(data)
    begin
      parser.parse
    ensure
      parser.close
    end
  end

  def self.load_all(data)
    parser = YAML::Parser.new(data)
    begin
      parser.parse_all
    ensure
      parser.close
    end
  end
end
