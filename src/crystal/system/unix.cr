# :nodoc:
module Crystal::System
  def self.retry_with_buffer(function_name, max_buffer, &)
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
end
