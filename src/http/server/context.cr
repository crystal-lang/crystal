class HTTP::Server
  class Context
    getter request
    getter response

    def initialize(@request : Request, @response : Response)
    end
  end
end
