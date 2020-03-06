class IO
  class Error < Exception
    include SystemError
  end

  class EOFError < Error
    def initialize(message = "End of file reached")
      super(message)
    end
  end
end
