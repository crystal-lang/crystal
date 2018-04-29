require "./sys/types"
require "./sys/stat"
require "./unistd"

lib LibC
  F_GETFD    =         1
  F_SETFD    =         2
  F_GETFL    =         3
  F_SETFL    =         4
  FD_CLOEXEC =         1
  O_CLOEXEC  = 0o2000000
  O_CREAT    = 0o0000100
  O_NOFOLLOW =  0o100000
  O_TRUNC    = 0o0001000
  O_APPEND   = 0o0002000
  O_NONBLOCK = 0o0004000
  O_SYNC     = 0o4000000 | O_DSYNC
  O_RDONLY   = 0o0000000
  O_RDWR     = 0o0000002
  O_WRONLY   = 0o0000001

  struct Flock
    l_type : Short
    l_whence : Short
    l_start : OffT
    l_len : OffT
    l_pid : Int
  end

  fun fcntl(x0 : Int, x1 : Int, ...) : Int
  fun open(x0 : Char*, x1 : Int, ...) : Int
end
