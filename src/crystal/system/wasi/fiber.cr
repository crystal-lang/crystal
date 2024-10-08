module Crystal::System::Fiber
  def self.allocate_stack(stack_size, protect) : Void*
    LibC.malloc(stack_size)
  end

  def self.reset_stack(stack : Void*, stack_size : Int, protect : Bool) : Nil
  end

  def self.free_stack(stack : Void*, stack_size) : Nil
    LibC.free(stack)
  end
end
