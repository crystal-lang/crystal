module IO
  class Error < Exception
  end

  class EOFError < Error
    def initialize(message = "end of file reached")
      super(message)
    end
  end
end
