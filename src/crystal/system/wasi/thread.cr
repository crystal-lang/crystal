module Crystal::System::Thread
  alias Handle = Nil

  def self.new_handle(thread_obj : ::Thread) : Handle
    raise NotImplementedError.new("Crystal::System::Thread.new_handle")
  end

  def self.current_handle : Handle
    nil
  end

  def self.yield_current : Nil
    raise NotImplementedError.new("Crystal::System::Thread.yield_current")
  end

  class_property current_thread : ::Thread { ::Thread.new }

  private def system_join : Exception?
    NotImplementedError.new("Crystal::System::Thread#system_join")
  end

  private def system_close
  end

  private def stack_address : Void*
    # TODO: Implement
    Pointer(Void).null
  end
end
