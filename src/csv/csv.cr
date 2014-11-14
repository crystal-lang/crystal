require "./**"

module CSV
  class MalformedCSVError < Exception
    getter line_number
    getter column_number

    def initialize(message, @line_number, @column_number)
      super("#{message} at #{@line_number}:#{@column_number}")
    end
  end

  def self.parse(string_or_io)
    Parser.new(string_or_io).parse
  end

  def self.build
    io = StringIO.new
    build(io) { |builder| yield builder }
    io.to_s
  end

  def self.build(io : IO)
    builder = Builder.new(io)
    yield builder
  end
end
