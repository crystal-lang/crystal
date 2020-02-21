class File < IO::FileDescriptor
end

class File::Error < IO::Error
  getter file : String
  getter other : String?

  private def self.new_from_errno(message, errno, **opts)
    if errno == Errno::ENOENT
      File::NotFoundError.new(message, **opts)
    else
      File::Error.new(message, **opts)
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
