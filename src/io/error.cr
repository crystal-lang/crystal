class IO
  class Error < Exception
    include SystemError

    getter target : String?

    protected def self.build_message(message, *, target : File) : String
      build_message(message, target: target.path)
    end

    protected def self.build_message(message, *, target : Nil) : String
      message
    end

    protected def self.build_message(message, *, target) : String
      "#{message} (#{target})"
    end

    def initialize(message : String? = nil, cause : Exception? = nil, *, target = nil)
      @target = target.try(&.to_s)

      super message, cause
    end
  end

  # Raised when an `IO` operation times out.
  #
  # ```
  # STDIN.read_timeout = 1.second
  # STDIN.gets # raises IO::TimeoutError (after 1 second)
  # ```
  class TimeoutError < Error
  end

  # Raised when an `IO` operation is attempted on a closed stream.
  class ClosedError < Error
    def initialize(message = "Closed stream", cause : Exception? = nil, *, target = nil)
      super(message, cause: cause, target: target)
    end
  end

  class EOFError < Error
    def initialize(message = "End of file reached")
      super(message)
    end
  end
end
