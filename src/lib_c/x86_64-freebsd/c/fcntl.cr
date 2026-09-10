require "./sys/types"
require "./sys/stat"
require "./unistd"

lib LibC
  F_GETFD    =          1
  F_SETFD    =          2
  F_GETFL    =          3
  F_SETFL    =          4
  FD_CLOEXEC =          1
  O_CLOEXEC  = 0x00100000
  O_CREAT    =     0x0200
  O_NOFOLLOW =     0x0100
  O_TRUNC    =     0x0400
  O_EXCL     =     0x0800
  O_APPEND   =     0x0008
  O_NONBLOCK =     0x0004
  O_SYNC     =     0x0080
  O_RDONLY   =     0x0000
  O_RDWR     =     0x0002
  O_WRONLY   =     0x0001

  # Magic value that specify the use of the current working directory
  # to determine the target of relative file paths in the openat() and
  # similar syscalls.

  AT_FDCWD = -100

  # Miscellaneous flags for the *at() syscalls.
  AT_EACCESS          = 0x0100 # Check access using effective user and group ID
  AT_SYMLINK_NOFOLLOW = 0x0200 # Do not follow symbolic links
  AT_SYMLINK_FOLLOW   = 0x0400 # Follow symbolic link
  AT_REMOVEDIR        = 0x0800 # Remove directory instead of file
  AT_RESOLVE_BENEATH  = 0x2000 # Do not allow name resolution to walk out of dirfd
  AT_EMPTY_PATH       = 0x4000 # Operate on dirfd if path is empty

  AT_RENAME_NOREPLACE = 0x0001 # Fail rename if target exists
  AT_RENAME_EXCHANGE  = 0x0002 # Atomically exchange 'from' and 'to'

  struct Flock
    l_start : OffT
    l_len : OffT
    l_pid : PidT
    l_type : Short
    l_whence : Short
    l_sysid : Int
  end

  fun fcntl(x0 : Int, x1 : Int, ...) : Int
  fun open(x0 : Char*, x1 : Int, ...) : Int
  fun faccessat(fd : Int, name : Char*, type : Int, flags : Int) : Int
end
