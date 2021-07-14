require "c/sys/mman"

module Crystal::System::Fiber
  def self.allocate_stack(stack_size) : Void*
    raise RuntimeError.new("Cannot allocate new fiber stack")
  end

  def self.free_stack(stack : Void*, stack_size) : Nil
  end
end
