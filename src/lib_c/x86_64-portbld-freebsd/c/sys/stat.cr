require "./types"
require "../time"

lib LibC
  S_IFMT   = 0o170000
  S_IFBLK  = 0o060000
  S_IFCHR  = 0o020000
  S_IFIFO  = 0o010000
  S_IFREG  = 0o100000
  S_IFDIR  = 0o040000
  S_IFLNK  = 0o120000
  S_IFSOCK = 0o140000
  S_IRUSR  = 0o000400
  S_IWUSR  = 0o000200
  S_IXUSR  = 0o000100
  S_IRWXU  = 0o000700
  S_IRGRP  = 0o000040
  S_IWGRP  = 0o000020
  S_IXGRP  = 0o000010
  S_IRWXG  = 0o000070
  S_IROTH  = 0o000004
  S_IWOTH  = 0o000002
  S_IXOTH  = 0o000001
  S_IRWXO  = 0o000007
  S_ISUID  = 0o004000
  S_ISGID  = 0o002000
  S_ISVTX  = 0o001000

  alias FflagsT = UInt

  struct Stat
    st_dev : DevT
    st_ino : InoT
    {% if flag?(:"freebsd12.0") %}
      st_nlink : NlinkT
      st_mode : ModeT
      st_pad0 : UShort
    {% else %}
      st_mode : ModeT
      st_nlink : NlinkT
    {% end %}
    st_uid : UidT
    st_gid : GidT
    {% if flag?(:"freebsd12.0") %}
      st_pad1 : UInt
    {% end %}
    st_rdev : DevT
    st_atim : Timespec
    st_mtim : Timespec
    st_ctim : Timespec
    {% if flag?(:"freebsd12.0") %}
      st_birthtim : Timespec
    {% end %}
    st_size : OffT
    st_blocks : BlkcntT
    st_blksize : BlksizeT
    st_flags : FflagsT
    {% if flag?(:"freebsd12.0") %}
      st_gen : ULong
      st_spare : StaticArray(ULong, 10)
    {% else %}
      st_gen : UInt
      st_lspare : Int
      st_birthtim : Timespec
      __reserved_17 : UInt
      __reserved_18 : UInt
    {% end %}
  end

  struct Statfs
    version : UInt32
    type : UInt32
    flags : UInt64
    bsize : UInt64
    iosize : UInt64
    blocks : UInt64
    bfree : UInt64
    bavail : Int64
    files : UInt64
    ffree : Int64
    syncwrites : UInt64
    asyncwrites : UInt64
    syncreads : UInt64
    asyncreads : UInt64
    spare : StaticArray(LongLong, 10)
    namemax : UInt32
    owner : UInt32
    fsid : Fsid
    charspare : StaticArray(ShortShort, 80)
    fstypename : StaticArray(ShortShort, 16)
    mntfromname : StaticArray(ShortShort, 88)
    mntonname : StaticArray(ShortShort, 88)
  end

  fun chmod(x0 : Char*, x1 : ModeT) : Int
  fun fstat(x0 : Int, x1 : Stat*) : Int
  fun lstat(x0 : Char*, x1 : Stat*) : Int
  fun mkdir(x0 : Char*, x1 : ModeT) : Int
  fun mkfifo(x0 : Char*, x1 : ModeT) : Int
  fun mknod(x0 : Char*, x1 : ModeT, x2 : DevT) : Int
  fun stat(x0 : Char*, x1 : Stat*) : Int
  fun statfs(file : Char*, buf : Stat*) : Int
  fun umask(x0 : ModeT) : ModeT
end
