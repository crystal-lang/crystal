module Crystal
  class VirtualFile
    @macro :: Macro
    getter :macro

    @source :: String
    getter :source

    def initialize(@macro, @source)
    end

    def to_s
      "expanded macro"
    end
  end
end
