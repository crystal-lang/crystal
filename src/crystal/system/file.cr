# :nodoc:
module Crystal::System::File
  # Helper method for calculating file open modes on systems with posix-y `open`
  # calls.
  private def self.open_flag(mode)
    if mode.size == 0
      raise "No file open mode specified"
    end

    m = 0
    o = 0
    case mode[0]
    when 'r'
      m = LibC::O_RDONLY
    when 'w'
      m = LibC::O_WRONLY
      o = LibC::O_CREAT | LibC::O_TRUNC
    when 'a'
      m = LibC::O_WRONLY
      o = LibC::O_CREAT | LibC::O_APPEND
    else
      raise "Invalid file open mode: '#{mode}'"
    end

    case mode.size
    when 1
      # Nothing
    when 2
      case mode[1]
      when '+'
        m = LibC::O_RDWR
      when 'b'
        # Nothing
      else
        raise "Invalid file open mode: '#{mode}'"
      end
    when 3
      # POSIX allows both `+b` and `b+`: https://pubs.opengroup.org/onlinepubs/9699919799/functions/fopen.html
      unless mode.ends_with?("+b") || mode.ends_with?("b+")
        raise "Invalid file open mode: '#{mode}'"
      end
      m = LibC::O_RDWR
    else
      raise "Invalid file open mode: '#{mode}'"
    end

    m | o
  end

  LOWER_ALPHANUM = "0123456789abcdefghijklmnopqrstuvwxyz".to_slice

  def self.mktemp(prefix : String?, suffix : String?, dir : String, random : ::Random = ::Random::DEFAULT) : {LibC::Int, String}
    mode = LibC::O_RDWR | LibC::O_CREAT | LibC::O_EXCL
    perm = ::File::Permissions.new(0o600)

    prefix = ::File.join(dir, prefix || "")
    bytesize = prefix.bytesize + 8 + (suffix.try(&.bytesize) || 0)

    100.times do
      path = String.build(bytesize) do |io|
        io << prefix
        8.times do
          io.write_byte LOWER_ALPHANUM.sample(random)
        end
        io << suffix
      end

      fd, errno = open(path, mode, perm)

      if errno.none?
        return {fd, path}
      elsif error_is_file_exists?(errno)
        # retry
        next
      else
        raise ::File::Error.from_os_error("Error creating temporary file", errno, file: path)
      end
    end

    raise ::File::AlreadyExistsError.new("Error creating temporary file", file: "#{prefix}********#{suffix}")
  end

  private def self.error_is_file_exists?(errno)
    errno.in?(Errno::EEXIST, WinError::ERROR_ALREADY_EXISTS)
  end

  # Closes the internal file descriptor without notifying libevent.
  # This is directly used after the fork of a process to close the
  # parent's Crystal::System::Signal.@@pipe reference before re initializing
  # the event loop. In the case of a fork that will exec there is even
  # no need to initialize the event loop at all.
  # def file_descriptor_close
end

{% if flag?(:wasi) %}
  require "./wasi/file"
{% elsif flag?(:unix) %}
  require "./unix/file"
{% elsif flag?(:win32) %}
  require "./win32/file"
{% else %}
  {% raise "No Crystal::System::File implementation available" %}
{% end %}
