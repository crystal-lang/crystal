class Fiber
  # :nodoc:
  struct Waiting
    include Crystal::PointerLinkedList::Node

    def initialize(@fiber : Fiber)
    end

    def enqueue : Nil
      @fiber.enqueue
    end
  end
end
