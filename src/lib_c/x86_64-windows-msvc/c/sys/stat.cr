require "./types"
require "../corecrt"

lib LibC
  S_IFMT  = 0xF000
  S_IFDIR = 0x4000
  S_IFCHR = 0x2000
  S_IFIFO = 0x1000
  S_IFREG = 0x8000

  S_IREAD  = 0x0100
  S_IWRITE = 0x0080
  S_IEXEC  = 0x0040

  struct Stat64
    st_dev : DevT
    st_ino : InoT
    st_mode : UShort
    st_nlink : Short
    st_uid : Short
    st_gid : Short
    st_rdev : DevT
    st_size : Int64
    st_atime : Time64T
    st_mtime : Time64T
    st_ctime : Time64T
  end

  fun _wstat64(path : WCHAR*, buffer : Stat64*) : Int
  fun _fstat64(fd : Int, buffer : Stat64*) : Int
end
