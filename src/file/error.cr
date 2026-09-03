class File < IO::FileDescriptor
end

class File::Error < IO::Error
  getter other : String?

  def file : String
    target.not_nil!
  end

  private def self.new_from_os_error(message, os_error, **opts)
    case
    when File::NotFoundError.os_error?(os_error)
      File::NotFoundError.new(message, **opts)
    when File::AlreadyExistsError.os_error?(os_error)
      File::AlreadyExistsError.new(message, **opts)
    when File::AccessDeniedError.os_error?(os_error)
      File::AccessDeniedError.new(message, **opts)
    when File::BadExecutableError.os_error?(os_error)
      File::BadExecutableError.new(message, **opts)
    else
      super message, os_error, **opts
    end
  end

  def initialize(message, *, file : String | Path, @other : String? = nil)
    super message, target: file
  end

  protected def self.build_message(message, *, file : String) : String
    "#{message}: '#{file.inspect_unquoted}'"
  end

  protected def self.build_message(message, *, file : String, other : String) : String
    "#{message}: '#{file.inspect_unquoted}' -> '#{other.inspect_unquoted}'"
  end

  {% if flag?(:win32) %}
    protected def self.os_error_message(os_error : WinError, *, file : String) : String?
      case os_error
      when WinError::ERROR_BAD_EXE_FORMAT
        os_error.formatted_message(file)
      else
        super
      end
    end
  {% end %}
end

class File::NotFoundError < File::Error
  # :nodoc:
  # See https://github.com/crystal-lang/crystal/issues/15905#issuecomment-2975820840
  def self.os_error?(error)
    error.in?(
      Errno::ENAMETOOLONG,
      Errno::ENOENT,
      Errno::ENOTDIR,
      WinError::ERROR_BAD_NETPATH,
      WinError::ERROR_BAD_NET_NAME,
      WinError::ERROR_BAD_PATHNAME,
      WinError::ERROR_DIRECTORY,
      WinError::ERROR_FILE_NOT_FOUND,
      WinError::ERROR_FILENAME_EXCED_RANGE,
      WinError::ERROR_INVALID_DRIVE,
      WinError::ERROR_INVALID_NAME,
      WinError::ERROR_PATH_NOT_FOUND,
      WinError::WSAENAMETOOLONG,
    )
  end
end

class File::AlreadyExistsError < File::Error
  # :nodoc:
  def self.os_error?(error)
    error.in?(
      Errno::EEXIST,
      WinError::ERROR_ALREADY_EXISTS,
      WinError::ERROR_FILE_EXISTS,
    )
  end
end

class File::AccessDeniedError < File::Error
  # :nodoc:
  def self.os_error?(error)
    error.in?(
      Errno::EACCES,
      WinError::ERROR_ACCESS_DENIED,
      WinError::ERROR_PRIVILEGE_NOT_HELD,
    )
  end
end

class File::BadExecutableError < File::Error
  # :nodoc:
  def self.os_error?(error)
    error.in?(
      Errno::ENOEXEC,
      WinError::ERROR_BAD_EXE_FORMAT,
    )
  end
end
