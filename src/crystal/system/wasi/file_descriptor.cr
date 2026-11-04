require "../unix/file_descriptor"

# :nodoc:
module Crystal::System::FileDescriptor
  def self.from_stdio(fd)
    if Crystal.stdio_closed?(fd)
      IO::FileDescriptor.new(closed: true)
    else
      IO::FileDescriptor.new(fd).tap do |io|
        if io.tty?
          # Make prompts visible even when they don't end with a newline.
          io.sync = true
        else
          io.flush_on_newline = true
        end
      end
    end
  end

  {% unless flag?(:wasip3) %}
    def self.get_blocking(fd : Handle)
      raise NotImplementedError.new("Crystal::System::FileDescriptor.get_blocking requires wasip3 or later")
    end

    def self.set_blocking(fd : Handle, value : Bool)
      raise NotImplementedError.new("Crystal::System::FileDescriptor.set_blocking requires wasip3 or later")
    end
  {% end %}

  protected def system_blocking_init(blocking : Bool?)
  end

  private def system_reopen(other : IO::FileDescriptor)
    {% if flag?(:wasip1) %}
      raise NotImplementedError.new "Crystal::System::FileDescriptor#system_reopen requires wasip2 or later"
    {% else %}
      if LibC.dup2(other.fd, fd) == -1
        raise IO::Error.from_errno("Could not reopen file descriptor")
      end

      @closed = false
      event_loop.reopened(self)
    {% end %}
  end

  private def system_lock(blocking : Bool, exclusive : Bool) : Nil
    raise NotImplementedError.new "Crystal::System::File#system_lock"
  end

  private def system_unlock
    raise NotImplementedError.new "Crystal::System::File#system_unlock"
  end

  private def system_echo(enable : Bool)
    raise NotImplementedError.new "Crystal::System::FileDescriptor#system_echo"
  end

  private def system_echo(enable : Bool, & : ->)
    raise NotImplementedError.new "Crystal::System::FileDescriptor#system_echo"
  end

  private def system_raw(enable : Bool)
    raise NotImplementedError.new "Crystal::System::FileDescriptor#system_raw"
  end

  private def system_raw(enable : Bool, & : ->)
    raise NotImplementedError.new "Crystal::System::FileDescriptor#system_raw"
  end
end
