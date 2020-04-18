require "file/mode"

# :nodoc:
module Crystal::System::File
  # Helper method for calculating file open modes on systems with posix-y `open`
  # calls.
  private def self.open_flag(mode : ::File::Mode)
    if mode.overwrite?
      mode |= ::File::Mode::Write | ::File::Mode::Create | ::File::Mode::Truncate
      mode &= ~(::File::Mode::Overwrite)
    end

    flags = 0
    if mode.read? && (mode.write? || mode.append?)
      flags |= LibC::O_RDWR
      flags |= LibC::O_APPEND if mode.append?
      mode &= ~(::File::Mode::Read | ::File::Mode::Write | ::File::Mode::Append)
    end
    mode.each do |m|
      case m
      when ::File::Mode::Read      then flags |= LibC::O_RDONLY
      when ::File::Mode::Write     then flags |= LibC::O_WRONLY
      when ::File::Mode::Create    then flags |= LibC::O_CREAT
      when ::File::Mode::CreateNew then flags |= LibC::O_CREAT | LibC::O_EXCL
      when ::File::Mode::Append    then flags |= LibC::O_WRONLY | LibC::O_APPEND
      when ::File::Mode::Truncate  then flags |= LibC::O_TRUNC
      when ::File::Mode::Sync
        {% if flag?(:win32) %}
          raise NotImplementedError.new("File.open(..., :sync)")
        {% else %}
          flags |= LibC::O_SYNC
        {% end %}
      when ::File::Mode::SymlinkNoFollow
        {% if flag?(:win32) %}
          raise NotImplementedError.new("File.open(..., :symlink_no_follow)")
        {% else %}
          flags |= LibC::O_NOFOLLOW
        {% end %}
      else
        raise "Unknown mode #{m}"
      end
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

  # Closes the internal file descriptor without notifying libevent.
  # This is directly used after the fork of a process to close the
  # parent's Crystal::Signal.@@pipe reference before re initializing
  # the event loop. In the case of a fork that will exec there is even
  # no need to initialize the event loop at all.
  # def file_descriptor_close
end

{% if flag?(:unix) %}
  require "./unix/file"
{% elsif flag?(:win32) %}
  require "./win32/file"
{% else %}
  {% raise "No Crystal::System::File implementation available" %}
{% end %}
