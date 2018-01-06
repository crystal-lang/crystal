require "./sys/types"
require "./sys/stat"
require "./unistd"

lib LibC
  O_RDONLY    = 0x000000  # open for reading only
  O_WRONLY    = 0x000001  # open for writing only
  O_RDWR      = 0x000002  # open for reading and writing
  O_ACCMODE   = 0x000003  # mask for above modes
  O_NONBLOCK  = 0x000004  # no delay
  O_APPEND    = 0x000008  # set append mode
  O_SHLOCK    = 0x000010  # open with shared file lock
  O_EXLOCK    = 0x000020  # open with exclusive file lock
  O_ASYNC     = 0x000040  # signal pgrp when data ready
  O_FSYNC     = 0x000080  # backwards compatibility
  O_NOFOLLOW  = 0x000100  # if path is a symlink, don't follow
  O_SYNC      = 0x000080  # synchronous writes
  O_CREAT     = 0x000200  # create if nonexistent
  O_TRUNC     = 0x000400  # truncate to zero length
  O_EXCL      = 0x000800  # error if already exists
  O_DSYNC     = O_SYNC    # synchronous data writes
  O_RSYNC     = O_SYNC    # synchronous reads
  O_NOCTTY    = 0x008000  # don't assign controlling terminal
  O_CLOEXEC   = 0x010000  # atomically set FD_CLOEXEC
  O_DIRECTORY = 0x020000  # fail if not a directory

  F_DUPFD           =  0  # duplicate file descriptor
  F_GETFD           =  1  # get file descriptor flags
  F_SETFD           =  2  # set file descriptor flags
  F_GETFL           =  3  # get file status flags
  F_SETFL           =  4  # set file status flags
  F_GETOWN          =  5  # get SIGIO/SIGURG proc/pgrp
  F_SETOWN          =  6  # set SIGIO/SIGURG proc/pgrp
  F_GETLK           =  7  # get record locking information
  F_SETLK           =  8  # set record locking information
  F_SETLKW          =  9  # F_SETLK; wait if blocked
  F_DUPFD_CLOEXEC   = 10  # duplicate with FD_CLOEXEC set
  F_ISATTY          = 11  # used by isatty(3)

  FD_CLOEXEC        =  1	# close-on-exec flag

  F_RDLCK           =  1  # shared or read lock
  F_UNLCK           =  2  # unlock
  F_WRLCK           =  3  # exclusive or write lock


  struct Flock
    l_start : OffT    # starting offset
    l_len : OffT      # len = 0 means until end of file
    l_pid : PidT      # lock owner
    l_type : Short    # lock type: read/write, etc.
    l_whence : Short  # type of l_start
  end

  fun fcntl(x0 : Int, x1 : Int, ...) : Int
  fun open(x0 : Char*, x1 : Int, ...) : Int
end
