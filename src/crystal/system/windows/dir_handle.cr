require "c/winapi"
require "winerror"

struct Crystal::System::DirHandle
  @dir_handle : LibC::Handle

  def initialize(path : String)
    if !DirHandle.exists?(path)
      raise WinError.new("Error opening directory '#{path}'")
    end
    @dir_handle = LibC::INVALID_HANDLE_VALUE
  end

  def read
    data = LibC::WIN32_FIND_DATA_A.new
    if @dir_handle == LibC::INVALID_HANDLE_VALUE
      @dir_handle = LibC.FindFirstFileA((path + "\\*").check_no_null_byte, pointerof(data))
      if @dir_handle == LibC::INVALID_HANDLE_VALUE
        raise WinError.new("FindFirstFileA")
      end
    elsif LibC.FindNextFileA(@dir_handle, pointerof(data)) == 0
      error = LibC.GetLastError
      if error == WinError::ERROR_NO_MORE_FILES
        return nil
      else
        raise WinError.new("FindNextFileA", error)
      end
    end
    String.new(data.cFileName.to_slice)
  end

  def rewind
    close
  end

  def close
    if @dir_handle != LibC::INVALID_HANDLE_VALUE
      if LibC.FindClose(@dir_handle) == 0
        raise WinError.new("FindClose")
      end
      @dir_handle = LibC::INVALID_HANDLE_VALUE
    end
  end

  def self.current : String
    len = LibC.GetCurrentDirectoryA(0, nil)
    if len == 0
      raise WinError.new("_GetCurrentDirectoryA")
    end
    String.new(len) do |buffer|
      if LibC.GetCurrentDirectoryA(len, buffer) == 0
        raise WinError.new("_GetCurrentDirectoryA")
      end
      {len - 1, len - 1} # remove \0 at the end
    end
  end

  def self.cd(path : String)
    if LibC.SetCurrentDirectoryA(path.check_no_null_byte) == 0
      raise WinError.new("Error while changing directory to #{path.inspect}")
    end
  end

  def self.exists?(path : String) : Bool
    atr = LibC.GetFileAttributesA(path.check_no_null_byte)
    if (atr == LibWindows::INVALID_FILE_ATTRIBUTES)
      return false
    end
    return atr & LibC::FILE_ATTRIBUTE_DIRECTORY != 0
  end

  def self.mkdir(path : String, mode)
    if LibC.CreateDirectoryA(path.check_no_null_byte, nil) == 0
      raise WinError.new("Unable to create directory '#{path}'")
    end
  end

  def self.rmdir(path : String)
    if LibC.RemoveDirectoryA(path.check_no_null_byte) == 0
      raise WinError.new("Unable to remove directory '#{path}'")
    end
  end
end
