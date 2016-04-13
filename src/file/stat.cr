lib LibC
  ifdef darwin
    struct Stat
      st_dev : Int32
      st_ino : Int32
      st_mode : LibC::ModeT
      st_nlink : UInt16
      st_uid : UInt32
      st_gid : UInt32
      st_rdev : Int32
      st_atimespec : LibC::TimeSpec
      st_mtimespec : LibC::TimeSpec
      st_ctimespec : LibC::TimeSpec
      st_size : Int64
      st_blocks : Int64
      st_blksize : Int32
      st_flags : UInt32
      st_gen : UInt32
      st_lspare : Int32
      st_qspare1 : Int64
      st_qspare2 : Int64
    end
  elsif linux
    ifdef x86_64
      struct Stat
        st_dev : UInt64
        st_ino : UInt64
        st_nlink : UInt64
        st_mode : LibC::ModeT
        st_uid : UInt32
        st_gid : UInt32
        __pad0 : UInt32
        st_rdev : UInt32
        st_size : Int64
        st_blksize : Int64
        st_blocks : Int64
        st_atimespec : LibC::TimeSpec
        st_mtimespec : LibC::TimeSpec
        st_ctimespec : LibC::TimeSpec
        __unused0 : Int64
        __unused1 : Int64
        __unused2 : Int64
      end
    else
      struct Stat
        st_dev : UInt64
        __pad1 : UInt16
        st_ino : UInt32
        st_mode : LibC::ModeT
        st_nlink : UInt32
        st_uid : UInt32
        st_gid : UInt32
        st_rdev : UInt64
        __pad2 : Int16
        st_size : UInt32
        st_blksize : Int32
        st_blocks : Int32
        st_atimespec : LibC::TimeSpec
        st_mtimespec : LibC::TimeSpec
        st_ctimespec : LibC::TimeSpec
        __unused4 : UInt64
        __unused5 : UInt64
      end
    end
  end

  S_ISVTX  = 0o001000
  S_ISGID  = 0o002000
  S_ISUID  = 0o004000
  S_IFIFO  = 0o010000
  S_IFCHR  = 0o020000
  S_IFDIR  = 0o040000
  S_IFBLK  = 0o060000
  S_IFREG  = 0o100000
  S_IFLNK  = 0o120000
  S_IFSOCK = 0o140000
  S_IFMT   = 0o170000

  fun stat(path : Char*, stat : Stat*) : Int
  fun lstat(path : Char*, stat : Stat*) : Int
  fun fstat(fileno : Int, stat : Stat*) : Int
end

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
      time @stat.st_atimespec
    end

    def blksize
      @stat.st_blksize
    end

    def blocks
      @stat.st_blocks
    end

    def ctime
      time @stat.st_ctimespec
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
      time @stat.st_mtimespec
    end

    def nlink
      @stat.st_nlink
    end

    def rdev
      @stat.st_rdev
    end

    def size
      @stat.st_size
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
