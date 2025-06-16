class File < IO::FileDescriptor
end

class File::Error < IO::Error
  getter other : String?

  def file : String
    target.not_nil!
  end

  private def self.new_from_os_error(message, os_error, **opts)
    case os_error
    when .in?(File::NotFoundError::OS_ERRORS)
      File::NotFoundError.new(message, **opts)
    when .in?(File::AlreadyExistsError::OS_ERRORS)
      File::AlreadyExistsError.new(message, **opts)
    when .in?(File::AccessDeniedError::OS_ERRORS)
      File::AccessDeniedError.new(message, **opts)
    when .in?(File::BadExecutableError::OS_ERRORS)
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
  OS_ERRORS = [
    Errno::ENOENT,
    WinError::ERROR_DIRECTORY,
    WinError::ERROR_FILE_NOT_FOUND,
    WinError::ERROR_INVALID_NAME,
    WinError::ERROR_PATH_NOT_FOUND,
  ]
end

class File::AlreadyExistsError < File::Error
  # :nodoc:
  OS_ERRORS = [
    Errno::EEXIST,
    WinError::ERROR_ALREADY_EXISTS,
  ]
end

class File::AccessDeniedError < File::Error
  # :nodoc:
  OS_ERRORS = [
    Errno::EACCES,
    WinError::ERROR_ACCESS_DENIED,
    WinError::ERROR_PRIVILEGE_NOT_HELD,
  ]
end

class File::BadExecutableError < File::Error
  # :nodoc:
  OS_ERRORS = [
    Errno::ENOEXEC,
    WinError::ERROR_BAD_EXE_FORMAT,
  ]
end
