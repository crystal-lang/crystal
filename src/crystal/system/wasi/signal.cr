module Crystal::System::Signal
  def self.trap(signal, handler) : Nil
    raise NotImplementedError.new("Crystal::System::Signal.trap")
  end

  def self.trap_handler?(signal)
    raise NotImplementedError.new("Crystal::System::Signal.trap_handler?")
  end

  def self.reset(signal) : Nil
    raise NotImplementedError.new("Crystal::System::Signal.reset")
  end

  def self.ignore(signal) : Nil
    raise NotImplementedError.new("Crystal::System::Signal.ignore")
  end
end
