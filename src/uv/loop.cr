module UV
  class Loop
    DEFAULT = Loop.new(LibUV.default_loop)

    def initialize(@loop = LibUV.loop_new)
    end

    def run
      LibUV.run(@loop, LibUV::RunMode::DEFAULT)
    end

    def to_unsafe
      @loop
    end
  end
end
