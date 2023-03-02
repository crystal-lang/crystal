require "c/io"
require "c/fcntl"
require "c/fileapi"
require "c/sys/utime"
require "c/sys/stat"
require "c/winbase"
require "c/handleapi"

module Crystal::System::File
  def self.open(filename : String, mode : String, perm : Int32 | ::File::Permissions) : LibC::Int
    perm = ::File::Permissions.new(perm) if perm.is_a? Int32
    # Only the owner writable bit is used, since windows only supports
    # the read only attribute.
    if perm.owner_write?
      perm = LibC::S_IREAD | LibC::S_IWRITE
    else
      perm = LibC::S_IREAD
    end

    fd, errno = open(filename, open_flag(mode), ::File::Permissions.new(perm))
    unless errno.none?
      raise ::File::Error.from_os_error("Error opening file with mode '#{mode}'", errno, file: filename)
    end

    fd
  end

  def self.open(filename : String, flags : Int32, perm : ::File::Permissions) : {LibC::Int, Errno}
    flags |= LibC::O_BINARY | LibC::O_NOINHERIT

    fd = LibC._wopen(System.to_wstr(filename), flags, perm)

    {fd, fd == -1 ? Errno.value : Errno::NONE}
  end

  NOT_FOUND_ERRORS = {
    WinError::ERROR_FILE_NOT_FOUND,
    WinError::ERROR_PATH_NOT_FOUND,
    WinError::ERROR_INVALID_NAME,
  }

  REPARSE_TAG_NAME_SURROGATE_MASK = 1 << 29

  private def self.check_not_found_error(message, path)
    error = WinError.value
    if NOT_FOUND_ERRORS.includes? error
      nil
    else
      raise ::File::Error.from_os_error(message, error, file: path)
    end
  end

  def self.info?(path : String, follow_symlinks : Bool) : ::File::Info?
    winpath = System.to_wstr(path)

    unless follow_symlinks
      # First try using GetFileAttributes to check if it's a reparse point
      file_attributes = uninitialized LibC::WIN32_FILE_ATTRIBUTE_DATA
      ret = LibC.GetFileAttributesExW(
        winpath,
        LibC::GET_FILEEX_INFO_LEVELS::GetFileExInfoStandard,
        pointerof(file_attributes)
      )
      return check_not_found_error("Unable to get file info", path) if ret == 0

      if file_attributes.dwFileAttributes.bits_set? LibC::FILE_ATTRIBUTE_REPARSE_POINT
        # Could be a symlink, retrieve its reparse tag with FindFirstFile
        handle = LibC.FindFirstFileW(winpath, out find_data)
        return check_not_found_error("Unable to get file info", path) if handle == LibC::INVALID_HANDLE_VALUE

        if LibC.FindClose(handle) == 0
          raise RuntimeError.from_winerror("FindClose")
        end

        if find_data.dwReserved0.bits_set? REPARSE_TAG_NAME_SURROGATE_MASK
          return ::File::Info.new(find_data)
        end
      end
    end

    handle = LibC.CreateFileW(
      System.to_wstr(path),
      LibC::FILE_READ_ATTRIBUTES,
      LibC::FILE_SHARE_READ | LibC::FILE_SHARE_WRITE | LibC::FILE_SHARE_DELETE,
      nil,
      LibC::OPEN_EXISTING,
      LibC::FILE_FLAG_BACKUP_SEMANTICS,
      LibC::HANDLE.null
    )

    return check_not_found_error("Unable to get file info", path) if handle == LibC::INVALID_HANDLE_VALUE

    begin
      if LibC.GetFileInformationByHandle(handle, out file_info) == 0
        raise ::File::Error.from_winerror("Unable to get file info", file: path)
      end

      ::File::Info.new(file_info, LibC::FILE_TYPE_DISK)
    ensure
      LibC.CloseHandle(handle)
    end
  end

  def self.info(path, follow_symlinks)
    info?(path, follow_symlinks) || raise ::File::Error.from_winerror("Unable to get file info", file: path)
  end

  def self.exists?(path)
    accessible?(path, 0)
  end

  def self.readable?(path) : Bool
    accessible?(path, 4)
  end

  def self.writable?(path) : Bool
    accessible?(path, 2)
  end

  def self.executable?(path) : Bool
    LibC.GetBinaryTypeW(System.to_wstr(path), out result) != 0
  end

  private def self.accessible?(path, mode)
    LibC._waccess_s(System.to_wstr(path), mode) == 0
  end

  def self.chown(path : String, uid : Int32, gid : Int32, follow_symlinks : Bool) : Nil
    raise NotImplementedError.new("File.chown")
  end

  def self.fchown(path : String, fd : Int, uid : Int32, gid : Int32) : Nil
    raise NotImplementedError.new("File#chown")
  end

  def self.chmod(path : String, mode : Int32 | ::File::Permissions) : Nil
    mode = ::File::Permissions.new(mode) unless mode.is_a? ::File::Permissions

    # TODO: dereference symlinks

    attributes = LibC.GetFileAttributesW(System.to_wstr(path))
    if attributes == LibC::INVALID_FILE_ATTRIBUTES
      raise ::File::Error.from_winerror("Error changing permissions", file: path)
    end

    # Only the owner writable bit is used, since windows only supports
    # the read only attribute.
    if mode.owner_write?
      attributes &= ~LibC::FILE_ATTRIBUTE_READONLY
    else
      attributes |= LibC::FILE_ATTRIBUTE_READONLY
    end

    if LibC.SetFileAttributesW(System.to_wstr(path), attributes) == 0
      raise ::File::Error.from_winerror("Error changing permissions", file: path)
    end
  end

  def self.fchmod(path : String, fd : Int, mode : Int32 | ::File::Permissions) : Nil
    # TODO: use fd instead of path
    chmod path, mode
  end

  def self.delete(path : String, *, raise_on_missing : Bool) : Bool
    if LibC._wunlink(System.to_wstr(path)) == 0
      true
    elsif !raise_on_missing && Errno.value == Errno::ENOENT
      false
    else
      raise ::File::Error.from_errno("Error deleting file", file: path)
    end
  end

  def self.realpath(path : String) : String
    # TODO: read links using https://msdn.microsoft.com/en-us/library/windows/desktop/aa364571(v=vs.85).aspx
    win_path = System.to_wstr(path)

    realpath = System.retry_wstr_buffer do |buffer, small_buf|
      len = LibC.GetFullPathNameW(win_path, buffer.size, buffer, nil)
      if 0 < len < buffer.size
        break String.from_utf16(buffer[0, len])
      elsif small_buf && len > 0
        next len
      else
        raise ::File::Error.from_winerror("Error resolving real path", file: path)
      end
    end

    unless exists? realpath
      raise ::File::Error.from_os_error("Error resolving real path", Errno::ENOENT, file: path)
    end

    realpath
  end

  def self.link(old_path : String, new_path : String) : Nil
    if LibC.CreateHardLinkW(System.to_wstr(new_path), System.to_wstr(old_path), nil) == 0
      raise ::File::Error.from_winerror("Error creating link", file: old_path, other: new_path)
    end
  end

  def self.symlink(old_path : String, new_path : String) : Nil
    win_old_path = System.to_wstr(old_path)
    win_new_path = System.to_wstr(new_path)
    info = info?(old_path, true)
    flags = info.try(&.type.directory?) ? LibC::SYMBOLIC_LINK_FLAG_DIRECTORY : 0

    result = LibC.CreateSymbolicLinkW(win_new_path, win_old_path, flags | LibC::SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE)

    # If we get an error like ERROR_INVALID_PARAMETER, it means that we have an
    # older Windows. Retry without SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE
    # flag.
    if result == 0 && WinError.value == WinError::ERROR_INVALID_PARAMETER
      result = LibC.CreateSymbolicLinkW(win_new_path, win_old_path, flags)
    end

    if result == 0
      raise ::File::Error.from_winerror("Error creating symlink", file: old_path, other: new_path)
    end
  end

  def self.readlink(path) : String
    raise NotImplementedError.new("readlink")
  end

  def self.rename(old_path : String, new_path : String) : ::File::Error?
    if LibC.MoveFileExW(System.to_wstr(old_path), System.to_wstr(new_path), LibC::MOVEFILE_REPLACE_EXISTING) == 0
      ::File::Error.from_winerror("Error renaming file", file: old_path, other: new_path)
    end
  end

  def self.utime(access_time : ::Time, modification_time : ::Time, path : String) : Nil
    atime = Crystal::System::Time.to_filetime(access_time)
    mtime = Crystal::System::Time.to_filetime(modification_time)
    handle = LibC.CreateFileW(
      System.to_wstr(path),
      LibC::FILE_WRITE_ATTRIBUTES,
      LibC::FILE_SHARE_READ | LibC::FILE_SHARE_WRITE | LibC::FILE_SHARE_DELETE,
      nil,
      LibC::OPEN_EXISTING,
      LibC::FILE_FLAG_BACKUP_SEMANTICS,
      LibC::HANDLE.null
    )
    if handle == LibC::INVALID_HANDLE_VALUE
      raise ::File::Error.from_winerror("Error setting time on file", file: path)
    end
    begin
      if LibC.SetFileTime(handle, nil, pointerof(atime), pointerof(mtime)) == 0
        raise ::File::Error.from_winerror("Error setting time on file", file: path)
      end
    ensure
      LibC.CloseHandle(handle)
    end
  end

  def self.futimens(path : String, fd : Int, access_time : ::Time, modification_time : ::Time) : Nil
    # TODO: use fd instead of path
    utime access_time, modification_time, path
  end

  private def system_truncate(size : Int) : Nil
    if LibC._chsize_s(fd, size) != 0
      raise ::File::Error.from_errno("Error truncating file", file: path)
    end
  end

  private def system_flock_shared(blocking : Bool) : Nil
    flock(false, blocking)
  end

  private def system_flock_exclusive(blocking : Bool) : Nil
    flock(true, blocking)
  end

  private def system_flock_unlock : Nil
    unlock_file(windows_handle)
  end

  private def flock(exclusive, retry)
    flags = LibC::LOCKFILE_FAIL_IMMEDIATELY
    flags |= LibC::LOCKFILE_EXCLUSIVE_LOCK if exclusive

    handle = windows_handle
    if retry
      until lock_file(handle, flags)
        sleep 0.1
      end
    else
      lock_file(handle, flags) || raise IO::Error.from_winerror("Error applying file lock: file is already locked")
    end
  end

  private def lock_file(handle, flags)
    # lpOverlapped must be provided despite the synchronous use of this method.
    overlapped = LibC::OVERLAPPED.new
    # lock the entire file with offset 0 in overlapped and number of bytes set to max value
    if 0 != LibC.LockFileEx(handle, flags, 0, 0xFFFF_FFFF, 0xFFFF_FFFF, pointerof(overlapped))
      true
    else
      winerror = WinError.value
      if winerror == WinError::ERROR_LOCK_VIOLATION
        false
      else
        raise IO::Error.from_os_error("LockFileEx", winerror)
      end
    end
  end

  private def unlock_file(handle)
    # lpOverlapped must be provided despite the synchronous use of this method.
    overlapped = LibC::OVERLAPPED.new
    # unlock the entire file with offset 0 in overlapped and number of bytes set to max value
    if 0 == LibC.UnlockFileEx(handle, 0, 0xFFFF_FFFF, 0xFFFF_FFFF, pointerof(overlapped))
      raise IO::Error.from_winerror("UnLockFileEx")
    end
  end

  private def system_fsync(flush_metadata = true) : Nil
    if LibC._commit(fd) != 0
      raise IO::Error.from_errno("Error syncing file")
    end
  end
end
