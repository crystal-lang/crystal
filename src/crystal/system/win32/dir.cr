require "crystal/system/windows"
require "c/winbase"
require "c/direct"

module Crystal::System::Dir
  private class DirHandle
    property handle : LibC::HANDLE
    getter query : LibC::LPWSTR

    def initialize(@handle, @query)
    end
  end

  def self.open(path : String) : DirHandle
    unless ::Dir.exists? path
      raise Errno.new("Error opening directory #{path.inspect}", Errno::ENOENT)
    end

    DirHandle.new(LibC::INVALID_HANDLE_VALUE, to_windows_path(path + "\\*"))
  end

  def self.next(dir : DirHandle) : String?
    if dir.handle == LibC::INVALID_HANDLE_VALUE
      # Directory is at start, use FindFirstFile
      handle = LibC.FindFirstFileW(dir.query, out data)
      if handle != LibC::INVALID_HANDLE_VALUE
        dir.handle = handle
        return String.from_utf16(data.cFileName.to_unsafe)[0]
      else
        error = LibC.GetLastError
        if error == WinError::ERROR_FILE_NOT_FOUND
          return nil
        else
          raise WinError.new("FindFirstFile", error)
        end
      end
    else
      # Use FindNextFile
      if LibC.FindNextFileW(dir.handle, out data_) != 0
        return String.from_utf16(data_.cFileName.to_unsafe)[0]
      else
        error = LibC.GetLastError
        if error == WinError::ERROR_NO_MORE_FILES
          return nil
        else
          raise WinError.new("FindNextFile", error)
        end
      end
    end
  end

  def self.rewind(dir : DirHandle) : Nil
    close(dir)
  end

  def self.close(dir : DirHandle) : Nil
    return if dir.handle == LibC::INVALID_HANDLE_VALUE

    if LibC.FindClose(dir.handle) == 0
      raise WinError.new("FindClose")
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
        raise WinError.new("Error while getting current directory")
      end
    end
  end

  def self.current=(path : String) : String
    if LibC.SetCurrentDirectoryW(to_windows_path(path)) == 0
      raise WinError.new("SetCurrentDirectory")
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
        raise WinError.new("Error while getting current directory")
      end
    end

    tmpdir.rchop("\\")
  end

  def self.create(path : String, mode : Int32) : Nil
    if LibC._wmkdir(to_windows_path(path)) == -1
      raise Errno.new("Unable to create directory '#{path}'")
    end
  end

  def self.delete(path : String) : Nil
    if LibC._wrmdir(to_windows_path(path)) == -1
      raise Errno.new("Unable to remove directory '#{path}'")
    end
  end

  private def self.to_windows_path(path : String) : LibC::LPWSTR
    path.check_no_null_byte.to_utf16.to_unsafe
  end
end
