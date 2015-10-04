require "./**"

# Provides methods and classes for parsing and generating CSV
# (comma-separated values) strings.
#
# This module conforms to [RFC 4180](https://tools.ietf.org/html/rfc4180).
module CSV
  # Raised when an error is encountered during CSV parsing.
  class MalformedCSVError < Exception
    getter line_number
    getter column_number

    def initialize(message, @line_number, @column_number)
      super("#{message} at #{@line_number}:#{@column_number}")
    end
  end

  # Parses a CSV or IO into an array.
  #
  # ```
  # CSV.parse("one,two\nthree") #=> [["one", "two"], ["three"]]
  # ```
  def self.parse(string_or_io : String | IO, header_row = false) : Array(Array(String)) | Array(Hash(String,String))
    Parser.new(string_or_io, header_row).parse
  end

  # Yields each of a CSV's rows as an `Array(String)`.
  #
  # ```
  # CSV.each_row("one,two\nthree") do |row|
  #   puts row
  # end
  # ```
  #
  # Output:
  #
  # ```
  # ["one", "two"]
  # ["three"]
  # ```
  def self.each_row(string_or_io : String | IO)
    Parser.new(string_or_io).each_row do |row|
      yield row
    end
  end

  # Yields each of a CSV's rows as an `Hash(String,String)`.
  #
  # ```
  # CSV.each_row_with_header("name,age\nharis,21\nbobby,35") do |row|
  #   puts row
  # end
  # ```
  #
  # Output:
  #
  # ```
  # {"name" => "haris", "age" => "21"}
  # {"name" => "bobby", "age" => "35"}
  # ```
  def self.each_row_with_header(string_or_io : String | IO)
    Parser.new(string_or_io, header_row = true).each_row_with_header do |row|
      yield row
    end
  end

  # Returns an `Iterator` of `Array(String)` over a CSV's rows.
  #
  # ```
  # rows = CSV.each_row("one,two\nthree")
  # rows.next #=> ["one", "two"]
  # rows.next #=> ["three"]
  # ```
  def self.each_row(string_or_io : String | IO)
    Parser.new(string_or_io).each_row
  end

  # Returns an `Iterator` of `Hash(String,String)` over a CSV's rows.
  #
  # ```
  # rows = CSV.each_row_with_header("name,age\nharis,21\nbobby,35")
  # rows.next #=> {"name" => "haris", "age" => "21"}
  # rows.next #=> {"name" => "bobby", "age" => "35"}
  # ```
  def self.each_row_with_header(string_or_io : String | IO)
    Parser.new(string_or_io, header_row = true).each_row_with_header
  end

  # Builds a CSV. This yields a `CSV::Builder` to the given block.
  #
  # ```
  # CSV.build do |csv|
  #   csv.row "one", "two"
  #   csv.row "three"
  # end
  # result #=> "one,two\nthree"
  # ```
  def self.build : String
    String.build do |io|
      build(io) { |builder| yield builder }
    end
  end

  # Appends CSV data to the given IO. This yields a `CSV::Builder`
  # that writes to the given IO.
  #
  # ```
  # io = StringIO.new
  # io.puts "HEADER"
  # CSV.build(io) do |csv|
  #   csv.row "one", "two"
  #   csv.row "three"
  # end
  # io.to_s #=> "HEADER\none,two\nthree"
  # ```
  def self.build(io : IO)
    builder = Builder.new(io)
    yield builder
  end
end
