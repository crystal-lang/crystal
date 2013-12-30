module Crystal
  class VirtualFile
    getter :macro
    getter :source

    def initialize(@macro, @source)
    end

    def to_s
      "expanded macro"
    end
  end
end
