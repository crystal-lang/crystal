require "./types"
require "../time"

lib LibC
  S_IFMT   = 0o0170000
  S_IFBLK  =  0o060000
  S_IFCHR  =  0o020000
  S_IFIFO  =  0o010000
  S_IFREG  =  0o100000
  S_IFDIR  =  0o040000
  S_IFLNK  =  0o120000
  S_IFSOCK =  0o140000
  S_IRUSR  =    0o0400
  S_IWUSR  =    0o0200
  S_IXUSR  =    0o0100
  S_IRWXU  =    0o0700
  S_IRGRP  =    0o0040
  S_IWGRP  =    0o0020
  S_IXGRP  =    0o0010
  S_IRWXG  =    0o0070
  S_IROTH  =    0o0004
  S_IWOTH  =    0o0002
  S_IXOTH  =    0o0001
  S_IRWXO  =    0o0007
  S_ISUID  =  0o004000
  S_ISGID  =  0o002000
  S_ISVTX  =  0o001000

  struct Stat
    st_dev : ULong
    st_ino : ULong
    st_nlink : ULong
    st_mode : UInt
    st_uid : UidT
    st_gid : GidT
    __pad0 : UInt
    st_rdev : ULong
    st_size : Long
    st_blksize : Long
    st_blocks : Long
    st_atime : ULong
    st_atime_nsec : ULong
    st_mtime : ULong
    st_mtime_nsec : ULong
    st_ctime : ULong
    st_ctime_nsec : ULong
    __pad3 : StaticArray(Long, 3)
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
