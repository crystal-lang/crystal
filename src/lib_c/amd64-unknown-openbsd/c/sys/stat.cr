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

  struct Stat
    st_mode : ModeT
    st_dev : DevT
    st_ino : InoT
    st_nlink : NlinkT
    st_uid : UidT
    st_gid : GidT
    st_rdev : DevT
    st_atim : Timespec
    st_mtim : Timespec
    st_ctim : Timespec
    st_size : OffT
    st_blocks : BlkcntT
    st_blksize : BlksizeT
    st_flags : UInt32T
    st_gen : UInt32T
    __st_birthtim : Timespec
  end

  struct Statfs
    f_flags : UInt32
    f_bsize : UInt32
    f_iosize : UInt32
    f_blocks : UInt64
    f_bfree : UInt64
    f_bavail : Int64
    f_files : UInt64
    f_ffree : UInt64
    f_favail : Int64
    f_syncwrites : UInt64
    f_syncreads : UInt64
    f_asyncwrites : UInt64
    f_asyncreads : UInt64
    f_fsid : Fsid
    f_namemax : UInt32
    f_owner : UInt32
    f_ctime : UInt64
    f_fstypename : StaticArray(ShortShort, 16)
    f_mntonname : StaticArray(ShortShort, 90)
    f_mntfromname : StaticArray(ShortShort, 90)
    f_mntfromspec : StaticArray(ShortShort, 90)
  end

  fun chmod(x0 : Char*, x1 : ModeT) : Int
  fun fstat(x0 : Int, x1 : Stat*) : Int
  fun lstat(x0 : Char*, x1 : Stat*) : Int
  fun mkdir(x0 : Char*, x1 : ModeT) : Int
  fun mkfifo(x0 : Char*, x1 : ModeT) : Int
  fun mknod(x0 : Char*, x1 : ModeT, x2 : DevT) : Int
  fun stat(x0 : Char*, x1 : Stat*) : Int
  fun statfs(file : Char*, buf : Statfs*) : Int
  fun umask(x0 : ModeT) : ModeT
end
