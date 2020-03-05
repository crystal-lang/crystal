class File < IO::FileDescriptor
end

class File::Error < IO::Error
  getter file : String
  getter other : String?

  private def self.new_from_errno(message, errno, **opts)
    if errno == Errno::ENOENT
      File::NotFoundError.new(message, **opts)
    else
      super message, errno, **opts
    end
  end

  private def self.new_from_winerror(message, code, **opts)
    case code
    when WinError::ERROR_FILE_NOT_FOUND, WinError::ERROR_PATH_NOT_FOUND, WinError::ERROR_INVALID_DRIVE,
         WinError::ERROR_NO_MORE_FILES, WinError::ERROR_BAD_NETPATH, WinError::ERROR_BAD_NET_NAME, WinError::ERROR_BAD_PATHNAME,
         WinError::ERROR_FILENAME_EXCED_RANGE
      File::NotFoundError.new(message, **opts)
    else
      super message, code, **opts
    end
  end

  protected def self.build_message(message, *, file : String)
    "#{message}: '#{file.inspect_unquoted}'"
  end

  protected def self.build_message(message, *, file : String, other : String)
    "#{message}: '#{file.inspect_unquoted}' -> '#{other.inspect_unquoted}'"
  end

  def initialize(message, *, @file : String, @other : String? = nil)
    super message
  end
end

class File::NotFoundError < File::Error
end
