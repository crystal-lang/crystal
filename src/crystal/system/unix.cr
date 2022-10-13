# :nodoc:
module Crystal::System
  GETPW_R_SIZE_MAX = 1024 * 16

  def self.retry_with_buffer(function_name, max_buffer)
    initial_buf = uninitialized UInt8[1024]
    buf = initial_buf

    while (ret = yield buf.to_slice) != 0
      case ret
      when LibC::ENOENT, LibC::ESRCH, LibC::EBADF, LibC::EPERM
        return nil
      when LibC::ERANGE
        raise RuntimeError.from_errno(function_name) if buf.size >= max_buffer
        buf = Bytes.new(buf.size * 2)
      else
        raise RuntimeError.from_errno(function_name)
      end
    end
  end

  def self.getpwuid(id : UInt32)
    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    System.retry_with_buffer("getpwuid_r", GETPW_R_SIZE_MAX) do |buf|
      LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    pwd if pwd_pointer
  end
end
