require "c/sys/stat"

class File
  struct Stat
    def self.new(filename : String)
      File.stat(filename)
    end

    {% if flag?(:win32) %}
      # :nodoc:
      def initialize(@stat : LibC::Stat64)
      end
    {% else %}
      # :nodoc:
      def initialize(@stat : LibC::Stat)
      end
    {% end %}

    def atime
      {% if flag?(:darwin) %}
        time @stat.st_atimespec
      {% elsif flag?(:win32) %}
        time @stat.st_atime
      {% else %}
        time @stat.st_atim
      {% end %}
    end

    def blksize
      {% if flag?(:win32) %}
        raise NotImplementedError.new("File::Stat#blksize")
      {% else %}
        @stat.st_blksize
      {% end %}
    end

    def blocks
      {% if flag?(:win32) %}
        raise NotImplementedError.new("File::Stat#blocks")
      {% else %}
        @stat.st_blocks
      {% end %}
    end

    def ctime
      {% if flag?(:darwin) %}
        time @stat.st_ctimespec
      {% elsif flag?(:win32) %}
        time @stat.st_ctime
      {% else %}
        time @stat.st_ctim
      {% end %}
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
      {% if flag?(:darwin) %}
        time @stat.st_mtimespec
      {% elsif flag?(:win32) %}
        time @stat.st_mtime
      {% else %}
        time @stat.st_mtim
      {% end %}
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
      io << ", mode=0o"
      mode.to_s(8, io)
      io << ", nlink=" << nlink
      io << ", uid=" << uid
      io << ", gid=" << gid
      io << ", rdev=0x"
      rdev.to_s(16, io)
      io << ", size=" << size
      {% unless flag?(:win32) %}
        # These two getters raise NotImplementedError on windows.
        io << ", blksize=" << blksize
        io << ", blocks=" << blocks
      {% end %}
      io << ", atime=" << atime
      io << ", mtime=" << mtime
      io << ", ctime=" << ctime
      io << '>'
    end

    def pretty_print(pp)
      pp.surround("#<File::Stat", ">", left_break: " ", right_break: nil) do
        pp.text "dev=0x#{dev.to_s(16)}"
        pp.comma
        pp.text "ino=#{ino}"
        pp.comma
        pp.text "mode=0o#{mode.to_s(8)}"
        pp.comma
        pp.text "nlink=#{nlink}"
        pp.comma
        pp.text "uid=#{uid}"
        pp.comma
        pp.text "gid=#{gid}"
        pp.comma
        pp.text "rdev=0x#{rdev.to_s(16)}"
        pp.comma
        pp.text "size=#{size}"
        pp.comma
        {% unless flag?(:win32) %}
          # These two getters raise NotImplementedError on windows.
          pp.text "blksize=#{blksize}"
          pp.comma
          pp.text "blocks=#{blocks}"
          pp.comma
        {% end %}
        pp.text "atime=#{atime}"
        pp.comma
        pp.text "mtime=#{mtime}"
        pp.comma
        pp.text "ctime=#{ctime}"
      end
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

    def pipe?
      (@stat.st_mode & LibC::S_IFMT) == LibC::S_IFIFO
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

    {% if flag?(:win32) %}
      private def time(value)
        Time.epoch(value)
      end
    {% else %}
      private def time(value)
        Time.new value, Time::Location::UTC
      end
    {% end %}
  end
end
