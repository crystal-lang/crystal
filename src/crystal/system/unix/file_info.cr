module Crystal::System::FileInfo
  def initialize(@stat : LibC::Stat)
  end

  def system_size : Int64
    @stat.st_size.to_i64
  end

  def system_permissions : ::File::Permissions
    ::File::Permissions.new((@stat.st_mode & 0o777).to_i16)
  end

  def system_type : ::File::Type
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

  def system_flags : ::File::Flags
    flags = ::File::Flags::None
    flags |= ::File::Flags::SetUser if @stat.st_mode.bits_set? LibC::S_ISUID
    flags |= ::File::Flags::SetGroup if @stat.st_mode.bits_set? LibC::S_ISGID
    flags |= ::File::Flags::Sticky if @stat.st_mode.bits_set? LibC::S_ISVTX
    flags
  end

  def system_modification_time : ::Time
    {% if flag?(:darwin) %}
      ::Time.new(@stat.st_mtimespec, ::Time::Location::UTC)
    {% else %}
      ::Time.new(@stat.st_mtim, ::Time::Location::UTC)
    {% end %}
  end

  def system_owner_id : String
    @stat.st_uid.to_s
  end

  def system_group_id : String
    @stat.st_gid.to_s
  end

  def system_same_file?(other : self) : Bool
    @stat.st_dev == other.@stat.st_dev && @stat.st_ino == other.@stat.st_ino
  end
end
