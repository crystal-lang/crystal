module Json
  class ParseException < Exception
    getter line_number
    getter column_number

    def initialize(message, @line_number, @column_number)
      super "#{message} at #{@line_number}:#{@column_number}"
    end
  end

  alias Type = Nil | Bool | Int64 | Float64 | String | Array(Type) | Hash(String, Type)

  def self.parse(string_or_io)
    Parser.new(string_or_io).parse
  end
end

require "./*"
