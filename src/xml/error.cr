module XML
  class Error < Exception
    getter line_number

    def initialize(message, @line_number)
      super(message)
    end

    def to_s(io)
      io << @message
      io << " at line "
      io << @line_number
    end
  end
end
