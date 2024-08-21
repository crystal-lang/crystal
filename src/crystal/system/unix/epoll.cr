{% skip_file unless flag?(:linux) || flag?(:solaris) %}

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

  def add(fd : Int32, events : UInt32, ptr : Pointer) : Nil
    epoll_event = uninitialized LibC::EpollEvent
    epoll_event.events = events
    epoll_event.data.ptr = ptr
    add(fd, pointerof(epoll_event))
  end

  def modify(fd : Int32, epoll_event : LibC::EpollEvent*) : Nil
    if LibC.epoll_ctl(@epfd, LibC::EPOLL_CTL_MOD, fd, epoll_event) == -1
      raise RuntimeError.from_errno("epoll_ctl(EPOLL_CTL_MOD)")
    end
  end

  def modify(fd : Int32, events : UInt32, ptr : Pointer) : Nil
    epoll_event = uninitialized LibC::EpollEvent
    epoll_event.events = events
    epoll_event.data.ptr = ptr
    modify(fd, pointerof(epoll_event))
  end

  # OPTIMIZE: if we added a fd only when it would block (instead of immediately
  # on open/accept), then maybe we could spare the errno checks for EPERM and
  # ENOENT (?)
  def delete(fd : Int32) : Nil
    if LibC.epoll_ctl(@epfd, LibC::EPOLL_CTL_DEL, fd, nil) == -1
      raise RuntimeError.from_errno("epoll_ctl(EPOLL_CTL_DEL)") unless Errno.value.in?(Errno::EPERM, Errno::ENOENT)
    end
  end

  # `timeout` is in milliseconds; -1 will wait indefinitely; 0 will never wait.
  def wait(events : Slice(LibC::EpollEvent), timeout : Int32) : Slice(LibC::EpollEvent)
    count = LibC.epoll_wait(@epfd, events.to_unsafe, events.size, timeout)
    raise RuntimeError.from_errno("epoll_wait") if count == -1 && Errno.value != Errno::EINTR
    events[0, count.clamp(0..)]
  end

  def close : Nil
    LibC.close(@epfd)
  end
end
