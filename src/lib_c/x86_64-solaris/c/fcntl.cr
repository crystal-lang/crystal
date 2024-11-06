require "./sys/types"
require "./sys/stat"
require "./unistd"

lib LibC
  F_GETFD    =        1
  F_SETFD    =        2
  F_GETFL    =        3
  F_SETFL    =        4
  FD_CLOEXEC =        1
  O_CLOEXEC  = 0x800000
  O_CREAT    =    0x100
  O_NOFOLLOW =  0x20000
  O_TRUNC    =    0x200
  O_EXCL     =    0x400
  O_APPEND   =     0x08
  O_NONBLOCK =     0x80
  O_SYNC     =     0x10
  O_RDONLY   =        0
  O_RDWR     =        2
  O_WRONLY   =        1

  struct Flock
    l_type : Short
    l_whence : Short
    l_start : OffT
    l_len : OffT
    l_sysid : Int
    l_pid : PidT
    l_pad : Long[4]
  end

  fun fcntl(x0 : Int, x1 : Int, ...) : Int
  fun open(x0 : Char*, x1 : Int, ...) : Int
end
