class Time::Location
  @@location_cache = {} of String => NamedTuple(time: Time, location: Location)

  # `InvalidTZDataError` is raised if a zoneinfo file contains invalid
  # time zone data.
  #
  # Details on the exact cause can be found in the error message.
  class InvalidTZDataError < Exception
    def self.initialize(message : String? = "Malformed time zone information", cause : Exception? = nil)
      super(message, cause)
    end
  end

  # :nodoc:
  def self.load?(name : String, sources : Enumerable(String)) : Time::Location?
    if source = find_zoneinfo_file(name, sources)
      load_from_dir_or_zip(name, source)
    end
  end

  # :nodoc:
  def self.load(name : String, sources : Enumerable(String)) : Time::Location?
    if source = find_zoneinfo_file(name, sources)
      load_from_dir_or_zip(name, source) || raise InvalidLocationNameError.new(name, source)
    end
  end

  # :nodoc:
  def self.load_android(name : String, sources : Enumerable(String)) : Time::Location?
    if path = find_android_tzdata_file(sources)
      load_from_android_tzdata(name, path) || raise InvalidLocationNameError.new(name, path)
    end
  end

  # :nodoc:
  def self.load_from_dir_or_zip(name : String, source : String) : Time::Location?
    if source.ends_with?(".zip")
      open_file_cached(name, source) do |file|
        read_zip_file(name, file) do |io|
          read_zoneinfo(name, io)
        end
      end
    else
      path = File.join(source, name)
      open_file_cached(name, path) do |file|
        read_zoneinfo(name, file)
      end
    end
  end

  # :nodoc:
  def self.load_from_android_tzdata(name : String, path : String) : Time::Location?
    return nil unless File.exists?(path)

    mtime = File.info(path).modification_time
    if (cache = @@location_cache[name]?) && cache[:time] == mtime
      cache[:location]
    else
      File.open(path) do |file|
        read_android_tzdata(file, false) do |location_name, location|
          @@location_cache[location_name] = {time: mtime, location: location}
        end
        @@location_cache[name].try &.[:location]
      end
    end
  end

  private def self.open_file_cached(name : String, path : String, &)
    return nil unless File.exists?(path)

    mtime = File.info(path).modification_time
    if (cache = @@location_cache[name]?) && cache[:time] == mtime
      cache[:location]
    else
      File.open(path) do |file|
        location = yield file
        if location
          @@location_cache[name] = {time: mtime, location: location}

          return location
        end
      end
    end
  end

  # :nodoc:
  def self.find_zoneinfo_file(name : String, sources : Enumerable(String)) : String?
    sources.each do |source|
      if source.ends_with?(".zip")
        path = source
      else
        path = File.join(source, name)
      end

      return source if File.exists?(path) && File.file?(path) && File.readable?(path)
    end
  end

  # :nodoc:
  def self.find_android_tzdata_file(sources : Enumerable(String)) : String?
    sources.find do |path|
      File.exists?(path) && File.file?(path) && File.readable?(path)
    end
  end

  # :nodoc:
  # Parse "zoneinfo" time zone file.
  # This is the standard file format used by most operating systems.
  # See https://data.iana.org/time-zones/tz-link.html, https://github.com/eggert/tz, tzfile(5)
  def self.read_zoneinfo(location_name : String, io : IO) : Time::Location
    raise InvalidTZDataError.new unless io.read_string(4) == "TZif"

    # 1-byte version, then 15 bytes of padding
    version = io.read_byte
    raise InvalidTZDataError.new unless version.in?(0_u8, '2'.ord, '3'.ord)
    io.skip(15)

    # six big-endian 32-bit integers:
    #	number of UTC/local indicators
    #	number of standard/wall indicators
    #	number of leap seconds
    #	number of transition times
    #	number of local time zones
    #	number of characters of time zone abbrev strings

    num_utc_local = read_int32(io)
    num_std_wall = read_int32(io)
    num_leap_seconds = read_int32(io)
    num_transitions = read_int32(io)
    num_local_time_zones = read_int32(io)
    abbrev_length = read_int32(io)

    transitionsdata = read_buffer(io, num_transitions * 4)

    # Time zone indices for transition times.
    transition_indexes = Bytes.new(num_transitions)
    io.read_fully(transition_indexes)

    zonedata = read_buffer(io, num_local_time_zones * 6)

    abbreviations = read_buffer(io, abbrev_length)

    leap_second_time_pairs = Bytes.new(num_leap_seconds * 8)
    io.read_fully(leap_second_time_pairs)

    isstddata = Bytes.new(num_std_wall)
    io.read_fully(isstddata)

    isutcdata = Bytes.new(num_utc_local)
    io.read_fully(isutcdata)

    # If version == 2 or 3, the entire file repeats, this time using
    # 8-byte ints for txtimes and leap seconds.
    # We won't need those until 2106.

    zones = Array(Zone).new(num_local_time_zones) do
      offset = read_int32(zonedata)
      is_dst = zonedata.read_byte != 0_u8
      name_idx = zonedata.read_byte
      raise InvalidTZDataError.new unless name_idx && name_idx < abbreviations.size
      abbreviations.pos = name_idx
      name = abbreviations.gets(Char::ZERO, chomp: true)
      raise InvalidTZDataError.new unless name
      Zone.new(name, offset, is_dst)
    end

    transitions = Array(ZoneTransition).new(num_transitions) do |transition_id|
      time = read_int32(transitionsdata).to_i64
      zone_idx = transition_indexes[transition_id]
      raise InvalidTZDataError.new unless zone_idx < zones.size

      isstd = !isstddata[transition_id]?.in?(nil, 0_u8)
      isutc = !isstddata[transition_id]?.in?(nil, 0_u8)

      ZoneTransition.new(time, zone_idx, isstd, isutc)
    end

    new(location_name, zones, transitions)
  rescue exc : IO::Error
    raise InvalidTZDataError.new(cause: exc)
  end

  private ANDROID_TZDATA_NAME_LENGTH = 40
  private ANDROID_TZDATA_ENTRY_SIZE  = ANDROID_TZDATA_NAME_LENGTH + 12

  # :nodoc:
  # Reads a packed tzdata file for Android's Bionic C runtime. Defined in
  # https://android.googlesource.com/platform/bionic/+/master/libc/tzcode/bionic.cpp
  def self.read_android_tzdata(io : IO, local : Bool, & : String, Time::Location ->)
    header = io.read_string(12)
    raise InvalidTZDataError.new unless header.starts_with?("tzdata") && header.ends_with?('\0')

    index_offset = read_int32(io)
    data_offset = read_int32(io)
    io.skip(4) # final_offset
    unless index_offset <= data_offset && (data_offset - index_offset).divisible_by?(ANDROID_TZDATA_ENTRY_SIZE)
      raise InvalidTZDataError.new
    end

    io.seek(index_offset)
    entries = Array.new((data_offset - index_offset) // ANDROID_TZDATA_ENTRY_SIZE) do
      name = io.read_string(40).rstrip('\0')
      start = read_int32(io)
      length = read_int32(io)
      io.skip(4) # unused
      {name, start, length}
    end

    entries.each do |(name, start, length)|
      io.seek(start + data_offset)
      yield name, read_zoneinfo(local ? "Local" : name, read_buffer(io, length))
    end
  end

  private def self.read_int32(io : IO)
    io.read_bytes(Int32, IO::ByteFormat::BigEndian)
  end

  private def self.read_buffer(io : IO, size : Int)
    buffer = Bytes.new(size)
    io.read_fully(buffer)
    IO::Memory.new(buffer)
  end

  # :nodoc:
  CENTRAL_DIRECTORY_HEADER_SIGNATURE = 0x02014b50
  # :nodoc:
  END_OF_CENTRAL_DIRECTORY_HEADER_SIGNATURE = 0x06054b50
  # :nodoc:
  ZIP_TAIL_SIZE = 22
  # :nodoc:
  LOCAL_FILE_HEADER_SIGNATURE = 0x04034b50
  # :nodoc:
  COMPRESSION_METHOD_UNCOMPRESSED = 0_i16

  # This method loads an entry from an uncompressed zip file.
  # See http://www.onicos.com/staff/iz/formats/zip.html for ZIP format layout
  private def self.read_zip_file(name : String, file : File, &)
    file.seek -ZIP_TAIL_SIZE, IO::Seek::End

    if file.read_bytes(Int32, IO::ByteFormat::LittleEndian) != END_OF_CENTRAL_DIRECTORY_HEADER_SIGNATURE
      raise InvalidTZDataError.new("Corrupt ZIP file #{file.path}")
    end

    file.skip 6
    num_entries = file.read_bytes(Int16, IO::ByteFormat::LittleEndian)
    file.skip 4

    file.pos = file.read_bytes(Int32, IO::ByteFormat::LittleEndian)

    num_entries.times do
      break if file.read_bytes(Int32, IO::ByteFormat::LittleEndian) != CENTRAL_DIRECTORY_HEADER_SIGNATURE

      file.skip 6
      compression_method = file.read_bytes(Int16, IO::ByteFormat::LittleEndian)
      file.skip 12
      uncompressed_size = file.read_bytes(Int32, IO::ByteFormat::LittleEndian)
      filename_length = file.read_bytes(Int16, IO::ByteFormat::LittleEndian)
      extra_field_length = file.read_bytes(Int16, IO::ByteFormat::LittleEndian)
      file_comment_length = file.read_bytes(Int16, IO::ByteFormat::LittleEndian)
      file.skip 8
      local_file_header_pos = file.read_bytes(Int32, IO::ByteFormat::LittleEndian)
      filename = file.read_string(filename_length)

      unless filename == name
        file.skip extra_field_length + file_comment_length
        next
      end

      unless compression_method == COMPRESSION_METHOD_UNCOMPRESSED
        raise InvalidTZDataError.new("Unsupported compression in ZIP file: #{file.path}")
      end

      file.pos = local_file_header_pos

      unless file.read_bytes(Int32, IO::ByteFormat::LittleEndian) == LOCAL_FILE_HEADER_SIGNATURE
        raise InvalidTZDataError.new("Invalid ZIP file: #{file.path}")
      end
      file.skip 4
      unless file.read_bytes(Int16, IO::ByteFormat::LittleEndian) == COMPRESSION_METHOD_UNCOMPRESSED
        raise InvalidTZDataError.new("Invalid ZIP file: #{file.path}")
      end
      file.skip 16
      unless file.read_bytes(Int16, IO::ByteFormat::LittleEndian) == filename_length
        raise InvalidTZDataError.new("Invalid ZIP file: #{file.path}")
      end
      extra_field_length = file.read_bytes(Int16, IO::ByteFormat::LittleEndian)
      unless file.gets(filename_length) == name
        raise InvalidTZDataError.new("Invalid ZIP file: #{file.path}")
      end

      file.skip extra_field_length

      return yield file
    end
  end
end
