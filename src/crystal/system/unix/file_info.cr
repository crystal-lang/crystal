struct Crystal::System::FileInfo < ::File::Info
  def initialize(@stat : LibC::Stat)
  end

  def size : UInt64
    @stat.st_size.to_u64
  end

  def permissions : ::File::Permissions
    ::File::Permissions.new((@stat.st_mode & 0o777).to_i16)
  end

  def type : ::File::Type
    case @stat.st_mode & LibC::S_IFMT
    when LibC::S_IFBLK
      ::File::Type::BlockDevice
    when LibC::S_IFCHR
      ::File::Type::CharacterDevice
    when LibC::S_IFDIR
      ::File::Type::Directory
    when LibC::S_IFIFO
      ::File::Type::Pipe
    when LibC::S_IFLNK
      ::File::Type::Symlink
    when LibC::S_IFREG
      ::File::Type::File
    when LibC::S_IFSOCK
      ::File::Type::Socket
    else
      ::File::Type::Unknown
    end
  end

  def flags : ::File::Flags
    flags = ::File::Flags::None
    flags |= ::File::Flags::SetUser if @stat.st_mode.bits_set? LibC::S_ISUID
    flags |= ::File::Flags::SetGroup if @stat.st_mode.bits_set? LibC::S_ISGID
    flags |= ::File::Flags::Sticky if @stat.st_mode.bits_set? LibC::S_ISVTX
    flags
  end

  def modification_time : ::Time
    {% if flag?(:darwin) %}
      ::Time.new(@stat.st_mtimespec, ::Time::Location::UTC)
    {% else %}
      ::Time.new(@stat.st_mtim, ::Time::Location::UTC)
    {% end %}
  end

  def owner : UInt32
    @stat.st_uid.to_u32
  end

  def group : UInt32
    @stat.st_gid.to_u32
  end

  def same_file?(other : ::File::Info) : Bool
    @stat.st_dev == other.@stat.st_dev && @stat.st_ino == other.@stat.st_ino
  end
end
