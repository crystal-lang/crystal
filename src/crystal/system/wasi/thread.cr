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

  def self.sleep(time : ::Time::Span) : Nil
    req = uninitialized LibC::Timespec
    req.tv_sec = typeof(req.tv_sec).new(time.seconds)
    req.tv_nsec = typeof(req.tv_nsec).new(time.nanoseconds)

    loop do
      return if LibC.nanosleep(pointerof(req), out rem) == 0
      raise RuntimeError.from_errno("nanosleep() failed") unless Errno.value == Errno::EINTR
      req = rem
    end
  end

  private def system_join : Exception?
    NotImplementedError.new("Crystal::System::Thread#system_join")
  end

  private def system_close
  end

  private def stack_address : Void*
    # TODO: Implement
    Pointer(Void).null
  end

  def self.init_suspend_resume : Nil
  end

  private def system_suspend : Nil
    raise NotImplementedError.new("Crystal::System::Thread.system_suspend")
  end

  private def system_wait_suspended : Nil
    raise NotImplementedError.new("Crystal::System::Thread.system_wait_suspended")
  end

  private def system_resume : Nil
    raise NotImplementedError.new("Crystal::System::Thread.system_resume")
  end
end
