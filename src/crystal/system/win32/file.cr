require "c/io"
require "c/fcntl"
require "c/fileapi"
require "c/sys/utime"
require "c/sys/stat"

module Crystal::System::File
  def self.open(filename : String, mode : String, perm : Int32 | ::File::Permissions) : LibC::Int
    perm = ::File::Permissions.new(perm) if perm.is_a? Int32
    oflag = open_flag(mode) | LibC::O_BINARY

    # Only the owner writable bit is used, since windows only supports
    # the read only attribute.
    if perm.owner_write?
      perm = LibC::S_IREAD | LibC::S_IWRITE
    else
      perm = LibC::S_IREAD
    end

    fd = LibC._wopen(to_windows_path(filename), oflag, perm)
    if fd == -1
      raise Errno.new("Error opening file #{filename.inspect} with mode #{mode.inspect}")
    end

    fd
  end

  def self.mktemp(prefix : String, suffix : String?, dir : String) : {LibC::Int, String}
    path = "#{tempdir}\\#{prefix}.#{::Random::Secure.hex}#{suffix}"

    fd = LibC._wopen(to_windows_path(path), LibC::O_RDWR | LibC::O_CREAT | LibC::O_EXCL | LibC::O_BINARY, ::File::DEFAULT_CREATE_PERMISSIONS)
    if fd == -1
      raise Errno.new("Error creating temporary file at #{path.inspect}")
    end

    {fd, path}
  end

  NOT_FOUND_ERRORS = {
    WinError::ERROR_FILE_NOT_FOUND,
    WinError::ERROR_PATH_NOT_FOUND,
    WinError::ERROR_INVALID_NAME,
  }

  REPARSE_TAG_NAME_SURROGATE_MASK = 1 << 29

  private def self.check_not_found_error(func_name)
    error = LibC.GetLastError
    if NOT_FOUND_ERRORS.includes? error
      return nil
    else
      raise WinError.new(func_name, error)
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
      return check_not_found_error("GetFileAttributesEx") if ret == 0

      if file_attributes.dwFileAttributes.bits_set? LibC::FILE_ATTRIBUTE_REPARSE_POINT
        # Could be a symlink, retrieve it's reparse tag with FindFirstFile
        handle = LibC.FindFirstFileW(winpath, out find_data)
        return check_not_found_error("FindFirstFile") if handle == LibC::INVALID_HANDLE_VALUE

        if LibC.FindClose(handle) == 0
          raise WinError.new("FindClose")
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

    return check_not_found_error("CreateFile") if handle == LibC::INVALID_HANDLE_VALUE

    begin
      if LibC.GetFileInformationByHandle(handle, out file_info) == 0
        raise WinError.new("GetFileInformationByHandle")
      end

      FileInfo.new(file_info, LibC::FILE_TYPE_DISK)
    ensure
      LibC.CloseHandle(handle)
    end
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
      raise WinError.new("GetFileAttributes")
    end

    # Only the owner writable bit is used, since windows only supports
    # the read only attribute.
    if mode.owner_write?
      attributes &= ~LibC::FILE_ATTRIBUTE_READONLY
    else
      attributes |= LibC::FILE_ATTRIBUTE_READONLY
    end

    if LibC.SetFileAttributesW(to_windows_path(path), attributes) == 0
      raise WinError.new("SetFileAttributes")
    end
  end

  def self.delete(path : String) : Nil
    if LibC._wunlink(to_windows_path(path)) != 0
      raise Errno.new("Error deleting file #{path.inspect}")
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
        raise WinError.new("Error resolving real path of #{path.inspect}")
      end
    end

    unless exists? real_path
      raise Errno.new("Error resolving real path of #{path.inspect}", Errno::ENOTDIR)
    end

    real_path
  end

  def self.link(old_path : String, new_path : String) : Nil
    if LibC.CreateHardLinkW(to_windows_path(new_path), to_windows_path(old_path), nil) == 0
      raise WinError.new("Error creating hard link from #{new_path.inspect} to #{old_path.inspect}")
    end
  end

  def self.symlink(old_path : String, new_path : String) : Nil
    # TODO: support directory symlinks (copy Go's stdlib logic here)
    if LibC.CreateSymbolicLinkW(to_windows_path(new_path), to_windows_path(old_path), 0) == 0
      raise WinError.new("Error creating symbolic link from #{new_path.inspect} to #{old_path.inspect}")
    end
  end

  def self.rename(old_path : String, new_path : String) : Nil
    if LibC._wrename(to_windows_path(old_path), to_windows_path(new_path)) != 0
      raise Errno.new("Error renaming file from #{old_path.inspect} to #{new_path.inspect}")
    end
  end

  def self.utime(access_time : ::Time, modification_time : ::Time, path : String) : Nil
    times = LibC::Utimbuf64.new
    times.actime = access_time.epoch
    times.modtime = modification_time.epoch

    if LibC._wutime64(to_windows_path(path), pointerof(times)) != 0
      raise Errno.new("Error setting time on file #{path.inspect}")
    end
  end

  private def system_truncate(size : Int) : Nil
    if LibC._chsize(@fd, size) != 0
      raise Errno.new("Error truncating file #{path.inspect}")
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
end
