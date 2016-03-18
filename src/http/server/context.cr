class HTTP::Server
  # Instances of this class are passed to an `HTTP::Server` handler.
  class Context
    # The `HTTP::Request` to process.
    getter request : Request

    # The `HTTP::Response` to configure and write to.
    getter response : Response

    # :nodoc:
    def initialize(@request : Request, @response : Response)
    end
  end
end
