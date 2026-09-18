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
  O_CREAT    =     0o100
  O_EXCL     =    0o0200
  O_NOFOLLOW =  0o100000
  O_TRUNC    =    0o1000
  O_APPEND   =    0o2000
  O_NONBLOCK =    0o4000
  O_SYNC     = 0o4010000
  O_RDONLY   =       0o0
  O_RDWR     =       0o2
  O_WRONLY   =       0o1

  AT_FDCWD                =    -100
  AT_SYMLINK_NOFOLLOW     =   0x100
  AT_SYMLINK_FOLLOW       =   0x400
  AT_NO_AUTOMOUNT         =   0x800
  AT_EMPTY_PATH           =  0x1000
  AT_STATX_SYNC_TYPE      =  0x6000
  AT_STATX_SYNC_AS_STAT   =  0x0000
  AT_STATX_FORCE_SYNC     =  0x2000
  AT_STATX_DONT_SYNC      =  0x4000
  AT_RECURSIVE            =  0x8000
  AT_RENAME_NOREPLACE     =  0x0001
  AT_RENAME_EXCHANGE      =  0x0002
  AT_RENAME_WHITEOUT      =  0x0004
  AT_EACCESS              =   0x200
  AT_REMOVEDIR            =   0x200
  AT_HANDLE_FID           =   0x200
  AT_HANDLE_MNT_ID_UNIQUE =   0x001
  AT_HANDLE_CONNECTABLE   =   0x002
  AT_EXECVE_CHECK         = 0x10000

  fun fcntl(__fd : Int, __cmd : Int, ...) : Int
  fun open(__path : Char*, __flags : Int, ...) : Int
end
