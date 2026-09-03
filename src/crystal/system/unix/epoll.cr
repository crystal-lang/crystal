require "c/sys/epoll"

struct Crystal::System::Epoll
  def initialize
    @epfd = LibC.epoll_create1(LibC::EPOLL_CLOEXEC)
    raise RuntimeError.from_errno("epoll_create1") if @epfd == -1
  end

  def fd : Int32
    @epfd
  end

  def add(fd : Int32, epoll_event : LibC::EpollEvent*) : Nil
    if LibC.epoll_ctl(@epfd, LibC::EPOLL_CTL_ADD, fd, epoll_event) == -1
      raise RuntimeError.from_errno("epoll_ctl(EPOLL_CTL_ADD)") unless Errno.value == Errno::EPERM
    end
  end

  def add(fd : Int32, events : UInt32, u64 : UInt64) : Nil
    epoll_event = uninitialized LibC::EpollEvent
    epoll_event.events = events
    epoll_event.data.u64 = u64
    add(fd, pointerof(epoll_event))
  end

  def modify(fd : Int32, epoll_event : LibC::EpollEvent*) : Nil
    if LibC.epoll_ctl(@epfd, LibC::EPOLL_CTL_MOD, fd, epoll_event) == -1
      raise RuntimeError.from_errno("epoll_ctl(EPOLL_CTL_MOD)")
    end
  end

  def delete(fd : Int32) : Nil
    delete(fd) do
      raise RuntimeError.from_errno("epoll_ctl(EPOLL_CTL_DEL)")
    end
  end

  def delete(fd : Int32, &) : Nil
    if LibC.epoll_ctl(@epfd, LibC::EPOLL_CTL_DEL, fd, nil) == -1
      yield
    end
  end

  # `timeout` is in milliseconds; -1 will wait indefinitely; 0 will never wait.
  def wait(events : Slice(LibC::EpollEvent), timeout : Int32) : Slice(LibC::EpollEvent)
    count = 0

    loop do
      count = LibC.epoll_wait(@epfd, events.to_unsafe, events.size, timeout)
      break unless count == -1

      if Errno.value == Errno::EINTR
        # retry when waiting indefinitely, return otherwise
        break unless timeout == -1
      else
        raise RuntimeError.from_errno("epoll_wait")
      end
    end

    events[0, count.clamp(0..)]
  end

  def close : Nil
    LibC.close(@epfd)
  end
end
