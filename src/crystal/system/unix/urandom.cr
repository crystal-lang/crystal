{% skip_file unless flag?(:unix) && !flag?(:openbsd) %}

require "c/fcntl"
require "c/unistd"
require "c/sys/stat"
require "mutex"

# :nodoc:
module Crystal::System::Urandom
  @@mutex = Mutex.new
  @@fd : LibC::Int?

  # Opens `/dev/urandom`, verifies the opened file is indeed a character device.
  #
  # We rely on raw POSIX calls instead of leveraging Crystal IO and File
  # facilities to ensure that we don't inadvertently use an insecure feature
  # while reading from `/dev/urandom` such as buffering or even evented IO since
  # `/dev/urandom` shall only block very early during the OS boot process.
  private def self.init
    @@mutex.synchronize do
      fd = LibC.open("/dev/urandom", LibC::O_RDONLY)
      raise Errno.new("open") if fd == -1

      if LibC.fstat(fd, out stats) == -1
        raise Errno.new("fstat")
      end
      if (stats.st_mode & LibC::S_IFMT) == LibC::S_IFCHR
        flags = LibC.fcntl(fd, LibC::F_GETFD, 0)
        raise Errno.new("fcntl") if flags == -1

        if LibC.fcntl(fd, LibC::F_SETFD, flags | LibC::FD_CLOEXEC) == -1
          raise Errno.new("fcntl")
        end
      else
        if LibC.close(fd) == -1
          raise Errno.new("close")
        end
      end

      @@fd = fd
    end
  end

  def self.random_bytes(buf : Bytes) : Nil
    init unless @@fd

    if fd = @@fd
      while buf.size > 0
        read_bytes = LibC.read(fd, buf, buf.size)
        if read_bytes < 0
          unless Errno.value == Errno::EINTR
            raise Errno.new("read")
          end
        else
          buf += read_bytes
        end
      end
    else
      raise "Failed to access secure source to generate random bytes!"
    end
  end
end
