module Crystal
  class LinkAttribute
    getter :lib
    getter :ldflags

    def initialize(@lib = nil, @ldflags = nil, @static = false)
    end

    def static?
      @static
    end
  end
end

