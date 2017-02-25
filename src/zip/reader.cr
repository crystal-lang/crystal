require "./file_info"

# Reads zip file entries sequentially from an `IO`.
#
# NOTE: Entries might not have correct values
# for crc32, compressed_size, uncompressed_size and comment,
# because when reading a zip file directly from a stream this
# information might be stored later in the zip stream.
# If you need this information, consider using `Zip::File`.
#
# ### Example
#
# ```
# File.open("./file.zip") do |file|
#   Zip::Reader.open(file) do |zip|
#     zip.each_entry do |entry|
#       p entry.filename
#       p entry.file?
#       p entry.dir?
#       p entry.io.gets_to_end
#     end
#   end
# end
# ```
class Zip::Reader
  # Whether to close the enclosed `IO` when closing this reader.
  property? sync_close = false

  # Returns `true` if this reader is closed.
  getter? closed = false

  # Creates a new reader from the given *io*.
  def initialize(@io : IO, @sync_close = false)
    @reached_end = false
    @read_data_descriptor = true
  end

  # Creates a new reader from the given *filename*.
  def self.new(filename : String)
    new(::File.new(filename), sync_close: true)
  end

  # Creates a new reader from the given *io*, yields it to the given block,
  # and closes it at the end.
  def self.open(io : IO, sync_close = false)
    reader = new(io, sync_close: sync_close)
    yield reader ensure reader.close
  end

  # Creates a new reader from the given *filename*, yields it to the given block,
  # and closes it at the end.
  def self.open(filename : String)
    reader = new(filename)
    yield reader ensure reader.close
  end

  # Reads the next entry in the zip, or `nil` if there
  # are no more entries.
  #
  # After reading a next entry, previous entries can no
  # longer be read (their `IO` will be closed.)
  def next_entry : Entry?
    return nil if @reached_end

    if last_entry = @last_entry
      last_entry.close
      skip_data_descriptor(last_entry)
    end

    while true
      signature = read UInt32

      case signature
      when FileInfo::SIGNATURE
        # Found file info signature
        break
      when FileInfo::DATA_DESCRIPTOR_SIGNATURE
        if last_entry && !@read_data_descriptor
          # Consider the case where a data descriptor comes after
          # a STORED entry: skip data descriptor and expect file signature next
          read_data_descriptor(last_entry)
          next
        else
          raise Error.new("Unexpected data descriptor when reading zip")
        end
      else
        # Other signature: we are done with entries (next comes metadata)
        @reached_end = true
        return nil
      end
    end

    @last_entry = Entry.new(@io)
  end

  # Yields each entry in the zip to the given block.
  def each_entry
    while entry = next_entry
      yield entry
    end
  end

  # Closes this zip reader.
  def close
    return if @closed
    @closed = true
    @io.close if @sync_close
  end

  private def skip_data_descriptor(entry)
    if entry.compression_method.deflated? && entry.bit_3_set?
      # The data descriptor signature is optional: if we
      # find it, we read the data descriptor info normally;
      # otherwise, the first four bytes are the crc32 value.
      signature = read UInt32
      if signature == FileInfo::DATA_DESCRIPTOR_SIGNATURE
        read_data_descriptor(entry)
      else
        read_data_descriptor(entry, crc32: signature)
      end
      @read_data_descriptor = true
    else
      @read_data_descriptor = false
      verify_checksum(entry)
    end
  end

  private def read_data_descriptor(entry, crc32 = nil)
    entry.crc32 = crc32 || (read UInt32)
    entry.compressed_size = read UInt32
    entry.uncompressed_size = read UInt32
    verify_checksum(entry)
  end

  private def verify_checksum(entry)
    if entry.crc32 != entry.checksum_io.crc32
      raise Zip::Error.new("Checksum failed for entry #{entry.filename} (expected #{entry.crc32}, got #{entry.checksum_io.crc32}")
    end
  end

  private def read(type)
    @io.read_bytes(type, IO::ByteFormat::LittleEndian)
  end

  # A entry inside a `Zip::Reader`.
  #
  # Use the `io` method to read from it.
  class Entry
    include FileInfo

    # :nodoc:
    def initialize(io)
      super(at_file_header: io)
      @io = ChecksumReader.new(decompressor_for(io), @filename)
      @closed = false
    end

    # Returns an `IO` to the entry's data.
    def io : IO
      @io
    end

    protected def checksum_io
      @io
    end

    protected def close
      return if @closed
      @closed = true
      @io.skip_to_end
      @io.close
    end
  end
end
