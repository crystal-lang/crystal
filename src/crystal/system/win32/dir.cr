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

    DirHandle.new(LibC::INVALID_HANDLE_VALUE, to_windows_path(path + "\\*"))
  end

  def self.next_entry(dir : DirHandle, path : String) : Entry?
    if dir.handle == LibC::INVALID_HANDLE_VALUE
      # Directory is at start, use FindFirstFile
      handle = LibC.FindFirstFileW(dir.query, out data)
      if handle != LibC::INVALID_HANDLE_VALUE
        dir.handle = handle
        return data_to_entry(data)
      else
        error = WinError.value
        if error == WinError::ERROR_FILE_NOT_FOUND
          return nil
        else
          raise ::File::Error.from_os_error("Error reading directory entries", error, file: path)
        end
      end
    else
      # Use FindNextFile
      if LibC.FindNextFileW(dir.handle, out data_) != 0
        return data_to_entry(data_)
      else
        error = WinError.value
        if error == WinError::ERROR_NO_MORE_FILES
          return nil
        else
          raise ::File::Error.from_os_error("Error reading directory entries", error, file: path)
        end
      end
    end
  end

  def self.data_to_entry(data)
    name = String.from_utf16(data.cFileName.to_unsafe)[0]
    dir = (data.dwFileAttributes & LibC::FILE_ATTRIBUTE_DIRECTORY) != 0
    Entry.new(name, dir)
  end

  def self.rewind(dir : DirHandle) : Nil
    close(dir)
  end

  def self.close(dir : DirHandle, path : String) : Nil
    return if dir.handle == LibC::INVALID_HANDLE_VALUE

    if LibC.FindClose(dir.handle) == 0
      raise ::File::Error.from_winerror("Error closing directory", file: path)
    end

    dir.handle = LibC::INVALID_HANDLE_VALUE
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
    if LibC.SetCurrentDirectoryW(to_windows_path(path)) == 0
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
    if LibC._wmkdir(to_windows_path(path)) == -1
      raise ::File::Error.from_errno("Unable to create directory", file: path)
    end
  end

  def self.delete(path : String) : Nil
    if LibC._wrmdir(to_windows_path(path)) == -1
      raise ::File::Error.from_errno("Unable to remove directory", file: path)
    end
  end

  private def self.to_windows_path(path : String) : LibC::LPWSTR
    path.check_no_null_byte.to_utf16.to_unsafe
  end
end
