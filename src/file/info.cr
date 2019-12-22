class File
  # Represents the various behaviour-altering flags which can be set on files.
  # Not all flags will be supported on all platforms.
  @[Flags]
  enum Flags : UInt8
    SetUser
    SetGroup
    Sticky
  end

  # Represents the type of a file. Not all types will be supported on all
  # platforms.
  enum Type : UInt8
    File
    Directory
    Symlink
    Socket
    Pipe
    CharacterDevice
    BlockDevice
    Unknown

    # Returns true if `self` is a `CharacterDevice` or a `BlockDevice`.
    def device?
      character_device? || block_device?
    end
  end

  # Represents a set of access permissions for a file. Not all permission sets
  # will be supported on all platforms.
  #
  # The binary representation of this enum is defined to be same representation
  # as the permission bits of a unix `st_mode` field. `File::Permissions`
  # can also be compared to its underlying bitset, for example
  # `File::Permissions::All == 0o777` will always be `true`.
  #
  # On windows, only the `OwnerWrite` bit is effective. All file permissions
  # will either be `0o444` for read-only files or `0o666` for read-write files.
  # Directories are always mode `0o555` for read-only or `0o777`.
  @[Flags]
  enum Permissions : Int16
    OtherExecute = 0o001
    OtherWrite   = 0o002
    OtherRead    = 0o004
    OtherAll     = 0o007

    GroupExecute = 0o010
    GroupWrite   = 0o020
    GroupRead    = 0o040
    GroupAll     = 0o070

    OwnerExecute = 0o100
    OwnerWrite   = 0o200
    OwnerRead    = 0o400
    OwnerAll     = 0o700

    def self.new(int : Int)
      new(int.to_i16)
    end

    def to_s(io : IO) : Nil
      io << (owner_read? ? 'r' : '-')
      io << (owner_write? ? 'w' : '-')
      io << (owner_execute? ? 'x' : '-')

      io << (group_read? ? 'r' : '-')
      io << (group_write? ? 'w' : '-')
      io << (group_execute? ? 'x' : '-')

      io << (other_read? ? 'r' : '-')
      io << (other_write? ? 'w' : '-')
      io << (other_execute? ? 'x' : '-')

      io << " (0o" << self.to_i.to_s(8) << ')'
    end
  end

  # A `File::Info` contains metadata regarding a file.
  # It is returned by `File.info`, `File#info` and `File.info?`.
  abstract struct Info
    # Size of the file, in bytes.
    abstract def size : UInt64

    # The permissions of the file.
    abstract def permissions : Permissions

    # The type of the file.
    abstract def type : Type

    # The special flags this file has set.
    abstract def flags : Flags

    # The last time this file was modified.
    abstract def modification_time : Time

    # The user ID of the file's owner.
    abstract def owner : UInt32

    # The group ID that the file belongs to.
    abstract def group : UInt32

    # Returns true if this `Info` and *other* are of the same file.
    #
    # On unix, this compares device and inode fields, and will compare equal for
    # hard linked files.
    abstract def same_file?(other : File::Info) : Bool

    # Returns true if this `Info` represents a standard file. Shortcut for
    # `type.file?`.
    def file?
      type.file?
    end

    # Returns true if this `Info` represents a directory. Shortcut for
    # `type.directory?`.
    def directory?
      type.directory?
    end

    # Returns true if this `Info` represents a symbolic link to another file.
    # Shortcut for `type.symlink?`.
    def symlink?
      type.symlink?
    end
  end
end

require "crystal/system/file_info"
