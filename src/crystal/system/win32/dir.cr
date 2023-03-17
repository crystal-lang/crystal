require "crystal/system/windows"
require "c/winbase"
require "c/direct"
require "c/handleapi"
require "c/processenv"

module Crystal::System::Dir
  private class DirHandle
    property handle : LibC::HANDLE
    getter query : LibC::LPWSTR

    def initialize(@handle, @query)
    end
  end

  def self.open(path : String) : DirHandle
    unless ::Dir.exists? path
      raise ::File::Error.from_os_error("Error opening directory", Errno::ENOENT, file: path)
    end

    DirHandle.new(LibC::INVALID_HANDLE_VALUE, System.to_wstr(path + "\\*"))
  end

  def self.next_entry(dir : DirHandle, path : String) : Entry?
    if dir.handle == LibC::INVALID_HANDLE_VALUE
      # Directory is at start, use FindFirstFile
      handle = LibC.FindFirstFileW(dir.query, out data)
      if handle != LibC::INVALID_HANDLE_VALUE
        dir.handle = handle
        data_to_entry(data)
      else
        error = WinError.value
        if error == WinError::ERROR_FILE_NOT_FOUND
          nil
        else
          raise ::File::Error.from_os_error("Error reading directory entries", error, file: path)
        end
      end
    else
      # Use FindNextFile
      if LibC.FindNextFileW(dir.handle, out data_) != 0
        data_to_entry(data_)
      else
        error = WinError.value
        if error == WinError::ERROR_NO_MORE_FILES
          nil
        else
          raise ::File::Error.from_os_error("Error reading directory entries", error, file: path)
        end
      end
    end
  end

  def self.data_to_entry(data)
    name = String.from_utf16(data.cFileName.to_unsafe)[0]
    dir = (data.dwFileAttributes & LibC::FILE_ATTRIBUTE_DIRECTORY) != 0
    hidden = data.dwFileAttributes.bits_set?(LibC::FILE_ATTRIBUTE_HIDDEN)
    Entry.new(name, dir, hidden)
  end

  def self.rewind(dir : DirHandle) : Nil
    close(dir)
  end

  def self.info(dir : DirHandle, path) : ::File::Info
    if dir.handle == LibC::INVALID_HANDLE_VALUE
      handle = LibC.FindFirstFileW(dir.query, out data)
      begin
        Crystal::System::FileDescriptor.system_info handle, LibC::FILE_TYPE_DISK
      ensure
        close(handle, path) rescue nil
      end
    else
      Crystal::System::FileDescriptor.system_info dir.handle, LibC::FILE_TYPE_DISK
    end
  end

  def self.close(dir : DirHandle, path : String) : Nil
    close(dir.handle, path)
    dir.handle = LibC::INVALID_HANDLE_VALUE
  end

  def self.close(handle : LibC::HANDLE, path : String) : Nil
    return if handle == LibC::INVALID_HANDLE_VALUE

    if LibC.FindClose(handle) == 0
      raise ::File::Error.from_winerror("Error closing directory", file: path)
    end
  end

  def self.current : String
    System.retry_wstr_buffer do |buffer, small_buf|
      len = LibC.GetCurrentDirectoryW(buffer.size, buffer)
      if 0 < len < buffer.size
        return String.from_utf16(buffer[0, len])
      elsif small_buf && len > 0
        next len
      else
        raise ::File::Error.from_winerror("Error getting current directory", file: "./")
      end
    end
  end

  def self.current=(path : String) : String
    if LibC.SetCurrentDirectoryW(System.to_wstr(path)) == 0
      raise ::File::Error.from_winerror("Error while changing directory", file: path)
    end

    path
  end

  def self.tempdir : String
    tmpdir = System.retry_wstr_buffer do |buffer, small_buf|
      len = LibC.GetTempPathW(buffer.size, buffer)
      if 0 < len < buffer.size
        break String.from_utf16(buffer[0, len])
      elsif small_buf && len > 0
        next len
      else
        raise RuntimeError.from_winerror("Error getting temporary directory")
      end
    end

    tmpdir.rchop("\\")
  end

  def self.create(path : String, mode : Int32) : Nil
    if LibC._wmkdir(System.to_wstr(path)) == -1
      raise ::File::Error.from_errno("Unable to create directory", file: path)
    end
  end

  def self.delete(path : String, *, raise_on_missing : Bool) : Bool
    return true if LibC._wrmdir(System.to_wstr(path)) == 0

    if !raise_on_missing && Errno.value == Errno::ENOENT
      false
    else
      raise ::File::Error.from_errno("Unable to remove directory", file: path)
    end
  end
end
