class File < IO::FileDescriptor
end

class File::Error < IO::Error
  getter other : String?

  def file : String
    target.not_nil!
  end

  private def self.new_from_os_error(message, os_error, **opts)
    case os_error
    when Errno::ENOENT, WinError::ERROR_FILE_NOT_FOUND, WinError::ERROR_PATH_NOT_FOUND
      File::NotFoundError.new(message, **opts)
    when Errno::EEXIST, WinError::ERROR_ALREADY_EXISTS
      File::AlreadyExistsError.new(message, **opts)
    when Errno::EACCES, WinError::ERROR_ACCESS_DENIED, WinError::ERROR_PRIVILEGE_NOT_HELD
      File::AccessDeniedError.new(message, **opts)
    when Errno::ENOEXEC, WinError::ERROR_BAD_EXE_FORMAT
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
end

class File::AlreadyExistsError < File::Error
end

class File::AccessDeniedError < File::Error
end

class File::BadExecutableError < File::Error
end
