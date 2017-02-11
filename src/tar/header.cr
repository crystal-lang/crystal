# A header of an entry inside a tar stream.
class Tar::Header
  # Type of a tar header
  enum Type : UInt8
    # Regular file
    REG = 48

    # Regular file
    AREG = 0

    # Hard link
    LINK = 49

    # Symbolic link
    SYM = 50

    # Character device node
    CHR = 51

    # Block device node
    BLK = 52

    # Directory
    DIR = 53

    # Fifo node
    FIFO = 54

    # Reserved
    CONT = 55

    # Extended header
    XHD = 120

    # Global extended header
    XGL = 103
  end

  private GNU_MAGIC = "ustar ".to_slice
  private GNU_VERSION = " \0".to_slice

  private USTAR_MAGIC = "ustar\0".to_slice
  private USTAR_VERSION = "00".to_slice

  property name : String
  getter size : Int64
  property mode : Int32
  property uid : Int32
  property gid : Int32
  property modification_time : Time
  property type : Type
  property linkname : String
  property uname : String
  property gname : String
  property devmajor : Int32
  property devminor : Int32
  property access_time : Time
  property change_time : Time

  # Creates a header with default values:
  # strings will be empty, numbers will be zero
  # and all times will be set to `Time.now`.
  def initialize
    now = Time.now

    @name = ""
    @size = 0_i64
    @mode = 0
    @uid = 0
    @gid = 0
    @modification_time = now
    @type = Type::REG
    @linkname = ""
    @uname = ""
    @gname = ""
    @devmajor = 0
    @devminor = 0
    @access_time = now
    @change_time = now
  end

  # Creates a `Tar::Header` with the given *name*, *type*
  # and *mode*, and all other attributes initialized to
  # zero and empty strings.
  def self.new(name : String, type : Type, mode : Int32)
    header = new
    header.name = name
    header.type = type
    header.mode = mode
    header
  end

  # Creates a `Tar::Header` initialized from the attributes
  # of the given *filename*. Note that the name will be the
  # basename of the filename, so it might need to be adjusted
  # afterwards.
  def self.new(filename : String)
    new filename, File.stat(filename)
  end

  # Creates a `Tar::Header` initialized from the attributes
  # of the given *file*. Note that the name will be the
  # basename of the filename, so it might need to be adjusted
  # afterwards.
  def self.new(file : File)
    new file.path, file.stat
  end

  # Creates a `Tar::Header` initialized from the attributes
  # of the given *filename* and *stat*. Note that the name will be the
  # basename of the filename, so it might need to be adjusted
  # afterwards.
  def initialize(filename : String, stat : File::Stat)
    @name = File.basename(filename)
    @size = 0_i64
    @mode = (stat.mode & 0o777).to_i
    @uid = stat.uid.to_i
    @gid = stat.gid.to_i
    @modification_time = stat.mtime
    @access_time = stat.atime
    @change_time = stat.ctime
    @linkname = ""
    case stat
    when .file?
      @mode |= LibC::S_IFREG
      @type = Type::REG
      @size = stat.size.to_i64
    when .directory?
      @mode |= LibC::S_IFDIR
      @type = Type::DIR
      @name += '/' unless @name.ends_with?('/')
    when .symlink?
      @mode |= LibC::S_IFLNK
      @type = Type::SYM
      @linkname = File.real_path(filename)
    when .blockdev?
      @mode |= LibC::S_IFBLK
      @type = Type::BLK
    when .chardev?
      @mode |= LibC::S_IFCHR
      @type = Type::CHR
    when .pipe?
      @mode |= LibC::S_IFIFO
      @type = Type::FIFO
    when .socket?
      @mode |= LibC::S_IFSOCK
      @type = Type::REG
    else
      raise ArgumentError.new("unknown file mode: #{stat.mode.to_s(8)}")
    end

    # TODO: uname
    @uname = ""

    # TODO: gname
    @gname = ""

    @devmajor = 0
    @devminor = 0
  end

  # :nodoc:
  def initialize(header : Bytes)
    magic = header[257, 6]
    version = header[263, 2]

    if magic == USTAR_MAGIC && version == USTAR_VERSION
      initialize(ustar: header)
    elsif magic == GNU_MAGIC && version == GNU_VERSION
      initialize(gnu: header)
    else
      raise Tar::Error.new("unknown tar format (unknown magic+version combination)")
    end
  end

  # :nodoc:
  def initialize(*, gnu header : Bytes)
    check_checksum(header)

    @name = read_string(header[0, 100])
    @mode = read_i32(header[100, 8])
    @uid = read_i32(header[108, 8])
    @gid = read_i32(header[116, 8])
    @size = read_i64(header[124, 12])
    @modification_time = read_time(header[136, 12])
    @type = Type.new(header[156])
    @linkname = read_string(header[157, 100])
    @uname = read_string(header[265, 32])
    @gname = read_string(header[297, 32])

    case @type
    when .chr?, .blk?
      @devmajor = read_i32(header[329, 8])
      @devminor = read_i32(header[337, 8])
    else
      @devmajor = 0
      @devminor = 0
    end

    @access_time = read_time(header[345, 12])
    @change_time = read_time(header[357, 12])
  end

  # :nodoc:
  def initialize(*, ustar header : Bytes)
    check_checksum(header)

    @name = read_string(header[0, 100])
    @mode = read_i32(header[100, 8])
    @uid = read_i32(header[108, 8])
    @gid = read_i32(header[116, 8])
    @size = read_i64(header[124, 12])
    @modification_time = read_time(header[136, 12])
    @access_time = @change_time = Time.epoch(0)
    @type = Type.new(header[156])
    @linkname = read_string(header[157, 100])
    @uname = read_string(header[265, 32])
    @gname = read_string(header[297, 32])

    case @type
    when .chr?, .blk?
      @devmajor = read_i32(header[329, 8])
      @devminor = read_i32(header[337, 8])
    else
      @devmajor = 0
      @devminor = 0
    end

    prefix = read_string(header[345, 155])
    unless prefix.empty?
      @name = "#{prefix}/#{@name}"
    end
  end

  def size=(size : Int)
    @size = size.to_i64
  end

  def dir?
    @type.dir?
  end

  protected def to_io(io)
    header_array = StaticArray(UInt8, 512).new(0_u8)
    header = header_array.to_slice

    prefix = ""
    name = @name
    if name.bytesize > 99
      prefix, name = split_name(name)
    end

    header[257, 6].copy_from(USTAR_MAGIC)
    header[263, 2].copy_from(USTAR_VERSION)

    write_string("name", name, header[0, 100])
    write_number("mode", @mode, header[100, 8])
    write_number("uid", @uid, header[108, 8])
    write_number("gid", @gid, header[116, 8])
    write_number("size", @size, header[124, 12])
    write_number("modification_time", @modification_time.epoch, header[136, 12])
    header[156] = @type.value
    write_string("linkname", @linkname, header[157, 100])
    write_string("uname", @uname, header[265, 32])
    write_string("gname", @gname, header[297, 32])
    write_number("devmajor", @devmajor, header[329, 8])
    write_number("devminor", @devminor, header[337, 8])
    write_string("prefix", prefix, header[345, 155])
    write_checksum(header)

    io.write(header)
  end

  private def read_string(slice)
    String.new(slice.to_unsafe)
  end

  # Numbers inside a tar are stored in octal.
  private def read_i64(slice)
    read_string_for_number(slice).to_i64(base: 8)
  end

  # Numbers inside a tar are stored in octal.
  private def read_i32(slice)
    read_string_for_number(slice).to_i32(base: 8)
  end

  # Numbers in a tar can have spaces or nulls: they must be skipped.
  private def read_string_for_number(slice)
    String.new(slice).strip { |c| c.ascii_whitespace? || c == '\0' }
  end

  private def read_time(slice)
    # Times can be all zeros, for example for atime and ctime.
    # In those cases we use epoch(0).
    if slice.all? &.==(0)
      Time.epoch(0)
    else
      Time.epoch(read_i64(slice)).to_local
    end
  end

  private def write_string(field, string, slice)
    # Check that we can write the string inside the available space
    if string.bytesize > slice.size - 1
      raise Error.new("#{field} bytesize for #{string.inspect} is too big (maximum is #{slice.size - 1})")
    end

    slice.copy_from(string.to_slice)
  end

  private def write_number(field, number, slice)
    string = number.to_s(base: 8)
    write_string(field, string, slice)
  end

  private def write_checksum(header)
    chk1, _ = checksums(header)
    write_number("checksum", chk1, header[148, 8])
  end

  private def split_name(name)
    slice = name.to_slice
    slice = slice[0, Math.min(114, slice.size)]
    index = slice.rindex('/'.ord)
    unless index
      raise "name bytesize is too big (>= 100) and it has no '/' to split for prefix"
    end

    {name[0, index], name[index + 1..-1]}
  end

  # Tar entries are always padded to blocks of 512 bytes,
  # so when reading/writing their content we must skip/write
  # this amount of bytes at the end.
  protected def padding
    rem = size.remainder(512)
    rem > 0 ? (512 - rem) : 0
  end

  # The spec isn't clear about how to compute checksum:
  # use signed or unsigned values? This is why most implementations
  # (and this one) computes it both ways and consider it OK if
  # any of these values match the checksum.
  private def checksums(header)
    unsigned = 0
    signed = 0
    header.each_with_index do |byte, index|
      byte = ' '.ord.to_u8 if 148 <= index < 156
      unsigned += byte
      signed += byte.to_i8
    end
    {unsigned, signed}
  end

  private def check_checksum(header)
    checksum = read_i32(header[148, 8])
    chk1, chk2 = checksums(header)
    if chk1 != checksum && chk2 != checksum
      raise Error.new("header checksum mismatch")
    end
  end
end
