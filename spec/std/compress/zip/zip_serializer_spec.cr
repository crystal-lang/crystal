require "../../spec_helper"
require "compress/zip"

class ByteReader < IO::Memory
  def read_1b
    slice = read_n(1)
    slice[0]
  end

  def read_uint16
    read_bytes(UInt16, format: IO::ByteFormat::LittleEndian)
  end

  def read_uint32
    read_bytes(UInt32, format: IO::ByteFormat::LittleEndian)
  end

  def read_uint64
    read_bytes(UInt64, format: IO::ByteFormat::LittleEndian)
  end

  def read_signed_int32
    read_bytes(Int32, format: IO::ByteFormat::LittleEndian)
  end

  def read_n(n)
    slice = Bytes.new(n)
    read_fully(slice)
    slice
  end

  def eof?
    pos >= (bytesize - 1)
  end
end

describe Compress::Zip::Serializer do
  describe "#write_local_file_header" do
    it "writes the local file header for an entry that does not require Zip64" do
      buf = ByteReader.new
      mtime = Time.utc(2016, 7, 17, 13, 48)

      Compress::Zip::Serializer.new.write_local_file_header(io: buf,
        filename: "foo.bin",
        compressed_size: 768,
        uncompressed_size: 901,
        crc32: 456,
        gp_flags: 12,
        mtime: mtime,
        storage_mode: 8)

      buf.rewind
      buf.read_uint32.should eq(0x04034b50) # Signature
      buf.read_uint16.should eq(20)         # Version needed to extract
      buf.read_uint16.should eq(12)         # gp flags
      buf.read_uint16.should eq(8)          # storage mode
      buf.read_uint16.should eq(28_160)     # DOS time
      buf.read_uint16.should eq(18_673)     # DOS date
      buf.read_uint32.should eq(456)        # CRC32
      buf.read_uint32.should eq(768)        # compressed size
      buf.read_uint32.should eq(901)        # uncompressed size
      buf.read_uint16.should eq(7)          # filename size
      buf.read_uint16.should eq(9)          # extra fields size

      buf.read_string(7).should eq("foo.bin") # extra fields size

      buf.read_uint16.should eq(0x5455) # Extended timestamp extra tag
      buf.read_uint16.should eq(5)      # Size of the timestamp extra
      buf.read_1b.should eq(128)        # The timestamp flag

      ext_mtime = buf.read_signed_int32
      ext_mtime.should eq(1_468_763_280) # The mtime encoded as a 4byte uint

      parsed_time = Time.unix(ext_mtime)
      parsed_time.year.should eq(2016)
    end

    it "writes the local file header for an entry that does require Zip64 based \
        on uncompressed size (with the Zip64 extra)" do
      buf = ByteReader.new
      mtime = Time.utc(2016, 7, 17, 13, 48)

      Compress::Zip::Serializer.new.write_local_file_header(io: buf,
        filename: "foo.bin",
        gp_flags: 12,
        crc32: 456,
        compressed_size: 768,
        uncompressed_size: (0xFFFFFFFF + 1),
        mtime: mtime,
        storage_mode: 8)

      buf.rewind
      buf.read_uint32.should eq(0x04034b50)   # Signature
      buf.read_uint16.should eq(45)           # Version needed to extract
      buf.read_uint16.should eq(12)           # gp flags
      buf.read_uint16.should eq(8)            # storage mode
      buf.read_uint16.should eq(28_160)       # DOS time
      buf.read_uint16.should eq(18_673)       # DOS date
      buf.read_uint32.should eq(456)          # CRC32
      buf.read_uint32.should eq(0xFFFFFFFF)   # compressed size
      buf.read_uint32.should eq(0xFFFFFFFF)   # uncompressed size
      buf.read_uint16.should eq(7)            # filename size
      buf.read_uint16.should eq(29)           # extra fields size (Zip64 + extended timestamp)
      buf.read_string(7).should eq("foo.bin") # extra fields size

      buf.read_uint16.should eq(1)              # Zip64 extra tag
      buf.read_uint16.should eq(16)             # Size of the Zip64 extra payload
      buf.read_uint64.should eq(0xFFFFFFFF + 1) # uncompressed size
      buf.read_uint64.should eq(768)            # compressed size
    end

    it "writes the local file header for an entry that does require Zip64 based \
        on compressed size (with the Zip64 extra)" do
      buf = ByteReader.new
      mtime = Time.utc(2016, 7, 17, 13, 48)

      Compress::Zip::Serializer.new.write_local_file_header(io: buf,
        gp_flags: 12,
        crc32: 456,
        compressed_size: 0xFFFFFFFF + 1,
        uncompressed_size: 768,
        mtime: mtime,
        filename: "foo.bin",
        storage_mode: 8)

      buf.rewind
      buf.read_uint32.should eq(0x04034b50)   # Signature
      buf.read_uint16.should eq(45)           # Version needed to extract
      buf.read_uint16.should eq(12)           # gp flags
      buf.read_uint16.should eq(8)            # storage mode
      buf.read_uint16.should eq(28_160)       # DOS time
      buf.read_uint16.should eq(18_673)       # DOS date
      buf.read_uint32.should eq(456)          # CRC32
      buf.read_uint32.should eq(0xFFFFFFFF)   # compressed size
      buf.read_uint32.should eq(0xFFFFFFFF)   # uncompressed size
      buf.read_uint16.should eq(7)            # filename size
      buf.read_uint16.should eq(29)           # extra fields size
      buf.read_string(7).should eq("foo.bin") # extra fields size

      buf.read_uint16.should eq(1)              # Zip64 extra tag
      buf.read_uint16.should eq(16)             # Size of the Zip64 extra payload
      buf.read_uint64.should eq(768)            # uncompressed size
      buf.read_uint64.should eq(0xFFFFFFFF + 1) # compressed size
    end
  end

  describe "#write_data_descriptor" do
    it "writes 4-byte sizes into the data descriptor for standard file sizes" do
      buf = ByteReader.new

      Compress::Zip::Serializer.new.write_data_descriptor(io: buf, crc32: 123, compressed_size: 89_821, uncompressed_size: 990_912)

      buf.rewind
      buf.read_uint32.should eq(0x08074b50) # Signature
      buf.read_uint32.should eq(123)        # CRC32
      buf.read_uint32.should eq(89_821)     # compressed size
      buf.read_uint32.should eq(990_912)    # uncompressed size
      buf.eof?.should be_true
    end

    it "writes 8-byte sizes into the data descriptor for Zip64 compressed file size" do
      buf = ByteReader.new

      Compress::Zip::Serializer.new.write_data_descriptor(io: buf,
        crc32: 123,
        compressed_size: (0xFFFFFFFF + 1),
        uncompressed_size: 990_912)

      buf.rewind
      buf.read_uint32.should eq(0x08074b50)     # Signature
      buf.read_uint32.should eq(123)            # CRC32
      buf.read_uint64.should eq(0xFFFFFFFF + 1) # compressed size
      buf.read_uint64.should eq(990_912)        # uncompressed size
      buf.eof?.should be_true
    end

    it "writes 8-byte sizes into the data descriptor for Zip64 uncompressed file size" do
      buf = ByteReader.new

      Compress::Zip::Serializer.new.write_data_descriptor(io: buf,
        crc32: 123,
        compressed_size: 123,
        uncompressed_size: 0xFFFFFFFF + 1)

      buf.rewind
      buf.read_uint32.should eq(0x08074b50)     # Signature
      buf.read_uint32.should eq(123)            # CRC32
      buf.read_uint64.should eq(123)            # compressed size
      buf.read_uint64.should eq(0xFFFFFFFF + 1) # uncompressed size
      buf.eof?.should be_true
    end
  end

  describe "#write_central_directory_file_header" do
    it "writes the file header for a small-ish entry" do
      buf = ByteReader.new

      Compress::Zip::Serializer.new.write_central_directory_file_header(io: buf,
        local_file_header_location: 898_921,
        gp_flags: 555,
        storage_mode: 23,
        compressed_size: 901,
        uncompressed_size: 909_102,
        mtime: Time.utc(2016, 2, 2, 14, 0),
        crc32: 89_765,
        filename: "a-file.txt")

      buf.rewind
      buf.read_uint32.should eq(0x02014b50)       # Central directory entry sig
      buf.read_uint16.should eq(820)              # version made by
      buf.read_uint16.should eq(20)               # version need to extract
      buf.read_uint16.should eq(555)              # general purpose bit flag (explicitly set to bogus value to ensure we pass it through)
      buf.read_uint16.should eq(23)               # compression method (explicitly set to bogus value)
      buf.read_uint16.should eq(28_672)           # last mod file time
      buf.read_uint16.should eq(18_498)           # last mod file date
      buf.read_uint32.should eq(89_765)           # crc32
      buf.read_uint32.should eq(901)              # compressed size
      buf.read_uint32.should eq(909_102)          # uncompressed size
      buf.read_uint16.should eq(10)               # filename length
      buf.read_uint16.should eq(9)                # extra field length
      buf.read_uint16.should eq(0)                # file comment
      buf.read_uint16.should eq(0)                # disk number, must be maximum value because of The Unarchiver bug
      buf.read_uint16.should eq(0)                # internal file attributes
      buf.read_uint32.should eq(2_175_008_768)    # external file attributes
      buf.read_uint32.should eq(898_921)          # relative offset of local header
      buf.read_string(10).should eq("a-file.txt") # the filename
    end

    it "writes the file header for an entry that contains an empty directory" do
      buf = ByteReader.new

      Compress::Zip::Serializer.new.write_central_directory_file_header(io: buf,
        local_file_header_location: 898_921,
        gp_flags: 555,
        storage_mode: 23,
        compressed_size: 0,
        uncompressed_size: 0,
        mtime: Time.utc(2016, 2, 2, 14, 0),
        crc32: 544,
        filename: "this-is-here-directory/")

      buf.rewind
      buf.read_uint32.should eq(0x02014b50)                    # Central directory entry sig
      buf.read_uint16.should eq(820)                           # version made by
      buf.read_uint16.should eq(20)                            # version need to extract
      buf.read_uint16.should eq(555)                           # general purpose bit flag (explicitly set to bogus value to ensure we pass it through)
      buf.read_uint16.should eq(23)                            # compression method (explicitly set to bogus value)
      buf.read_uint16.should eq(28_672)                        # last mod file time
      buf.read_uint16.should eq(18_498)                        # last mod file date
      buf.read_uint32.should eq(544)                           # crc32
      buf.read_uint32.should eq(0)                             # compressed size
      buf.read_uint32.should eq(0)                             # uncompressed size
      buf.read_uint16.should eq(23)                            # filename length
      buf.read_uint16.should eq(9)                             # extra field length
      buf.read_uint16.should eq(0)                             # file comment
      buf.read_uint16.should eq(0)                             # disk number (0, first disk)
      buf.read_uint16.should eq(0)                             # internal file attributes
      buf.read_uint32.should eq(1_106_051_072)                 # external file attributes
      buf.read_uint32.should eq(898_921)                       # relative offset of local header
      buf.read_string(23).should eq("this-is-here-directory/") # the filename
    end

    it "writes the file header for an entry that requires Zip64 extra because of the uncompressed size" do
      buf = ByteReader.new

      Compress::Zip::Serializer.new.write_central_directory_file_header(io: buf,
        local_file_header_location: 898_921,
        gp_flags: 555,
        storage_mode: 23,
        compressed_size: 901,
        uncompressed_size: 0xFFFFFFFFF + 3,
        mtime: Time.utc(2016, 2, 2, 14, 0),
        crc32: 89_765,
        filename: "a-file.txt")

      buf.rewind
      buf.read_uint32.should eq(0x02014b50) # Central directory entry sig
      buf.read_uint16.should eq(820)        # version made by
      buf.read_uint16.should eq(45)         # version need to extract
      buf.read_uint16.should eq(555)        # general purpose bit flag
      # (explicitly set to bogus value
      # to ensure we pass it through)
      buf.read_uint16.should eq(23) # compression method (explicitly
      # set to bogus value)
      buf.read_uint16.should eq(28_672)           # last mod file time
      buf.read_uint16.should eq(18_498)           # last mod file date
      buf.read_uint32.should eq(89_765)           # crc32
      buf.read_uint32.should eq(0xFFFFFFFF)       # compressed size
      buf.read_uint32.should eq(0xFFFFFFFF)       # uncompressed size
      buf.read_uint16.should eq(10)               # filename length
      buf.read_uint16.should eq(41)               # extra field length
      buf.read_uint16.should eq(0)                # file comment
      buf.read_uint16.should eq(0xFFFF)           # disk number, must be blanked to the maximum value
      buf.read_uint16.should eq(0)                # internal file attributes
      buf.read_uint32.should eq(2_175_008_768)    # external file attributes
      buf.read_uint32.should eq(0xFFFFFFFF)       # relative offset of local header
      buf.read_string(10).should eq("a-file.txt") # the filename

      buf.read_uint16.should eq(1)               # Zip64 extra tag
      buf.read_uint16.should eq(28)              # Size of the Zip64 extra payload
      buf.read_uint64.should eq(0xFFFFFFFFF + 3) # uncompressed size
      buf.read_uint64.should eq(901)             # compressed size
      buf.read_uint64.should eq(898_921)         # local file header location
    end

    it "writes the file header for an entry that requires Zip64 extra because of the compressed size" do
      buf = ByteReader.new

      Compress::Zip::Serializer.new.write_central_directory_file_header(io: buf,
        local_file_header_location: 898_921,
        gp_flags: 555,
        storage_mode: 23,
        compressed_size: 0xFFFFFFFFF + 3, # the worst compression scheme in the universe
        uncompressed_size: 901,
        mtime: Time.utc(2016, 2, 2, 14, 0),
        crc32: 89_765,
        filename: "a-file.txt")

      buf.rewind
      buf.read_uint32.should eq(0x02014b50)       # Central directory entry sig
      buf.read_uint16.should eq(820)              # version made by
      buf.read_uint16.should eq(45)               # version need to extract
      buf.read_uint16.should eq(555)              # general purpose bit flag (explicitly set to bogus value to ensure we pass it through)
      buf.read_uint16.should eq(23)               # compression method (explicitly set to bogus value)
      buf.read_uint16.should eq(28_672)           # last mod file time
      buf.read_uint16.should eq(18_498)           # last mod file date
      buf.read_uint32.should eq(89_765)           # crc32
      buf.read_uint32.should eq(0xFFFFFFFF)       # compressed size
      buf.read_uint32.should eq(0xFFFFFFFF)       # uncompressed size
      buf.read_uint16.should eq(10)               # filename length
      buf.read_uint16.should eq(41)               # extra field length
      buf.read_uint16.should eq(0)                # file comment
      buf.read_uint16.should eq(0xFFFF)           # disk number, must be blanked to the maximum value because of The Unarchiver bug
      buf.read_uint16.should eq(0)                # internal file attributes
      buf.read_uint32.should eq(2_175_008_768)    # external file attributes
      buf.read_uint32.should eq(0xFFFFFFFF)       # relative offset of local header
      buf.read_string(10).should eq("a-file.txt") # the filename

      #  buf.should_not be_eof
      buf.read_uint16.should eq(1)               # Zip64 extra tag
      buf.read_uint16.should eq(28)              # Size of the Zip64 extra payload
      buf.read_uint64.should eq(901)             # uncompressed size
      buf.read_uint64.should eq(0xFFFFFFFFF + 3) # compressed size
      buf.read_uint64.should eq(898_921)         # local file header location
    end

    it "writes the file header for an entry that requires Zip64 extra because of the local file header offset being beyound 4GB" do
      buf = ByteReader.new

      Compress::Zip::Serializer.new.write_central_directory_file_header(io: buf,
        local_file_header_location: 0xFFFFFFFFF + 1,
        gp_flags: 555,
        storage_mode: 23,
        compressed_size: 8_981,
        # the worst compression scheme in the universe
        uncompressed_size: 819_891,
        mtime: Time.utc(2016, 2, 2, 14, 0),
        crc32: 89_765,
        filename: "a-file.txt")

      buf.rewind
      buf.read_uint32.should eq(0x02014b50)       # Central directory entry sig
      buf.read_uint16.should eq(820)              # version made by
      buf.read_uint16.should eq(45)               # version need to extract
      buf.read_uint16.should eq(555)              # general purpose bit flag (explicitly set to bogus value to ensure we pass it through)
      buf.read_uint16.should eq(23)               # compression method (explicitly set to bogus value)
      buf.read_uint16.should eq(28_672)           # last mod file time
      buf.read_uint16.should eq(18_498)           # last mod file date
      buf.read_uint32.should eq(89_765)           # crc32
      buf.read_uint32.should eq(0xFFFFFFFF)       # compressed size
      buf.read_uint32.should eq(0xFFFFFFFF)       # uncompressed size
      buf.read_uint16.should eq(10)               # filename length
      buf.read_uint16.should eq(41)               # extra field length
      buf.read_uint16.should eq(0)                # file comment
      buf.read_uint16.should eq(0xFFFF)           # disk number, must be blanked to the maximum value because of The Unarchiver bug
      buf.read_uint16.should eq(0)                # internal file attributes
      buf.read_uint32.should eq(2_175_008_768)    # external file attributes
      buf.read_uint32.should eq(0xFFFFFFFF)       # relative offset of local header
      buf.read_string(10).should eq("a-file.txt") # the filename

      #  buf.should_not be_eof
      buf.read_uint16.should eq(1)               # Zip64 extra tag
      buf.read_uint16.should eq(28)              # Size of the Zip64 extra payload
      buf.read_uint64.should eq(819_891)         # uncompressed size
      buf.read_uint64.should eq(8_981)           # compressed size
      buf.read_uint64.should eq(0xFFFFFFFFF + 1) # local file header location
    end
  end

  describe "#write_end_of_central_directory" do
    it "writes out the EOCD with all markers for a small ZIP file with just a few entries" do
      buf = ByteReader.new

      num_files = rand(8..190)
      Compress::Zip::Serializer.new.write_end_of_central_directory(io: buf,
        start_of_central_directory_location: 9_091_211,
        central_directory_size: 9_091,
        num_files_in_archive: num_files, comment: "xyz")

      buf.rewind
      buf.read_uint32.should eq(0x06054b50) # EOCD signature
      buf.read_uint16.should eq(0)          # number of this disk
      buf.read_uint16.should eq(0)          # number of the disk with the EOCD record
      buf.read_uint16.should eq(num_files)  # number of files on this disk
      buf.read_uint16.should eq(num_files)  # number of files in central directory total (for all disks)
      buf.read_uint32.should eq(9_091)      # size of the central directory (cdir records for all files)
      buf.read_uint32.should eq(9_091_211)  # start of central directory offset from the beginning of file/disk

      comment_length = buf.read_uint16
      comment_length.should eq(3)

      buf.read_string(comment_length).should match(/xyz/)
    end

    it "writes out the custom comment" do
      buf = ByteReader.new
      comment = "Ohai mate"
      Compress::Zip::Serializer.new.write_end_of_central_directory(io: buf,
        start_of_central_directory_location: 9_091_211,
        central_directory_size: 9_091,
        num_files_in_archive: 4,
        comment: comment)
      #
      #      size_and_comment = buf[((comment.bytesize + 2) * -1)..-1]
      #      comment_size = size_and_comment.unpack("v")[0]
      #      comment_size.should eq(comment.bytesize)
    end

    it "writes out the Zip64 EOCD as well if the central directory is located \
        beyound 4GB in the archive" do
      buf = ByteReader.new

      num_files = rand(8..190)
      Compress::Zip::Serializer.new.write_end_of_central_directory(io: buf,
        start_of_central_directory_location: 0xFFFFFFFF + 3,
        central_directory_size: 9091,
        num_files_in_archive: num_files)

      buf.rewind

      buf.read_uint32.should eq(0x06064b50)     # Zip64 EOCD signature
      buf.read_uint64.should eq(44)             # Zip64 EOCD record size
      buf.read_uint16.should eq(820)            # Version made by
      buf.read_uint16.should eq(45)             # Version needed to extract
      buf.read_uint32.should eq(0)              # Number of this disk
      buf.read_uint32.should eq(0)              # Number of the disk with the Zip64 EOCD record
      buf.read_uint64.should eq(num_files)      # Number of entries in the central directory of this disk
      buf.read_uint64.should eq(num_files)      # Number of entries in the central directories of all disks
      buf.read_uint64.should eq(9_091)          # Central directory size
      buf.read_uint64.should eq(0xFFFFFFFF + 3) # Start of central directory location

      buf.read_uint32.should eq(0x07064b50)               # Zip64 EOCD locator signature
      buf.read_uint32.should eq(0)                        # Number of the disk with the EOCD locator signature
      buf.read_uint64.should eq((0xFFFFFFFF + 3) + 9_091) # Where the Zip64 EOCD record starts
      buf.read_uint32.should eq(1)                        # Total number of disks

      # Then the usual EOCD record
      buf.read_uint32.should eq(0x06054b50) # EOCD signature
      buf.read_uint16.should eq(0)          # number of this disk
      buf.read_uint16.should eq(0)          # number of the disk with the EOCD record
      buf.read_uint16.should eq(0xFFFF)     # number of files on this disk
      buf.read_uint16.should eq(0xFFFF)     # number of files in central directory total (for all disks)
      buf.read_uint32.should eq(0xFFFFFFFF) # size of the central directory (cdir records for all files)
      buf.read_uint32.should eq(0xFFFFFFFF) # start of central directory offset from the beginning of file/disk

      comment_length = buf.read_uint16
      comment_length.should eq(0)

      buf.read_string(comment_length).should eq("")
    end

    it "writes out the Zip64 EOCD if the archive has more than 0xFFFF files" do
      buf = ByteReader.new

      Compress::Zip::Serializer.new.write_end_of_central_directory(io: buf,
        start_of_central_directory_location: 123,
        central_directory_size: 9_091,
        num_files_in_archive: 0xFFFF + 1, comment: "")

      buf.rewind

      buf.read_uint32.should eq(0x06064b50) # Zip64 EOCD signature
      buf.read_uint64
      buf.read_uint16
      buf.read_uint16
      buf.read_uint32
      buf.read_uint32
      buf.read_uint64.should eq(0xFFFF + 1) # Number of entries in the central directory of this disk
      buf.read_uint64.should eq(0xFFFF + 1) # Number of entries in the central directories of all disks
    end

    it "writes out the Zip64 EOCD if the central directory size exceeds 0xFFFFFFFF" do
      buf = ByteReader.new

      Compress::Zip::Serializer.new.write_end_of_central_directory(io: buf,
        start_of_central_directory_location: 123,
        central_directory_size: 0xFFFFFFFF + 2,
        num_files_in_archive: 5, comment: "Foooo")

      buf.rewind
      buf.read_uint32.should eq(0x06064b50)     # Zip64 EOCD signature
      buf.read_uint64                           # size of zip64 EOCD record
      buf.read_uint16                           # version made by
      buf.read_uint16                           # version needed to extract
      buf.read_uint32                           # number of this disk
      buf.read_uint32                           # number of the disk where central directory entries start
      buf.read_uint64                           # Number of entries in the central directory of this disk
      buf.read_uint64                           # Number of entries in the central directories of all disks
      buf.read_uint64.should eq(0xFFFFFFFF + 2) # Size of the central directory
      buf.read_uint64.should eq(123)            # Where the central directory begins
    end
  end
end
