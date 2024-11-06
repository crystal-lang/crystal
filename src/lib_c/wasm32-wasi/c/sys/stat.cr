require "./types"
require "../time"

lib LibC
  S_IFMT   = S_IFBLK | S_IFCHR | S_IFDIR | S_IFIFO | S_IFLNK | S_IFREG | S_IFSOCK
  S_IFBLK  = 0x6000
  S_IFCHR  = 0x2000
  S_IFIFO  = 0xc000
  S_IFREG  = 0x8000
  S_IFDIR  = 0x4000
  S_IFLNK  = 0xa000
  S_IFSOCK = 0xc000
  S_IRUSR  =  0x100
  S_IWUSR  =   0x80
  S_IXUSR  =   0x40
  S_IRWXU  = S_IXUSR | S_IWUSR | S_IRUSR
  S_IRGRP  = 0x20
  S_IWGRP  = 0x10
  S_IXGRP  =  0x8
  S_IRWXG  = S_IXGRP | S_IWGRP | S_IRGRP
  S_IROTH  = 0x4
  S_IWOTH  = 0x2
  S_IXOTH  = 0x1
  S_IRWXO  = S_IXOTH | S_IWOTH | S_IROTH
  S_ISUID  = 0x800
  S_ISGID  = 0x400
  S_ISVTX  = 0x200

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
    __reserved : StaticArray(LongLong, 3)
  end

  fun fchmod(fd : Int, mode : ModeT) : Int
  fun fstat(x0 : Int, x1 : Stat*) : Int
  fun lstat(x0 : Char*, x1 : Stat*) : Int
  fun mkdir(x0 : Char*, x1 : ModeT) : Int
  fun stat(x0 : Char*, x1 : Stat*) : Int
end
