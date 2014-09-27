module Crystal
  class VirtualFile
    getter :macro
    getter :source
    getter :expanded_location

    def initialize(@macro, @source, @expanded_location)
    end

    def to_s
      "expanded macro"
    end

    def to_s(io)
      io << to_s
    end
  end
end
