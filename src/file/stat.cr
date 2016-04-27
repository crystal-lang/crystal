require "c/sys/stat"

class File
  struct Stat
    def initialize(filename : String)
      if LibC.stat(filename, out @stat) != 0
        raise Errno.new("Unable to get stat for '#{filename}'")
      end
    end

    def initialize(@stat : LibC::Stat)
    end

    def atime
      ifdef darwin
        time @stat.st_atimespec
      else
        time @stat.st_atim
      end
    end

    def blksize
      @stat.st_blksize
    end

    def blocks
      @stat.st_blocks
    end

    def ctime
      ifdef darwin
        time @stat.st_ctimespec
      else
        time @stat.st_ctim
      end
    end

    def dev
      @stat.st_dev
    end

    def gid
      @stat.st_gid
    end

    def ino
      @stat.st_ino
    end

    def mode
      @stat.st_mode
    end

    # permission bits of mode
    def perm
      mode & 0o7777
    end

    def mtime
      ifdef darwin
        time @stat.st_mtimespec
      else
        time @stat.st_mtim
      end
    end

    def nlink
      @stat.st_nlink
    end

    def rdev
      @stat.st_rdev
    end

    def size
      @stat.st_size.to_u64
    end

    def uid
      @stat.st_uid
    end

    def inspect(io)
      io << "#<File::Stat"
      io << " dev=0x"
      dev.to_s(16, io)
      io << ", ino=" << ino
      io << ", mode=0"
      mode.to_s(8, io)
      io << ", nlink=" << nlink
      io << ", uid=" << uid
      io << ", gid=" << gid
      io << ", rdev=0x"
      rdev.to_s(16, io)
      io << ", size=" << size
      io << ", blksize=" << blksize
      io << ", blocks=" << blocks
      io << ", atime=" << atime
      io << ", mtime=" << mtime
      io << ", ctime=" << ctime
      io << ">"
    end

    def blockdev?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_IFBLK
    end

    def chardev?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_IFCHR
    end

    def directory?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_IFDIR
    end

    def file?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_IFREG
    end

    def setuid?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_ISUID
    end

    def setgid?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_ISGID
    end

    def symlink?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_IFLNK
    end

    def socket?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_IFSOCK
    end

    def sticky?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_ISVTX
    end

    private def time(value)
      Time.new value, Time::Kind::Utc
    end
  end
end
