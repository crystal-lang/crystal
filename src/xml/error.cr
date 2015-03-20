module XML
  class Error < Exception
    getter line_number

    def initialize(message, @line_number)
      super(message)
    end
  end
end
