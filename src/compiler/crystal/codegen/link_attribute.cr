module Crystal
  class LinkAttribute
    getter :lib
    getter :ldflags
    getter :framework

    def initialize(@lib = nil, @ldflags = nil, @static = false, @framework = nil)
    end

    def static?
      @static
    end
  end
end

