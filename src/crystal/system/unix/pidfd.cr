{% skip_file unless flag?(:linux) %}

require "c/linux/pidfd"

module Crystal::System::Pidfd
  @@supported_flag = false
  @@supported = false

  def self.supported?
    {% if flag?(:interpreted) %}
      false
    {% else %}
      Crystal.once(pointerof(@@supported_flag)) do
        pidfd = Syscall.pidfd_open(LibC.getpid, 0_u32)
        unless pidfd < 0
          LibC.close(pidfd)
          @@supported = true
        end
      end
      @@supported
    {% end %}
  end

  def self.open(pid, flags)
    {% unless flag?(:interpreted) %}
      ret = Syscall.pidfd_open(pid, flags.to_u32)
      raise RuntimeError.from_os_error("pidfd_open", Errno.new(-ret)) if ret < 0
      ret
    {% end %}
  end

  def self.close(pidfd)
    {% unless flag?(:interpreted) %}
      LibC.close(pidfd)
    {% end %}
  end

  def self.exists?(pidfd)
    {% unless flag?(:interpreted) %}
      case ret = Syscall.pidfd_send_signal(pidfd, 0, Pointer(LibC::SiginfoT).null, 0_u32)
      when 0
        true
      when LibC::EBADF, Errno::ESRCH
        false
      when LibC::EPERM
        true
      else
        raise RuntimeError.from_os_error("pidfd_send_signal", Errno.new(-ret))
      end
    {% end %}
  end

  def self.send_signal(pidfd, signal)
    {% unless flag?(:interpreted) %}
      ret = Syscall.pidfd_send_signal(pidfd, signal, Pointer(LibC::SiginfoT).null, 0_u32)
      raise RuntimeError.from_os_error("kill", Errno.new(-ret)) if ret < 0 && ret != -LibC::EBADF
    {% end %}
  end
end
