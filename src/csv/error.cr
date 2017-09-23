require "csv"

class CSV
  # Raises when an error related to a CSV is found.
  class Error < Exception
  end

  # Raised when an error is encountered during CSV parsing.
  class MalformedCSVError < Error
    getter line_number : Int32
    getter column_number : Int32

    def initialize(message, @line_number, @column_number)
      super("#{message} at #{@line_number}:#{@column_number}")
    end
  end
end
