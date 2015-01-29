require "time"

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

  S_ISVTX  = 0001000
  S_ISGID  = 0002000
  S_ISUID  = 0004000
  S_IFIFO  = 0010000
  S_IFCHR  = 0020000
  S_IFDIR  = 0040000
  S_IFBLK  = 0060000
  S_IFREG  = 0100000
  S_IFLNK  = 0120000
  S_IFSOCK = 0140000
  S_IFMT   = 0170000

  fun stat(path : UInt8*, stat : Stat*) : Int32
  fun lstat(path : UInt8*, stat : Stat *) : Int32
  fun fstat(fileno : Int32, stat : Stat*) : Int32
end

class File
  class Stat
    def initialize(filename : String)
      if LibC.stat(filename, out @stat) != 0
        raise Errno.new("Unable to get stat for '#{filename}'")
      end
    end

    def initialize(@stat : LibC::Stat)
    end

    def atime
      Time.new(@stat.st_atimespec)
    end

    def blksize
      @stat.st_blksize
    end

    def blocks
      @stat.st_blocks
    end

    def ctime
      Time.new(@stat.st_ctimespec)
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
      number = @stat.st_mode
      omode  = 0
      m      = 1

      while number != 0
        omode  += (number % 8).to_i * m
        m      *= 10
        number /= 8
      end

      omode
    end

    def mtime
      Time.new(@stat.st_mtimespec)
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

    def inspect
      "<File::Stat dev=%d ino=%s mode=%0s nlink=%s uid=%d gid=%d rdev=%d size=%d blksize=%d blocks=%d atime=%d mtime=%d ctime=%d>" % [dev, ino, mode, nlink, uid, gid, rdev, size, blksize, blocks, atime, mtime, ctime]
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

    def socket?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_IFSOCK
    end

    def sticky?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_ISVTX
    end
  end
end
