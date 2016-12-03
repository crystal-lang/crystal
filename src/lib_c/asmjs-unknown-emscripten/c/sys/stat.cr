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
  S_IRUSR  =    0o400
  S_IWUSR  =    0o200
  S_IXUSR  =    0o100
  S_IRWXU  =    0o700
  S_IRGRP  =    0o040
  S_IWGRP  =    0o020
  S_IXGRP  =    0o010
  S_IRWXG  =    0o070
  S_IROTH  =    0o004
  S_IWOTH  =    0o002
  S_IXOTH  =    0o001
  S_IRWXO  =    0o007
  S_ISUID  =   0o4000
  S_ISGID  =   0o2000
  S_ISVTX  =   0o1000

  struct Stat
    st_dev : DevT
    st_ino : InoT
    st_nlink : NlinkT
    st_mode : ModeT
    st_uid : UidT
    st_gid : GidT
    __pad0 : UInt
    st_rdev : DevT
    st_size : OffT
    st_blksize : BlksizeT
    st_blocks : BlkcntT
    st_atim : Timespec
    st_mtim : Timespec
    st_ctim : Timespec
    __unused : StaticArray(Long, 3)
  end

  fun chmod(x0 : Char*, x1 : ModeT) : Int
  fun fstat(x0 : Int, x1 : Stat*) : Int
  fun lstat(x0 : Char*, x1 : Stat*) : Int
  fun mkdir(x0 : Char*, x1 : ModeT) : Int
  fun mkfifo(x0 : Char*, x1 : ModeT) : Int
  fun mknod(x0 : Char*, x1 : ModeT, x2 : DevT) : Int
  fun stat(x0 : Char*, x1 : Stat*) : Int
  fun umask(x0 : ModeT) : ModeT
end
