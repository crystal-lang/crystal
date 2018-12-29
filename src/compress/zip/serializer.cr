class Compress::Zip::Serializer
  # All of these are aliased to Int even though they do not have the same
  # capacity internally - this is done to prevent callers from having to downcast
  # to a specific Int subtype manually. Write methods protect from overflows at runtime.
  alias ZipLocation = Int
  alias ZipFilesize = Int
  alias ZipCRC32 = Int
  alias ZipGpFlags = Int
  alias ZipStorageMode = Int

  VERSION_NEEDED_TO_EXTRACT       = 20
  VERSION_NEEDED_TO_EXTRACT_ZIP64 = 45

  # A combination of two bytes - version_made_by as low byte and the OS type as high byte
  # version_made_by = 52
  # os_type = 3 # UNIX
  # [version_made_by, os_type].pack('CC')
  MADE_BY_SIGNATURE = Bytes[52, 3]

  def file_external_attrs
    # These need to be set so that the unarchived files do not become executable on UNIX, for
    # security purposes. Strictly speaking we would want to make this user-customizable,
    # but for now just putting in sane defaults will do. For example, Trac with zipinfo does this:
    # zipinfo.external_attr = 0644 << 16L # permissions -r-wr--r--.
    # We snatch the incantations from Rubyzip for this.
    unix_perms = 0o644
    file_type_file = 0o10
    ((file_type_file << 12 | (unix_perms & 0o7777)) << 16).to_u32!
  end

  def dir_external_attrs
    # Applies permissions to an empty directory.
    unix_perms = 0o755
    file_type_dir = 0o04
    ((file_type_dir << 12 | (unix_perms & 0o7777)) << 16).to_u32!
  end

  def write_local_file_header(io : IO,
                              filename : String,
                              compressed_size : ZipFilesize,
                              uncompressed_size : ZipFilesize,
                              crc32 : ZipCRC32,
                              gp_flags : ZipGpFlags,
                              mtime : Time,
                              storage_mode : ZipStorageMode,
                              additional_extra_fields : Bytes = Bytes.empty)
    requires_zip64 = (compressed_size > UInt32::MAX || uncompressed_size > UInt32::MAX)

    write_uint32_le(io, 0x04034b50)
    if requires_zip64
      write_uint16_le(io, VERSION_NEEDED_TO_EXTRACT_ZIP64)
    else
      write_uint16_le(io, VERSION_NEEDED_TO_EXTRACT)
    end

    write_uint16_le(io, gp_flags)                  # general purpose bit flag        2 bytes
    write_uint16_le(io, storage_mode.to_u16)       # compression method              2 bytes
    write_uint16_le(io, to_binary_dos_time(mtime)) # last mod file time              2 bytes
    write_uint16_le(io, to_binary_dos_date(mtime)) # last mod file date              2 bytes
    write_uint32_le(io, crc32)                     # CRC32                           4 bytes

    # compressed size              4 bytes
    # uncompressed size            4 bytes
    if requires_zip64
      write_uint32_le(io, UInt32::MAX)
      write_uint32_le(io, UInt32::MAX)
    else
      write_uint32_le(io, compressed_size)
      write_uint32_le(io, uncompressed_size)
    end

    # Filename should not be longer than 0xFFFF otherwise this wont fit here
    write_uint16_le(io, filename.bytesize)

    extra_fields_io = IO::Memory.new

    # Interesting tidbit:
    # https://social.technet.microsoft.com/Forums/windows/en-US/6a60399f-2879-4859-b7ab-6ddd08a70948
    # TL;DR of it is: Windows 7 Explorer _will_ open Zip64 entries. However, it desires to have the
    # Zip64 extra field as _the first_ extra field.
    if requires_zip64
      write_zip64_extra_for_local_file_header(extra_fields_io, compressed_size, uncompressed_size)
    end
    write_timestamp_extra_field(extra_fields_io, mtime)
    extra_fields_io.write(additional_extra_fields) # If the caller gave us any
    extra_fields_io.rewind

    write_uint16_le(io, extra_fields_io.size) # extra field length              2 bytes
    io.write(filename.encode("utf-8"))        # file name (variable size)
    IO.copy(extra_fields_io, io)              # extra fields content (variable size)
  end

  def write_central_directory_file_header(io : IO, filename : String, compressed_size : ZipFilesize, uncompressed_size : ZipFilesize, crc32 : ZipCRC32, gp_flags : ZipGpFlags, mtime : Time, storage_mode : ZipStorageMode, local_file_header_location : ZipLocation, additional_extra_fields : Bytes = Bytes.empty)
    # At this point if the header begins somewhere beyound 0xFFFFFFFF we _have_ to record the offset
    # of the local file header as a zip64 extra field, so we give up, give in, you loose, love will always win...
    add_zip64 = (local_file_header_location > UInt32::MAX) || (compressed_size > UInt32::MAX) || (uncompressed_size > UInt32::MAX)

    # Compose extra fields
    extra_fields_io = IO::Memory.new
    if add_zip64
      write_zip64_extra_for_central_directory_file_header(extra_fields_io, uncompressed_size, compressed_size, local_file_header_location)
    end
    write_timestamp_extra_field(extra_fields_io, mtime)
    extra_fields_io.write(additional_extra_fields) # If the caller gave us any
    extra_fields_io.rewind

    write_uint32_le(io, 0x02014b50)                                                              # central directory entry file header signature   4 bytes  (0x02014b50)
    io.write(MADE_BY_SIGNATURE)                                                                  # version made by                 2 bytes
    write_uint16_le(io, add_zip64 ? VERSION_NEEDED_TO_EXTRACT_ZIP64 : VERSION_NEEDED_TO_EXTRACT) # version needed to extract       2 bytes

    write_uint16_le(io, gp_flags)                  # general purpose bit flag        2 bytes
    write_uint16_le(io, storage_mode.to_u16)       # compression method              2 bytes
    write_uint16_le(io, to_binary_dos_time(mtime)) # last mod file time              2 bytes
    write_uint16_le(io, to_binary_dos_date(mtime)) # last mod file date              2 bytes
    write_uint32_le(io, crc32)                     # crc-32                          4 bytes

    write_uint32_le(io, add_zip64 ? UInt32::MAX : compressed_size)
    write_uint32_le(io, add_zip64 ? UInt32::MAX : uncompressed_size)

    # Filename should not be longer than 0xFFFF otherwise this wont fit here
    write_uint16_le(io, filename.bytesize)    # file name length                2 bytes
    write_uint16_le(io, extra_fields_io.size) # extra field length              2 bytes
    write_uint16_le(io, 0)                    # file comment length             2 bytes

    # For The Unarchiver < 3.11.1 this field has to be set to the overflow value if zip64 is used
    # because otherwise it does not properly advance the pointer when reading the Zip64 extra field
    # https://bitbucket.org/WAHa_06x36/theunarchiver/pull-requests/2/bug-fix-for-zip64-extra-field-parser/diff
    write_uint16_le(io, add_zip64 ? UInt16::MAX : 0) # disk number start               2 bytes
    write_uint16_le(io, 0)                           # internal file attributes        2 bytes

    # Because the add_empty_directory method will create a directory with a trailing "/",
    # this check can be used to assign proper permissions to the created directory.
    # external file attributes        4 bytes
    exattrs = filename.ends_with?('/') ? dir_external_attrs : file_external_attrs
    write_uint32_le(io, exattrs)

    entry_header_offset = add_zip64 ? UInt32::MAX : local_file_header_location
    write_uint32_le(io, entry_header_offset) # relative offset of local header 4 bytes

    io.write(filename.encode("utf-8")) # file name (variable size)

    IO.copy(extra_fields_io, io) # extra field (variable size)
    # (empty)                                          # file comment (variable size)
  end

  def write_end_of_central_directory(io : IO, start_of_central_directory_location : ZipLocation, central_directory_size : ZipLocation, num_files_in_archive : ZipLocation, comment : String = "")
    zip64_eocdr_offset = start_of_central_directory_location.to_u64 + central_directory_size.to_u64
    zip64_required = central_directory_size > UInt32::MAX ||
                     start_of_central_directory_location > UInt32::MAX ||
                     zip64_eocdr_offset > UInt32::MAX ||
                     num_files_in_archive > UInt16::MAX

    # Then, if zip64 is used
    if zip64_required
      # [zip64 end of central directory record]
      # zip64 end of central dir
      write_uint32_le(io, 0x06064b50)                      # signature                       4 bytes  (0x06064b50)
      write_uint64_le(io, 44)                              # size of zip64 EOCD record - 44, excludes the 12 bytes of the signature and size itself        8 bytes
      io.write(MADE_BY_SIGNATURE)                          # version made by                 2 bytes
      write_uint16_le(io, VERSION_NEEDED_TO_EXTRACT_ZIP64) # version needed to extract       2 bytes
      write_uint32_le(io, 0)                               # number of this disk             4 bytes
      write_uint32_le(io, 0)                               # number of the disk with the start of the central directory  4 bytes
      write_uint64_le(io, num_files_in_archive)            # total number of entries in the central directory on this disk  8 bytes
      write_uint64_le(io, num_files_in_archive)            # total number of entries in the archive total 8 bytes
      write_uint64_le(io, central_directory_size)          # size of the central directory   8 bytes

      # offset of start of central directory with respect to the starting disk number        8 bytes
      write_uint64_le(io, start_of_central_directory_location)
      # zip64 extensible data sector    (variable size), blank for us

      # [zip64 end of central directory locator]
      write_uint32_le(io, 0x07064b50)         # zip64 end of central dir locator signature 4 bytes  (0x07064b50)
      write_uint32_le(io, 0)                  # number of the disk with the start of the zip64 end of central directory 4 bytes
      write_uint64_le(io, zip64_eocdr_offset) # relative offset of the zip64
      # end of central directory record 8 bytes
      # (note: "relative" is actually "from the start of the file")
      write_uint32_le(io, 1) # total number of disks           4 bytes
    end

    # Then the end of central directory record:
    write_uint32_le(io, 0x06054b50) # end of central dir signature     4 bytes  (0x06054b50)
    write_uint16_le(io, 0)          # number of this disk              2 bytes
    write_uint16_le(io, 0)          # number of the disk with the
    # start of the central directory 2 bytes

    num_entries = zip64_required ? UInt16::MAX : num_files_in_archive
    write_uint16_le(io, num_entries) # total number of entries in the central directory on this disk   2 bytes
    write_uint16_le(io, num_entries) # total number of entries in the central directory            2 bytes

    write_uint32_le(io, zip64_required ? UInt32::MAX : central_directory_size)              # size of the central directory    4 bytes
    write_uint32_le(io, zip64_required ? UInt32::MAX : start_of_central_directory_location) # offset of start of central directory with respect to the starting disk number        4 bytes

    # Sneak in the default comment
    write_uint16_le(io, comment.bytesize) # .ZIP file comment length        2 bytes
    io.write(comment.encode("utf-8"))     # .ZIP file comment       (variable size)
  end

  def write_data_descriptor(io : IO, compressed_size : ZipFilesize, uncompressed_size : ZipFilesize, crc32 : ZipCRC32)
    write_uint32_le(io, 0x08074b50) # Although not originally assigned a signature, the value
    # 0x08074b50 has commonly been adopted as a signature value
    # for the data descriptor record.
    write_uint32_le(io, crc32) # crc-32                          4 bytes

    # If one of the sizes is above 0xFFFFFFF use ZIP64 lengths (8 bytes) instead. A good unarchiver
    # will decide to unpack it as such if it finds the Zip64 extra for the file in the central directory.
    # So also use the opportune moment to switch the entry to Zip64 if needed
    requires_zip64 = (compressed_size > UInt32::MAX || uncompressed_size > UInt32::MAX)

    # compressed size                 4 bytes, or 8 bytes for ZIP64
    # uncompressed size               4 bytes, or 8 bytes for ZIP64
    if requires_zip64
      write_uint64_le(io, compressed_size)
      write_uint64_le(io, uncompressed_size)
    else
      write_uint32_le(io, compressed_size)
      write_uint32_le(io, uncompressed_size)
    end
  end

  # Writes the extended timestamp information field. The spec defines 2
  # different formats - the one for the local file header can also accomodate the
  # atime and ctime, whereas the one for the central directory can only take
  # the mtime - and refers the reader to the local header extra to obtain the
  # remaining times
  private def write_timestamp_extra_field(io : IO, mtime : Time)
    #         Local-header version:
    #
    #         Value         Size        Description
    #         -----         ----        -----------
    # (time)  0x5455        Short       tag for this extra block type ("UT")
    #         TSize         Short       total data size for this block
    #         Flags         Byte        info bits
    #         (ModTime)     Long        time of last modification (UTC/GMT)
    #         (AcTime)      Long        time of last access (UTC/GMT)
    #         (CrTime)      Long        time of original creation (UTC/GMT)
    #
    #         Central-header version:
    #
    #         Value         Size        Description
    #         -----         ----        -----------
    # (time)  0x5455        Short       tag for this extra block type ("UT")
    #         TSize         Short       total data size for this block
    #         Flags         Byte        info bits (refers to local header!)
    #         (ModTime)     Long        time of last modification (UTC/GMT)
    #
    # The lower three bits of Flags in both headers indicate which time-
    #       stamps are present in the LOCAL extra field:
    #
    #       bit 0           if set, modification time is present
    #       bit 1           if set, access time is present
    #       bit 2           if set, creation time is present
    #       bits 3-7        reserved for additional timestamps; not set
    flags = 0b10000000                # Set bit 1 only to indicate only mtime is present
    write_uint16_le(io, 0x5455)       # tag for this extra block type ("UT")
    write_uint16_le(io, 1 + 4)        # # the size of this block (1 byte used for the Flag + 1 long used for the timestamp)
    write_uint8_le(io, flags)         # encode a single byte
    write_int32_le(io, mtime.to_unix) # Use a signed long, not the unsigned one used by the rest of the ZIP spec.
  end

  private def write_zip64_extra_for_local_file_header(io : IO, compressed_size : ZipFilesize, uncompressed_size : ZipFilesize)
    write_uint16_le(io, 0x0001)            # Tag for the extra field
    write_uint16_le(io, 16)                # Size of the extra field
    write_uint64_le(io, uncompressed_size) # Original uncompressed size
    write_uint64_le(io, compressed_size)   # Size of compressed data
  end

  private def write_zip64_extra_for_central_directory_file_header(io : IO, uncompressed_size : Int, compressed_size : Int, local_file_header_location : ZipLocation)
    write_uint16_le(io, 0x0001)                     # 2 bytes    Tag for this "extra" block type
    write_uint16_le(io, 28)                         # 2 bytes    Size of this "extra" block. For us it will always be 28
    write_uint64_le(io, uncompressed_size)          # 8 bytes   Size of uncompressed data
    write_uint64_le(io, compressed_size)            # 8 bytes   Size of compressed data
    write_uint64_le(io, local_file_header_location) # 8 bytes   Local file header location in file
    write_uint32_le(io, 0)                          # 4 bytes   Number of the disk on which this file starts
  end

  private def to_binary_dos_time(t : Time)
    (t.second // 2) + (t.minute << 5) + (t.hour << 11)
  end

  private def to_binary_dos_date(t : Time)
    t.day + (t.month << 5) + ((t.year - 1980) << 9)
  end

  private def write_uint8_le(io : IO, val : Int)
    if val < UInt8::MIN || val > UInt8::MAX
      raise(ArgumentError.new("Unable to fit #{val} into uint8"))
    end
    io.write_bytes(val.to_u8, IO::ByteFormat::LittleEndian)
  end

  private def write_uint16_le(io : IO, val : Int)
    if val < UInt16::MIN || val > UInt16::MAX
      raise(ArgumentError.new("Unable to fit #{val} into uint16"))
    end
    io.write_bytes(val.to_u16, IO::ByteFormat::LittleEndian)
  end

  private def write_uint32_le(io : IO, val : Int)
    if val < UInt32::MIN || val > UInt32::MAX
      raise(ArgumentError.new("Unable to fit #{val} into uint32"))
    end
    io.write_bytes(val.to_u32, IO::ByteFormat::LittleEndian)
  end

  private def write_int32_le(io : IO, val : Int)
    if val < Int32::MIN || val > Int32::MAX
      raise(ArgumentError.new("Unable to fit #{val} into int32"))
    end
    io.write_bytes(val.to_i32, IO::ByteFormat::LittleEndian)
  end

  private def write_uint64_le(io : IO, val : Int)
    if val < UInt64::MIN || val > UInt64::MAX
      raise(ArgumentError.new("Unable to fit #{val} into uint64"))
    end
    io.write_bytes(val.to_u64, IO::ByteFormat::LittleEndian)
  end
end
