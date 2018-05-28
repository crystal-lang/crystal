class IO
  class Error < Exception
  end

  class EOFError < Error
    def initialize(message = "End of file reached")
      super(message)
    end
  end
end
