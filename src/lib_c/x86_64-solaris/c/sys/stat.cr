require "./types"
require "../time"

lib LibC
  S_IFMT   = 0xF000
  S_IFIFO  = 0x1000
  S_IFCHR  = 0x2000
  S_IFDIR  = 0x4000
  S_IFBLK  = 0x6000
  S_IFREG  = 0x8000
  S_IFLNK  = 0xA000
  S_IFSOCK = 0xC000
  S_IFDOOR = 0xD000
  S_IFPORT = 0xE000

  S_IRWXU = 0o0700
  S_IRUSR = 0o0400
  S_IWUSR = 0o0200
  S_IXUSR = 0o0100
  S_IRWXG = 0o0070
  S_IRGRP = 0o0040
  S_IWGRP = 0o0020
  S_IXGRP = 0o0010
  S_IRWXO = 0o0007
  S_IROTH = 0o0004
  S_IWOTH = 0o0002
  S_IXOTH = 0o0001

  S_ISUID = 0x800
  S_ISGID = 0x400
  S_ISVTX = 0x200

  struct Stat
    st_dev : DevT
    st_ino : InoT
    st_mode : ModeT
    st_nlink : NlinkT
    st_uid : UidT
    st_gid : GidT
    st_rdev : DevT
    st_size : OffT
    st_atim : Timespec
    st_mtim : Timespec
    st_ctim : Timespec
    st_blksize : BlksizeT
    st_blocks : BlkcntT
    st_fstype : Char[16]
  end

  fun chmod(x0 : Char*, x1 : ModeT) : Int
  fun fchmod(x0 : Int, x1 : ModeT) : Int
  fun fstat(x0 : Int, x1 : Stat*) : Int
  fun lstat(x0 : Char*, x1 : Stat*) : Int
  fun mkdir(x0 : Char*, x1 : ModeT) : Int
  fun mkfifo(x0 : Char*, x1 : ModeT) : Int
  fun mknod(x0 : Char*, x1 : ModeT, x2 : DevT) : Int
  fun stat(x0 : Char*, x1 : Stat*) : Int
  fun umask(x0 : ModeT) : ModeT
end
