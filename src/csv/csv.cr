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

  def self.each_row(string_or_io)
    Parser.new(string_or_io).each_row do |row|
      yield row
    end
  end

  def self.each_row(string_or_io)
    Parser.new(string_or_io).each_row
  end

  def self.build
    String.build do |io|
      build(io) { |builder| yield builder }
    end
  end

  def self.build(io : IO)
    builder = Builder.new(io)
    yield builder
  end
end
