module Crystal::System
  def self.file_descriptor_limit
    rlimit = uninitialized LibC::Rlimit
    if LibC.getrlimit(LibC::RLIMIT_NOFILE, pointerof(rlimit)) != 0
      raise RuntimeError.from_errno("Could not get rlimit")
    end
    {rlimit.rlim_cur, rlimit.rlim_max}
  end

  def self.file_descriptor_limit=(limit) : Nil
    rlimit = LibC::Rlimit.new
    rlimit.rlim_cur = limit
    rlimit.rlim_max = limit
    if LibC.setrlimit(LibC::RLIMIT_NOFILE, pointerof(rlimit)) != 0
      raise RuntimeError.from_errno("Could not set rlimit")
    end
  end
end
