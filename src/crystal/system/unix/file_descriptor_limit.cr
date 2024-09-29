module Crystal::System
  def self.file_descriptor_limit : Tuple(Int32, Int32)
    rlimit = uninitialized LibC::Rlimit
    if LibC.getrlimit(LibC::RLIMIT_NOFILE, pointerof(rlimit)) != 0
      raise RuntimeError.from_errno("Could not get rlimit")
    end
    {rlimit.rlim_cur.to_i32, rlimit.rlim_max.to_i32}
  end

  def self.file_descriptor_limit=(limit : Int) : Nil
    rlimit = LibC::Rlimit.new
    rlimit.rlim_cur = limit
    rlimit.rlim_max = limit
    if LibC.setrlimit(LibC::RLIMIT_NOFILE, pointerof(rlimit)) != 0
      raise RuntimeError.from_errno("Could not set rlimit")
    end
  end
end
