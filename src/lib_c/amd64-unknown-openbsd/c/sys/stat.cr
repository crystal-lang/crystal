require "./types"
require "../time"

lib LibC

  struct Stat
    st_mode : ModeT           # inode protection mode
    st_dev : DevT             # inode's device
    st_ino : InoT             # inode's number
    st_nlink : NlinkT         # number of hard links
    st_uid : UidT             # user ID of the file's owner
    st_gid : GidT             # group ID of the file's group
    st_rdev : DevT            # device type
    st_atim : Timespec        # time of last access
    st_mtim : Timespec        # time of last data modification
    st_ctim : Timespec        # time of last file status change
    st_size : OffT            # file size, in bytes
    st_blocks : BlkcntT       # blocks allocated for file
    st_blksize : BlksizeT     # optimal blocksize for I/O
    st_flags : UInt32T        # user defined flags for file
    st_gen : UInt32T          # file generation number
    __st_birthtim : Timespec  # time of file creation
  end

  S_ISUID   = 0o004000  # set user id on execution
  S_ISGID   = 0o002000  # set group id on execution
  S_ISTXT   = 0o001000  # sticky bit

  S_IRWXU   = 0o000700  # RWX mask for owner
  S_IRUSR   = 0o000400  # R for owner
  S_IWUSR   = 0o000200  # W for owner
  S_IXUSR   = 0o000100  # X for owner

  S_IREAD   = S_IRUSR
  S_IWRITE  = S_IWUSR
  S_IEXEC   = S_IXUSR

  S_IRWXG   = 0o000070  # RWX mask for group
  S_IRGRP   = 0o000040  # R for group
  S_IWGRP   = 0o000020  # W for group
  S_IXGRP   = 0o000010  # X for group

  S_IRWXO   = 0o000007  # RWX mask for other
  S_IROTH   = 0o000004  # R for other
  S_IWOTH   = 0o000002  # W for other
  S_IXOTH   = 0o000001  # X for other

  S_IFMT    = 0o170000  # type of file mask
  S_IFIFO   = 0o010000  # named pipe (fifo)
  S_IFCHR   = 0o020000  # character special
  S_IFDIR   = 0o040000  # directory
  S_IFBLK   = 0o060000  # block special
  S_IFREG   = 0o100000  # regular
  S_IFLNK   = 0o120000  # symbolic link
  S_IFSOCK  = 0o140000  # socket
  S_ISVTX   = 0o001000  # save swapped text even after use

  fun chmod(path : Char*, mode : ModeT) : Int
  fun fstat(fd : Int, sb : Stat*) : Int
  fun mknod(path : Char*, mode : ModeT, dev : DevT) : Int
  fun mkdir(path : Char*, mode : ModeT) : Int
  fun mkfifo(path : Char*, mode : ModeT) : Int
  fun stat(path : Char*, sb : Stat*) : Int
  fun umask(numask : ModeT) : ModeT
  fun lstat(path : Char*, sb : Stat*) : Int
end
