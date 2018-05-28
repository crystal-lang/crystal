require "./types"
require "../corecrt"

lib LibC
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

  fun _fstat64(fd : Int, buffer : Stat64*) : Int
end
