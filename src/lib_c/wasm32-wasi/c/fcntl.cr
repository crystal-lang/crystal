require "./sys/types"
require "./sys/stat"
require "./unistd"

lib LibC
  F_GETFD    = 1
  F_SETFD    = 2
  F_GETFL    = 3
  F_SETFL    = 4
  FD_CLOEXEC = 1
  O_CLOEXEC  = 0
  O_CREAT    = 1_u16 << 12
  O_EXCL     = 4_u16 << 12
  O_NOFOLLOW = 0x01000000
  O_TRUNC    = 8_u16 << 12
  O_APPEND   =      1_u16
  O_NONBLOCK =      4_u16
  O_SYNC     =     16_u16
  O_RDONLY   = 0x04000000
  O_RDWR     = O_RDONLY | O_WRONLY
  O_WRONLY   = 0x10000000

  fun fcntl(x0 : Int, x1 : Int, ...) : Int
  fun open(x0 : Char*, x1 : Int, ...) : Int
end
