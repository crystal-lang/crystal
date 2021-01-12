class File < IO::FileDescriptor
end

class File::Error < IO::Error
  getter file : String
  getter other : String?

  private def self.new_from_errno(message, errno, **opts)
    case errno
    when Errno::ENOENT
      File::NotFoundError.new(message, **opts)
    when Errno::EEXIST
      File::AlreadyExistsError.new(message, **opts)
    when Errno::EACCES
      File::AccessDeniedError.new(message, **opts)
    else
      super message, errno, **opts
    end
  end

  protected def self.build_message(message, *, file : String)
    "#{message}: '#{file.inspect_unquoted}'"
  end

  protected def self.build_message(message, *, file : String, other : String)
    "#{message}: '#{file.inspect_unquoted}' -> '#{other.inspect_unquoted}'"
  end

  def initialize(message, *, file : String | Path, @other : String? = nil)
    @file = file.to_s
    super message
  end
end

class File::NotFoundError < File::Error
end

class File::AlreadyExistsError < File::Error
end

class File::AccessDeniedError < File::Error
end
