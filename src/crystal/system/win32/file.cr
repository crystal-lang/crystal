require "c/io"
require "c/fcntl"
require "c/fileapi"
require "c/sys/utime"
require "c/sys/stat"
require "c/winbase"
require "c/handleapi"
require "c/ntifs"
require "c/winioctl"

module Crystal::System::File
  # On Windows we cannot rely on the system mode `FILE_APPEND_DATA` and
  # keep track of append mode explicitly. When writing data, this ensures to only
  # write at the end of the file.
  @system_append = false

  def self.open(filename : String, mode : String, perm : Int32 | ::File::Permissions, blocking : Bool?) : FileDescriptor::Handle
    perm = ::File::Permissions.new(perm) if perm.is_a? Int32
    # Only the owner writable bit is used, since windows only supports
    # the read only attribute.
    if perm.owner_write?
      perm = LibC::S_IREAD | LibC::S_IWRITE
    else
      perm = LibC::S_IREAD
    end

    handle, error = open(filename, open_flag(mode), ::File::Permissions.new(perm), blocking != false)
    unless error.error_success?
      raise ::File::Error.from_os_error("Error opening file with mode '#{mode}'", error, file: filename)
    end

    handle
  end

  def self.open(filename : String, flags : Int32, perm : ::File::Permissions, blocking : Bool) : {FileDescriptor::Handle, WinError}
    access, disposition, attributes = self.posix_to_open_opts flags, perm, blocking

    handle = LibC.CreateFileW(
      System.to_wstr(filename),
      access,
      LibC::DEFAULT_SHARE_MODE, # UNIX semantics
      nil,
      disposition,
      attributes,
      LibC::HANDLE.null
    )

    {handle.address, handle == LibC::INVALID_HANDLE_VALUE ? WinError.value : WinError::ERROR_SUCCESS}
  end

  private def self.posix_to_open_opts(flags : Int32, perm : ::File::Permissions, blocking : Bool)
    access = if flags.bits_set? LibC::O_WRONLY
               LibC::FILE_GENERIC_WRITE
             elsif flags.bits_set? LibC::O_RDWR
               LibC::FILE_GENERIC_READ | LibC::FILE_GENERIC_WRITE
             else
               LibC::FILE_GENERIC_READ
             end

    # do not handle `O_APPEND`, because Win32 append mode relies on removing
    # `FILE_WRITE_DATA` which breaks file truncation and locking; instead,
    # simply set the end of the file as the write offset in `#write_blocking`

    if flags.bits_set? LibC::O_TRUNC
      if flags.bits_set? LibC::O_CREAT
        disposition = LibC::CREATE_ALWAYS
      else
        disposition = LibC::TRUNCATE_EXISTING
      end
    elsif flags.bits_set? LibC::O_CREAT
      if flags.bits_set? LibC::O_EXCL
        disposition = LibC::CREATE_NEW
      else
        disposition = LibC::OPEN_ALWAYS
      end
    else
      disposition = LibC::OPEN_EXISTING
    end

    attributes = 0
    unless perm.owner_write?
      attributes |= LibC::FILE_ATTRIBUTE_READONLY
    end

    if flags.bits_set? LibC::O_TEMPORARY
      attributes |= LibC::FILE_FLAG_DELETE_ON_CLOSE | LibC::FILE_ATTRIBUTE_TEMPORARY
      access |= LibC::DELETE
    end

    if flags.bits_set? LibC::O_SHORT_LIVED
      attributes |= LibC::FILE_ATTRIBUTE_TEMPORARY
    end

    if flags.bits_set? LibC::O_SEQUENTIAL
      attributes |= LibC::FILE_FLAG_SEQUENTIAL_SCAN
    elsif flags.bits_set? LibC::O_RANDOM
      attributes |= LibC::FILE_FLAG_RANDOM_ACCESS
    end

    unless blocking
      attributes |= LibC::FILE_FLAG_OVERLAPPED
    end

    {access, disposition, attributes}
  end

  protected def system_set_mode(mode : String)
    @system_append = true if mode.starts_with?('a')
  end

  private def write_blocking(handle, slice)
    write_blocking(handle, slice, pos: @system_append ? UInt64::MAX : nil)
  end

  NOT_FOUND_ERRORS = {
    WinError::ERROR_FILE_NOT_FOUND,
    WinError::ERROR_PATH_NOT_FOUND,
    WinError::ERROR_INVALID_NAME,
    WinError::ERROR_DIRECTORY,
  }

  def self.check_not_found_error(message, path)
    error = WinError.value
    if NOT_FOUND_ERRORS.includes? error
      nil
    else
      raise ::File::Error.from_os_error(message, error, file: path)
    end
  end

  def self.info?(path : String, follow_symlinks : Bool) : ::File::Info?
    winpath = System.to_wstr(path)

    # First try using GetFileAttributes to check if it's a reparse point
    file_attributes = uninitialized LibC::WIN32_FILE_ATTRIBUTE_DATA
    ret = LibC.GetFileAttributesExW(
      winpath,
      LibC::GET_FILEEX_INFO_LEVELS::GetFileExInfoStandard,
      pointerof(file_attributes)
    )
    if ret != 0
      if file_attributes.dwFileAttributes.bits_set? LibC::FILE_ATTRIBUTE_REPARSE_POINT
        # Could be a symlink, retrieve its reparse tag with FindFirstFile
        handle = LibC.FindFirstFileW(winpath, out find_data)
        return check_not_found_error("Unable to get file info", path) if handle == LibC::INVALID_HANDLE_VALUE

        if LibC.FindClose(handle) == 0
          raise RuntimeError.from_winerror("FindClose")
        end

        case find_data.dwReserved0
        when LibC::IO_REPARSE_TAG_SYMLINK
          return ::File::Info.new(find_data) unless follow_symlinks
        when LibC::IO_REPARSE_TAG_AF_UNIX
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
      FileDescriptor.system_info(handle)
    ensure
      LibC.CloseHandle(handle)
    end
  end

  def self.info(path, follow_symlinks)
    info?(path, follow_symlinks) || raise ::File::Error.from_winerror("Unable to get file info", file: path)
  end

  def self.exists?(path, *, follow_symlinks = true)
    accessible?(path, check_writable: false, follow_symlinks: follow_symlinks)
  end

  def self.readable?(path) : Bool
    accessible?(path, check_writable: false, follow_symlinks: true)
  end

  def self.writable?(path) : Bool
    accessible?(path, check_writable: true, follow_symlinks: true)
  end

  def self.executable?(path) : Bool
    # NOTE: this always follows symlinks:
    # https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getbinarytypew#remarks
    LibC.GetBinaryTypeW(System.to_wstr(path), out result) != 0
  end

  private def self.accessible?(path, *, check_writable, follow_symlinks)
    if follow_symlinks
      path = realpath?(path) || return false
    end

    attributes = LibC.GetFileAttributesW(System.to_wstr(path))
    return false if attributes == LibC::INVALID_FILE_ATTRIBUTES
    return true if attributes.bits_set?(LibC::FILE_ATTRIBUTE_DIRECTORY)
    return false if check_writable && attributes.bits_set?(LibC::FILE_ATTRIBUTE_READONLY)

    true
  end

  def self.chown(path : String, uid : Int32, gid : Int32, follow_symlinks : Bool) : Nil
    raise NotImplementedError.new("File.chown")
  end

  def self.fchown(path : String, fd : Int, uid : Int32, gid : Int32) : Nil
    raise NotImplementedError.new("File#chown")
  end

  def self.chmod(path : String, mode : Int32 | ::File::Permissions) : Nil
    mode = ::File::Permissions.new(mode) unless mode.is_a? ::File::Permissions

    unless exists?(path, follow_symlinks: false)
      raise ::File::Error.from_os_error("Error changing permissions", Errno::ENOENT, file: path)
    end

    path = realpath(path)

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

  private def system_chmod(path : String, mode : Int32 | ::File::Permissions) : Nil
    mode = ::File::Permissions.new(mode) unless mode.is_a? ::File::Permissions
    handle = windows_handle

    basic_info = uninitialized LibC::FILE_BASIC_INFO
    if LibC.GetFileInformationByHandleEx(handle, LibC::FILE_INFO_BY_HANDLE_CLASS::FileBasicInfo, pointerof(basic_info), sizeof(typeof(basic_info))) == 0
      raise ::File::Error.from_winerror("Error changing permissions", file: path)
    end

    # Only the owner writable bit is used, since windows only supports
    # the read only attribute.
    if mode.owner_write?
      basic_info.fileAttributes &= ~LibC::FILE_ATTRIBUTE_READONLY
    else
      basic_info.fileAttributes |= LibC::FILE_ATTRIBUTE_READONLY
    end

    if LibC.SetFileInformationByHandle(handle, LibC::FILE_INFO_BY_HANDLE_CLASS::FileBasicInfo, pointerof(basic_info), sizeof(typeof(basic_info))) == 0
      raise ::File::Error.from_winerror("Error changing permissions", file: path)
    end
  end

  def self.delete(path : String, *, raise_on_missing : Bool) : Bool
    win_path = System.to_wstr(path)

    attributes = LibC.GetFileAttributesW(win_path)
    if attributes == LibC::INVALID_FILE_ATTRIBUTES
      check_not_found_error("Error deleting file", path)
      raise ::File::Error.from_os_error("Error deleting file", Errno::ENOENT, file: path) if raise_on_missing
      return false
    end

    # Windows cannot delete read-only files, so we unset the attribute here, but
    # restore it afterwards if deletion still failed
    read_only_removed = false
    if attributes.bits_set?(LibC::FILE_ATTRIBUTE_READONLY)
      if LibC.SetFileAttributesW(win_path, attributes & ~LibC::FILE_ATTRIBUTE_READONLY) != 0
        read_only_removed = true
      end
    end

    # all reparse point directories should be deleted like a directory, not just
    # symbolic links, so we don't care about the reparse tag here
    is_reparse_dir = attributes.bits_set?(LibC::FILE_ATTRIBUTE_REPARSE_POINT) && attributes.bits_set?(LibC::FILE_ATTRIBUTE_DIRECTORY)
    result = is_reparse_dir ? LibC.RemoveDirectoryW(win_path) : LibC.DeleteFileW(win_path)
    return true if result != 0
    LibC.SetFileAttributesW(win_path, attributes) if read_only_removed
    raise ::File::Error.from_winerror("Error deleting file", file: path)
  end

  private REALPATH_SYMLINK_LIMIT = 100

  private def self.realpath?(path : String) : String?
    REALPATH_SYMLINK_LIMIT.times do
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

      if symlink_info = symlink_info?(realpath)
        new_path, is_relative = symlink_info
        path = is_relative ? ::File.expand_path(new_path, ::File.dirname(realpath)) : new_path
        next
      end

      return exists?(realpath, follow_symlinks: false) ? realpath : nil
    end

    raise ::File::Error.from_os_error("Too many symbolic links", Errno::ELOOP, file: path)
  end

  def self.realpath(path : String) : String
    realpath?(path) || raise ::File::Error.from_os_error("Error resolving real path", Errno::ENOENT, file: path)
  end

  def self.link(old_path : String, new_path : String) : Nil
    if LibC.CreateHardLinkW(System.to_wstr(new_path), System.to_wstr(old_path), nil) == 0
      raise ::File::Error.from_winerror("Error creating link", file: old_path, other: new_path)
    end
  end

  def self.symlink(old_path : String, new_path : String) : Nil
    win_old_path = System.to_wstr(old_path.gsub('/', '\\'))
    win_new_path = System.to_wstr(new_path)
    info = info?(old_path, true)
    flags = info.try(&.type.directory?) ? LibC::SYMBOLIC_LINK_FLAG_DIRECTORY : 0

    # Symlink on Windows required the SeCreateSymbolicLink privilege. But in the Windows 10
    # Creators Update (1703), Microsoft added the SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE
    # flag, that allows creation symlink without SeCreateSymbolicLink privilege if the computer
    # is in Developer Mode.
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

  private def self.symlink_info?(path)
    handle = LibC.CreateFileW(
      System.to_wstr(path),
      LibC::FILE_READ_ATTRIBUTES,
      LibC::DEFAULT_SHARE_MODE,
      nil,
      LibC::OPEN_EXISTING,
      LibC::FILE_FLAG_BACKUP_SEMANTICS | LibC::FILE_FLAG_OPEN_REPARSE_POINT,
      LibC::HANDLE.null
    )

    return nil if handle == LibC::INVALID_HANDLE_VALUE

    begin
      size = 0x40
      buf = Pointer(UInt8).malloc(size)

      while true
        if LibC.DeviceIoControl(handle, LibC::FSCTL_GET_REPARSE_POINT, nil, 0, buf, size, out _, nil) != 0
          reparse_data = buf.as(LibC::REPARSE_DATA_BUFFER*)
          if reparse_data.value.reparseTag == LibC::IO_REPARSE_TAG_SYMLINK
            symlink_data = reparse_data.value.dummyUnionName.symbolicLinkReparseBuffer
            path_buffer = reparse_data.value.dummyUnionName.symbolicLinkReparseBuffer.pathBuffer.to_unsafe.as(UInt8*)
            is_relative = symlink_data.flags.bits_set?(LibC::SYMLINK_FLAG_RELATIVE)

            # the print name is not necessarily set; fall back to substitute
            # name if unavailable
            if (name_len = symlink_data.printNameLength) > 0
              name_ptr = path_buffer + symlink_data.printNameOffset
              name = String.from_utf16(Slice.new(name_ptr, name_len).unsafe_slice_of(UInt16))
              return {name, is_relative}
            end

            name_len = symlink_data.substituteNameLength
            name_ptr = path_buffer + symlink_data.substituteNameOffset
            name = String.from_utf16(Slice.new(name_ptr, name_len).unsafe_slice_of(UInt16))
            # remove the internal prefix for NT paths which shows up when  e.g.
            # creating a symbolic link with an absolute source
            # TODO: support the other possible paths, for example see
            # https://github.com/golang/go/blob/ab28b834c4a38bd2295ee43eca4f9e38c28d54a2/src/os/file_windows.go#L362
            if name.starts_with?(%q(\??\)) && name[5]? == ':'
              name = name[4..]
            end
            return {name, is_relative}
          else
            # not a symlink (e.g. IO_REPARSE_TAG_AF_UNIX)
            return nil
          end
        end

        return nil if WinError.value != WinError::ERROR_MORE_DATA || size == LibC::MAXIMUM_REPARSE_DATA_BUFFER_SIZE
        size *= 2
        buf = buf.realloc(size)
      end
    ensure
      LibC.CloseHandle(handle)
    end
  end

  def self.readlink(path) : String
    info = symlink_info?(path) || raise ::File::Error.new("Cannot read link", file: path)
    path, _is_relative = info
    path
  end

  def self.rename(old_path : String, new_path : String) : ::File::Error?
    if LibC.MoveFileExW(System.to_wstr(old_path), System.to_wstr(new_path), LibC::MOVEFILE_REPLACE_EXISTING) == 0
      ::File::Error.from_winerror("Error renaming file", file: old_path, other: new_path)
    end
  end

  def self.utime(access_time : ::Time, modification_time : ::Time, path : String) : Nil
    handle = LibC.CreateFileW(
      System.to_wstr(path),
      LibC::FILE_WRITE_ATTRIBUTES,
      LibC::DEFAULT_SHARE_MODE,
      nil,
      LibC::OPEN_EXISTING,
      LibC::FILE_FLAG_BACKUP_SEMANTICS,
      LibC::HANDLE.null
    )
    if handle == LibC::INVALID_HANDLE_VALUE
      raise ::File::Error.from_winerror("Error setting time on file", file: path)
    end

    begin
      utime(handle, access_time, modification_time, path)
    ensure
      LibC.CloseHandle(handle)
    end
  end

  def self.utime(handle : LibC::HANDLE, access_time : ::Time, modification_time : ::Time, path : String) : Nil
    atime = Crystal::System::Time.to_filetime(access_time)
    mtime = Crystal::System::Time.to_filetime(modification_time)
    if LibC.SetFileTime(handle, nil, pointerof(atime), pointerof(mtime)) == 0
      raise ::File::Error.from_winerror("Error setting time on file", file: path)
    end
  end

  private def system_utime(access_time : ::Time, modification_time : ::Time, path : String) : Nil
    Crystal::System::File.utime(windows_handle, access_time, modification_time, path)
  end

  private def system_truncate(size : Int) : Nil
    handle = windows_handle
    if LibC.SetFilePointerEx(handle, size.to_i64, out old_pos, IO::Seek::Set) == 0
      raise ::File::Error.from_winerror("Error truncating file", file: path)
    end
    begin
      if LibC.SetEndOfFile(handle) == 0
        raise ::File::Error.from_winerror("Error truncating file", file: path)
      end
    ensure
      LibC.SetFilePointerEx(handle, old_pos, nil, IO::Seek::Set)
    end
  end
end
