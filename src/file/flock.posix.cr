# TODO: use fcntl/lockf instead of flock (which doesn't lock over NFS)
# TODO: always use non-blocking locks, yield fiber until resource becomes available

lib LibC
  @[Flags]
  enum FlockOp
    SH = 0x1
    EX = 0x2
    NB = 0x4
    UN = 0x8
  end

  fun flock(fd : Int, op : FlockOp) : Int
end

class File
  def flock_shared(blocking = true)
    flock_shared blocking
    begin
      yield
    ensure
      flock_unlock
    end
  end

  # Place a shared advisory lock. More than one process may hold a shared lock for a given file at a given time.
  # `Errno::EWOULDBLOCK` is raised if *blocking* is set to `false` and an existing exclusive lock is set.
  def flock_shared(blocking = true)
    flock LibC::FlockOp::SH, blocking
  end

  def flock_exclusive(blocking = true)
    flock_exclusive blocking
    begin
      yield
    ensure
      flock_unlock
    end
  end

  # Place an exclusive advisory lock. Only one process may hold an exclusive lock for a given file at a given time.
  # `Errno::EWOULDBLOCK` is raised if *blocking* is set to `false` and any existing lock is set.
  def flock_exclusive(blocking = true)
    flock LibC::FlockOp::EX, blocking
  end

  # Remove an existing advisory lock held by this process.
  def flock_unlock
    flock LibC::FlockOp::UN
  end

  private def flock(op : LibC::FlockOp, blocking : Bool = true)
    op |= LibC::FlockOp::NB unless blocking

    if LibC.flock(@fd, op) != 0
      raise Errno.new("flock")
    end

    nil
  end
end
