require "file/mode"

# :nodoc:
module Crystal::System::File
  private ModeMap = {
    ::File::Mode::Read      => LibC::O_RDONLY,
    ::File::Mode::Write     => LibC::O_WRONLY,
    ::File::Mode::ReadWrite => LibC::O_RDWR,

    ::File::Mode::Create    => LibC::O_CREAT,
    ::File::Mode::CreateNew => LibC::O_CREAT | LibC::O_EXCL,
    ::File::Mode::Append    => LibC::O_APPEND,
    ::File::Mode::Truncate  => LibC::O_TRUNC,

    ::File::Mode::Sync            => LibC::O_SYNC,
    ::File::Mode::SymlinkNoFollow => LibC::O_NOFOLLOW,
  }

  # Helper method for calculating file open modes on systems with posix-y `open`
  # calls.
  private def self.open_flag(mode : ::File::Mode)
    flags = 0
    # Missing hash key?
    #    mode.each do |key|
    #      flags |= ModeMap[key]
    ModeMap.each do |key, val|
      flags |= val if mode.includes?(key)
    end
    flags
  end

  # Helper method for calculating file open modes on systems with posix-y `open`
  # calls.
  private def self.open_flag(mode : String)
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
    else
      raise "Invalid file open mode: '#{mode}'"
    end

    oflag = m | o
  end
end

{% if flag?(:unix) %}
  require "./unix/file"
{% elsif flag?(:win32) %}
  require "./win32/file"
{% else %}
  {% raise "No Crystal::System::File implementation available" %}
{% end %}
