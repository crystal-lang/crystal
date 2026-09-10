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
  O_EXCL     =     0o200
  O_NOFOLLOW =  0o400000
  O_TRUNC    =    0o1000
  O_APPEND   =    0o2000
  O_NONBLOCK =    0o4000
  O_SYNC     = 0o4010000
  O_RDONLY   =       0o0
  O_RDWR     =       0o2
  O_WRONLY   =       0o1

  #  The constants AT_REMOVEDIR and AT_EACCESS have the same value.  AT_EACCESS
  #  is meaningful only to faccessat, while AT_REMOVEDIR is meaningful only to
  #  unlinkat.  The two functions do completely different things and therefore,
  #  the flags can be allowed to overlap.  For example, passing AT_REMOVEDIR to
  #  faccessat would be undefined behavior and thus treating it equivalent to
  #  AT_EACCESS is valid undefined behavior.

  AT_FDCWD              =   -100 # Special value used to indicate the *at functions should use the current working directory.
  AT_SYMLINK_NOFOLLOW   =  0x100 # Do not follow symbolic links.
  AT_REMOVEDIR          =  0x200 # Remove directory instead of unlinking file.
  AT_SYMLINK_FOLLOW     =  0x400 # Follow symbolic links.
  AT_NO_AUTOMOUNT       =  0x800 # Suppress terminal automount traversal.
  AT_EMPTY_PATH         = 0x1000 # Allow empty relative pathname.
  AT_STATX_SYNC_TYPE    = 0x6000
  AT_STATX_SYNC_AS_STAT = 0x0000
  AT_STATX_FORCE_SYNC   = 0x2000
  AT_STATX_DONT_SYNC    = 0x4000
  AT_RECURSIVE          = 0x8000 # Apply to the entire subtree.
  AT_EACCESS            =  0x200 # Test access permitted for effective IDs, not real IDs.

  struct Flock
    l_type : Short
    l_whence : Short
    l_start : OffT
    l_len : OffT
    l_pid : PidT
  end

  fun fcntl(fd : Int, cmd : Int, ...) : Int
  fun open(file : Char*, oflag : Int, ...) : Int
end
