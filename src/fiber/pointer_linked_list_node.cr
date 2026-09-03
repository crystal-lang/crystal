require "crystal/pointer_linked_list"

class Fiber
  # :nodoc:
  struct PointerLinkedListNode
    include Crystal::PointerLinkedList::Node

    def initialize(@fiber : Fiber)
    end

    def enqueue : Nil
      @fiber.enqueue
    end
  end
end
