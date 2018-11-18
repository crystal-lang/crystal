struct Crystal::System::FileInfo < ::File::Info
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

  def size : UInt64
    (@file_attributes.nFileSizeHigh.to_u64 << 32) | @file_attributes.nFileSizeLow.to_u64
  end

  def permissions : ::File::Permissions
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

  def type : ::File::Type
    case @file_type
    when LibC::FILE_TYPE_PIPE
      ::File::Type::Pipe
    when LibC::FILE_TYPE_CHAR
      ::File::Type::CharacterDevice
    when LibC::FILE_TYPE_DISK
      # See: https://msdn.microsoft.com/en-us/library/windows/desktop/aa365511(v=vs.85).aspx
      if @file_attributes.dwFileAttributes.bits_set?(LibC::FILE_ATTRIBUTE_REPARSE_POINT) &&
         @reparse_tag.bits_set? File::REPARSE_TAG_NAME_SURROGATE_MASK
        ::File::Type::Symlink
      elsif @file_attributes.dwFileAttributes.bits_set? LibC::FILE_ATTRIBUTE_DIRECTORY
        ::File::Type::Directory
      else
        ::File::Type::File
      end
    else
      ::File::Type::Unknown
    end
  end

  def flags : ::File::Flags
    ::File::Flags::None
  end

  def modification_time : ::Time
    Time.from_filetime(@file_attributes.ftLastWriteTime)
  end

  def owner : UInt32
    0_u32
  end

  def group : UInt32
    0_u32
  end

  def same_file?(other : ::File::Info) : Bool
    return false if type.symlink? || type.pipe? || type.character_device?

    @file_attributes.dwVolumeSerialNumber == other.file_attributes.dwVolumeSerialNumber &&
      @file_attributes.nFileIndexHigh == other.file_attributes.nFileIndexHigh &&
      @file_attributes.nFileIndexLow == other.file_attributes.nFileIndexLow
  end

  private def to_windows_path(path : String) : LibC::LPWSTR
    path.check_no_null_byte.to_utf16.to_unsafe
  end
end
