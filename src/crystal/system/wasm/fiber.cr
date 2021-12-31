module Crystal::System::Fiber
  def self.allocate_stack(stack_size) : Void*
    LibC.malloc(stack_size)
  end

  def self.free_stack(stack : Void*, stack_size) : Nil
    LibC.free(stack)
  end
end
