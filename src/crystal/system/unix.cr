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

  # Return the password file entry for a given system user id
  #
  # Returns nil if there is no matching entry is found and
  # raises a RuntimeError on failure
  def self.getpwuid(id : UInt32) : LibC::Passwd?
    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    ret = nil
    System.retry_with_buffer("getpwuid_r", GETPW_R_SIZE_MAX) do |buf|
      ret = LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    return pwd if pwd_pointer

    if ret && ret != 0
      raise RuntimeError.from_os_error("getpwuid_r", Errno.new(ret))
    end
  end
end
