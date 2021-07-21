require "c/sys/mman"

module Crystal::System::Fiber
  def self.allocate_stack(stack_size) : Void*
    raise NotImplementedError.new("Crystal::System::Fiber.allocate_stack")
  end

  def self.free_stack(stack : Void*, stack_size) : Nil
    raise NotImplementedError.new("Crystal::System::Fiber.free_stack")
  end
end
