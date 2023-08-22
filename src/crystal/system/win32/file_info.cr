module Crystal::System::FileInfo
  protected getter file_attributes

  def initialize(@file_attributes : LibC::BY_HANDLE_FILE_INFORMATION, @file_type : LibC::DWORD)
    @reparse_tag = LibC::DWORD.new(0)
  end

  def initialize(file_attributes : LibC::WIN32_FIND_DATAW)
    @file_attributes = LibC::BY_HANDLE_FILE_INFORMATION.new(
      dwFileAttributes: file_attributes.dwFileAttributes,
      ftCreationTime: file_attributes.ftCreationTime,
      ftLastAccessTime: file_attributes.ftLastAccessTime,
      ftLastWriteTime: file_attributes.ftLastWriteTime,
      dwVolumeSerialNumber: 0,
      nFileSizeHigh: file_attributes.nFileSizeHigh,
      nFileSizeLow: file_attributes.nFileSizeLow,
      nNumberOfLinks: 1,
      nFileIndexHigh: 0,
      nFileIndexLow: 0
    )
    @file_type = LibC::FILE_TYPE_DISK
    @reparse_tag = file_attributes.dwReserved0
  end

  def initialize(@file_type : LibC::DWORD)
    @file_attributes = LibC::BY_HANDLE_FILE_INFORMATION.new
    @reparse_tag = LibC::DWORD.new(0)
  end

  def system_size : Int64
    ((@file_attributes.nFileSizeHigh.to_u64 << 32) | @file_attributes.nFileSizeLow.to_u64).to_i64
  end

  def system_permissions : ::File::Permissions
    if @file_attributes.dwFileAttributes.bits_set? LibC::FILE_ATTRIBUTE_READONLY
      permissions = ::File::Permissions.new(0o444)
    else
      permissions = ::File::Permissions.new(0o666)
    end

    if @file_attributes.dwFileAttributes.bits_set? LibC::FILE_ATTRIBUTE_DIRECTORY
      permissions | ::File::Permissions.new(0o111)
    else
      permissions
    end
  end

  def system_type : ::File::Type
    case @file_type
    when LibC::FILE_TYPE_PIPE
      ::File::Type::Pipe
    when LibC::FILE_TYPE_CHAR
      ::File::Type::CharacterDevice
    when LibC::FILE_TYPE_DISK
      # See: https://msdn.microsoft.com/en-us/library/windows/desktop/aa365511(v=vs.85).aspx
      if @file_attributes.dwFileAttributes.bits_set?(LibC::FILE_ATTRIBUTE_REPARSE_POINT)
        case @reparse_tag
        when LibC::IO_REPARSE_TAG_SYMLINK
          ::File::Type::Symlink
        when LibC::IO_REPARSE_TAG_AF_UNIX
          ::File::Type::Socket
        else
          ::File::Type::Unknown
        end
      elsif @file_attributes.dwFileAttributes.bits_set? LibC::FILE_ATTRIBUTE_DIRECTORY
        ::File::Type::Directory
      else
        ::File::Type::File
      end
    else
      ::File::Type::Unknown
    end
  end

  def system_flags : ::File::Flags
    ::File::Flags::None
  end

  def system_modification_time : ::Time
    Time.from_filetime(@file_attributes.ftLastWriteTime)
  end

  def system_owner_id : String
    "0"
  end

  def system_group_id : String
    "0"
  end

  def system_same_file?(other : self) : Bool
    return false if type.symlink? || type.pipe? || type.character_device?

    @file_attributes.dwVolumeSerialNumber == other.file_attributes.dwVolumeSerialNumber &&
      @file_attributes.nFileIndexHigh == other.file_attributes.nFileIndexHigh &&
      @file_attributes.nFileIndexLow == other.file_attributes.nFileIndexLow
  end
end
