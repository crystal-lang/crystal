class Time::Location
  @@location_cache = {} of String => NamedTuple(time: Time, location: Location)

  class InvalidTZDataError < Exception
    def self.initialize(message : String? = "Malformed time zone information", cause : Exception? = nil)
      super(message, cause)
    end
  end

  # :nodoc:
  def self.load?(name : String, sources : Enumerable(String))
    if source = find_zoneinfo_file(name, sources)
      load_from_dir_or_zip(name, source)
    end
  end

  # :nodoc:
  def self.load(name : String, sources : Enumerable(String))
    if source = find_zoneinfo_file(name, sources)
      load_from_dir_or_zip(name, source) || raise InvalidLocationNameError.new(name, source)
    end
  end

  # :nodoc:
  def self.load_from_dir_or_zip(name : String, source : String)
    {% if flag?(:win32) %}
      raise NotImplementedError.new("Time::Location.load_from_dir_or_zip")
    {% else %}
      if source.ends_with?(".zip")
        open_file_cached(name, source) do |file|
          read_zip_file(name, file) do |io|
            read_zoneinfo(name, io)
          end
        end
      else
        path = File.expand_path(name, source)
        open_file_cached(name, path) do |file|
          read_zoneinfo(name, file)
        end
      end
    {% end %}
  end

  private def self.open_file_cached(name : String, path : String)
    return nil unless File.exists?(path)

    mtime = File.stat(path).mtime
    if (cache = @@location_cache[name]?) && cache[:time] == mtime
      return cache[:location]
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
  def self.find_zoneinfo_file(name : String, sources : Enumerable(String))
    {% if flag?(:win32) %}
      raise NotImplementedError.new("Time::Location.find_zoneinfo_file")
    {% else %}
      sources.each do |source|
        if source.ends_with?(".zip")
          return source if File.exists?(source)
        else
          path = File.expand_path(name, source)
          return source if File.exists?(path)
        end
      end
    {% end %}
  end

  # Parse "zoneinfo" time zone file.
  # This is the standard file format used by most operating systems.
  # See https://data.iana.org/time-zones/tz-link.html, https://github.com/eggert/tz, tzfile(5)

  # :nodoc:
  def self.read_zoneinfo(location_name : String, io : IO)
    raise InvalidTZDataError.new unless io.read_string(4) == "TZif"

    # 1-byte version, then 15 bytes of padding
    version = io.read_byte
    raise InvalidTZDataError.new unless {0_u8, '2'.ord, '3'.ord}.includes?(version)
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

    leap_second_time_pairs = Bytes.new(num_leap_seconds)
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

      isstd = !{nil, 0_u8}.includes? isstddata[transition_id]?
      isutc = !{nil, 0_u8}.includes? isstddata[transition_id]?

      ZoneTransition.new(time, zone_idx, isstd, isutc)
    end

    new(location_name, zones, transitions)
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
  private def self.read_zip_file(name : String, file : IO::FileDescriptor)
    file.seek -ZIP_TAIL_SIZE, IO::Seek::End

    if file.read_bytes(Int32, IO::ByteFormat::LittleEndian) != END_OF_CENTRAL_DIRECTORY_HEADER_SIGNATURE
      raise InvalidTZDataError.new("corrupt zip file")
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
        raise InvalidTZDataError.new("Unsupported compression for #{name}")
      end

      file.pos = local_file_header_pos

      unless file.read_bytes(Int32, IO::ByteFormat::LittleEndian) == LOCAL_FILE_HEADER_SIGNATURE
        raise InvalidTZDataError.new("Invalid Zip file")
      end
      file.skip 4
      unless file.read_bytes(Int16, IO::ByteFormat::LittleEndian) == COMPRESSION_METHOD_UNCOMPRESSED
        raise InvalidTZDataError.new("Invalid Zip file")
      end
      file.skip 16
      unless file.read_bytes(Int16, IO::ByteFormat::LittleEndian) == filename_length
        raise InvalidTZDataError.new("Invalid Zip file")
      end
      extra_field_length = file.read_bytes(Int16, IO::ByteFormat::LittleEndian)
      unless file.gets(filename_length) == name
        raise InvalidTZDataError.new("Invalid Zip file")
      end

      file.skip extra_field_length

      return yield file
    end
  end
end
