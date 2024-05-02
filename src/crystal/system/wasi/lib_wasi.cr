lib LibWasi
  alias Fd = Int32
  alias Size = UInt32
  alias FileSize = UInt64

  struct PrestatDir
    pr_name_len : Size
  end

  union PrestatUnion
    dir : PrestatDir
  end

  enum PrestatTag : UInt8
    Dir
  end

  struct Prestat
    tag : PrestatTag
    value : PrestatUnion
  end

  @[Flags]
  enum LookupFlags : UInt32
    SymlinkFollow
  end

  @[Flags]
  enum OpenFlags : UInt16
    Creat
    Directory
    Excl
    Trunc
  end

  @[Flags]
  enum FdFlags : UInt16
    Append   # Append mode: Data written to the file is always appended to the file's end.
    Dsync    # Write according to synchronized I/O data integrity completion. Only the data stored in the file is synchronized.
    NonBlock # Non-blocking mode.
    RSync    # Synchronized read I/O operations.
    Sync     # Write according to synchronized I/O file integrity completion. In addition to synchronizing the data stored in the file, the implementation may also synchronously update the file's metadata.
  end

  @[Flags]
  enum Rights : UInt64
    FdDatasync           # The right to invoke fd_datasync. If path_open is set, includes the right to invoke path_open with fdflags::dsync.
    FdRead               # The right to invoke fd_read and sock_recv. If rights::fd_seek is set, includes the right to invoke fd_pread.
    FdSeek               # The right to invoke fd_seek. This flag implies rights::fd_tell.
    FdFdstatSetFlags     # The right to invoke fd_fdstat_set_flags.
    FdSync               # The right to invoke fd_sync. If path_open is set, includes the right to invoke path_open with fdflags::rsync and fdflags::dsync.
    FdTell               # The right to invoke fd_seek in such a way that the file offset remains unaltered (i.e., whence::cur with offset zero), or to invoke fd_tell.
    FdWrite              # The right to invoke fd_write and sock_send. If rights::fd_seek is set, includes the right to invoke fd_pwrite.
    FdAdvise             # The right to invoke fd_advise.
    FdAllocate           # The right to invoke fd_allocate.
    PathCreateDirectory  # The right to invoke path_create_directory.
    PathCreateFile       # If path_open is set, the right to invoke path_open with oflags::creat.
    PathLinkSource       # The right to invoke path_link with the file descriptor as the source directory.
    PathLinkTarget       # The right to invoke path_link with the file descriptor as the target directory.
    PathOpen             # The right to invoke path_open.
    FdReaddir            # The right to invoke fd_readdir.
    PathReadlink         # The right to invoke path_readlink.
    PathRenameSource     # The right to invoke path_rename with the file descriptor as the source directory.
    PathRenameTarget     # The right to invoke path_rename with the file descriptor as the target directory.
    PathFilestatGet      # The right to invoke path_filestat_get.
    PathFilestatSetSize  # The right to change a file's size (there is no path_filestat_set_size). If path_open is set, includes the right to invoke path_open with oflags::trunc.
    PathFilestatSetTimes # The right to invoke path_filestat_set_times.
    FdFilestatGet        # The right to invoke fd_filestat_get.
    FdFilestatSetSize    # The right to invoke fd_filestat_set_size.
    FdFilestatSetTimes   # The right to invoke fd_filestat_set_times.
    PathSymlink          # The right to invoke path_symlink.
    PathRemoveDirectory  # The right to invoke path_remove_directory.
    PathUnlinkFile       # The right to invoke path_unlink_file.
    PollFdReadwrite      # If rights::fd_read is set, includes the right to invoke poll_oneoff to subscribe to eventtype::fd_read. If rights::fd_write is set, includes the right to invoke poll_oneoff to subscribe to eventtype::fd_write.
    SockShutdown         # The right to invoke sock_shutdown.
  end

  enum FileType : UInt8
    Unknown         # The type of the file descriptor or file is unknown or is different from any of the other types specified.
    BlockDevice     # The file descriptor or file refers to a block device inode.
    CharacterDevice # The file descriptor or file refers to a character device inode.
    Directory       # The file descriptor or file refers to a directory inode.
    RegularFile     # The file descriptor or file refers to a regular file inode.
    SocketDgram     # The file descriptor or file refers to a datagram socket.
    SocketStream    # The file descriptor or file refers to a byte-stream socket.
    SymbolicLink    # The file refers to a symbolic link inode.
  end

  struct DirEnt
    d_next : UInt64
    d_ino : UInt64
    d_namlen : UInt32
    d_type : FileType
  end

  fun fd_prestat_get = __wasi_fd_prestat_get(fd : Fd, stat : Prestat*) : WasiError
  fun fd_prestat_dir_name = __wasi_fd_prestat_dir_name(fd : Fd, path : UInt8*, len : Size) : WasiError
  fun path_open = __wasi_path_open(fd : Fd, dirflags : LookupFlags, path : UInt8*, oflags : OpenFlags, fs_rights_base : Rights, fs_rights_inheriting : Rights, fdflags : FdFlags, ret : Fd*) : WasiError
  fun fd_readdir = __wasi_fd_readdir(fd : Fd, buf : UInt8*, len : Size, cookie : UInt64, ret : Size*) : WasiError
  fun fd_close = __wasi_fd_close(fd : Fd) : WasiError
  fun random_get = __wasi_random_get(buf : UInt8*, len : Size) : WasiError
  fun proc_exit = __wasi_proc_exit(code : Int32) : NoReturn
end
