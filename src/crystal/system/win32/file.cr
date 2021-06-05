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
    oflag = open_flag(mode) | LibC::O_BINARY | LibC::O_NOINHERIT

    # Only the owner writable bit is used, since windows only supports
    # the read only attribute.
    if perm.owner_write?
      perm = LibC::S_IREAD | LibC::S_IWRITE
    else
      perm = LibC::S_IREAD
    end

    fd = LibC._wopen(to_windows_path(filename), oflag, perm)
    if fd == -1
      raise ::File::Error.from_errno("Error opening file with mode '#{mode}'", file: filename)
    end

    fd
  end

  def self.mktemp(prefix : String?, suffix : String?, dir : String) : {LibC::Int, String}
    path = "#{dir}#{::File::SEPARATOR}#{prefix}.#{::Random::Secure.hex}#{suffix}"

    mode = LibC::O_RDWR | LibC::O_CREAT | LibC::O_EXCL | LibC::O_BINARY | LibC::O_NOINHERIT
    fd = LibC._wopen(to_windows_path(path), mode, ::File::DEFAULT_CREATE_PERMISSIONS)
    if fd == -1
      raise ::File::Error.from_errno("Error creating temporary file", file: path)
    end

    {fd, path}
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
      return nil
    else
      raise ::File::Error.from_os_error(message, error, file: path)
    end
  end

  def self.info?(path : String, follow_symlinks : Bool) : ::File::Info?
    winpath = to_windows_path(path)

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
          return FileInfo.new(find_data)
        end
      end
    end

    handle = LibC.CreateFileW(
      to_windows_path(path),
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

      FileInfo.new(file_info, LibC::FILE_TYPE_DISK)
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
    raise NotImplementedError.new("File.executable?")
  end

  private def self.accessible?(path, mode)
    LibC._waccess_s(to_windows_path(path), mode) == 0
  end

  def self.chown(path : String, uid : Int32, gid : Int32, follow_symlinks : Bool) : Nil
    raise NotImplementedError.new("File.chown")
  end

  def self.chmod(path : String, mode : Int32 | ::File::Permissions) : Nil
    mode = ::File::Permissions.new(mode) unless mode.is_a? ::File::Permissions

    # TODO: dereference symlinks

    attributes = LibC.GetFileAttributesW(to_windows_path(path))
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

    if LibC.SetFileAttributesW(to_windows_path(path), attributes) == 0
      raise ::File::Error.from_winerror("Error changing permissions", file: path)
    end
  end

  def self.delete(path : String) : Nil
    if LibC._wunlink(to_windows_path(path)) != 0
      raise ::File::Error.from_errno("Error deleting file", file: path)
    end
  end

  def self.real_path(path : String) : String
    # TODO: read links using https://msdn.microsoft.com/en-us/library/windows/desktop/aa364571(v=vs.85).aspx
    win_path = to_windows_path(path)

    real_path = System.retry_wstr_buffer do |buffer, small_buf|
      len = LibC.GetFullPathNameW(win_path, buffer.size, buffer, nil)
      if 0 < len < buffer.size
        break String.from_utf16(buffer[0, len])
      elsif small_buf && len > 0
        next len
      else
        raise ::File::Error.from_winerror("Error resolving real path", file: path)
      end
    end

    unless exists? real_path
      raise ::File::Error.from_os_error("Error resolving real path", Errno::ENOENT, file: path)
    end

    real_path
  end

  def self.link(old_path : String, new_path : String) : Nil
    if LibC.CreateHardLinkW(to_windows_path(new_path), to_windows_path(old_path), nil) == 0
      raise ::File::Error.from_winerror("Error creating link", file: old_path, other: new_path)
    end
  end

  def self.symlink(old_path : String, new_path : String) : Nil
    # TODO: support directory symlinks (copy Go's stdlib logic here)
    if LibC.CreateSymbolicLinkW(to_windows_path(new_path), to_windows_path(old_path), LibC::SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE) == 0
      raise ::File::Error.from_winerror("Error creating symlink", file: old_path, other: new_path)
    end
  end

  def self.readlink(path) : String
    raise NotImplementedError.new("readlink")
  end

  def self.rename(old_path : String, new_path : String) : Nil
    if LibC.MoveFileExW(to_windows_path(old_path), to_windows_path(new_path), LibC::MOVEFILE_REPLACE_EXISTING) == 0
      raise ::File::Error.from_winerror("Error renaming file", file: old_path, other: new_path)
    end
  end

  def self.utime(access_time : ::Time, modification_time : ::Time, path : String) : Nil
    atime = Crystal::System::Time.to_filetime(access_time)
    mtime = Crystal::System::Time.to_filetime(modification_time)
    handle = LibC.CreateFileW(
      to_windows_path(path),
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

  private def system_truncate(size : Int) : Nil
    if LibC._chsize_s(fd, size) != 0
      raise ::File::Error.from_errno("Error truncating file", file: path)
    end
  end

  private def system_flock_shared(blocking : Bool) : Nil
    raise NotImplementedError.new("File#flock_shared")
  end

  private def system_flock_exclusive(blocking : Bool) : Nil
    raise NotImplementedError.new("File#flock_exclusive")
  end

  private def system_flock_unlock : Nil
    raise NotImplementedError.new("File#flock_unlock")
  end

  private def self.to_windows_path(path : String) : LibC::LPWSTR
    path.check_no_null_byte.to_utf16.to_unsafe
  end

  private def system_fsync(flush_metadata = true) : Nil
    if LibC._commit(fd) != 0
      raise IO::Error.from_errno("Error syncing file")
    end
  end
end
