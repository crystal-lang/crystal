require "./file_info"

# Provides random read access to zip file entries stores inside
# a `File` or an `IO::Memory`.
#
# ### Example
#
# ```
# Zip::File.open("./file.zip") do |file|
#   # Iterate through all entries printing their filename and contents
#   file.entries.each do |entry|
#     p entry.filename
#     entry.open do |io|
#       p io.gets_to_end
#     end
#   end
#
#   # Random access to entries by filename is also provided
#   entry = file["some_file.txt"]
#   entry.open do |io|
#     p io.gets_to_end
#   end
# end
# ```
class Zip::File
  # Returns all entries inside this zip file.
  getter entries : Array(Entry)

  # Returns `true` if this zip file is closed.
  getter? closed = false

  # Returns the zip file comment.
  getter comment = ""

  # Opens a `Zip::File` for reading from the given *io*.
  def initialize(@io : IO, @sync_close = false)
    directory_end_offset = find_directory_end_offset
    entries_size, directory_offset = read_directory_end(directory_end_offset)
    @entries = Array(Entry).new(entries_size)
    @entries_by_filename = {} of String => Entry
    read_entries(directory_offset, entries_size)
  end

  # Opens a `Zip::File` for reading from the given *filename*.
  def self.new(filename : String)
    new(::File.new(filename), sync_close: true)
  end

  # Opens a `Zip::File` for reading from the given *io*, yields
  # it to the given block, and closes it at the end.
  def self.open(io : IO, sync_close = false)
    zip = new io, sync_close
    yield zip ensure zip.close
  end

  # Opens a `Zip::File` for reading from the given *filename*, yields
  # it to the given block, and closes it at the end.
  def self.open(filename : String)
    zip = new filename
    yield zip ensure zip.close
  end

  # Returns the entry that has the given filename, or
  # raises `KeyError` if no such entry exists.
  def [](filename : String) : Entry
    self[filename]? || raise(KeyError.new("Missing zip entry: #{filename}"))
  end

  # Returns the entry that has the given filename, or
  # `nil` if no such entry exists.
  def []?(filename : String) : Entry?
    @entries_by_filename[filename]?
  end

  # Closes this zip file.
  def close
    return if @closed
    @closed = true
    if @sync_close
      @io.close
    end
  end

  # Try to find the directory end offset (by searching its signature)
  # in the last 64, 1024 and 65K bytes (in that order)
  private def find_directory_end_offset
    find_directory_end_offset(64) ||
      find_directory_end_offset(1024) ||
      find_directory_end_offset(65 * 1024) ||
      raise Zip::Error.new("Couldn't find directory end signature in the last 65KB")
  end

  private def find_directory_end_offset(buf_size)
    @io.seek(0, IO::Seek::End)
    size = @io.pos

    buf_size = Math.min(buf_size, size)
    @io.pos = size - buf_size

    buf = Bytes.new(buf_size)
    @io.read_fully(buf)

    i = buf_size - 1 - 4
    while i >= 0
      # These are the bytes the make up the directory end signature,
      # according to the spec
      break if buf[i] == 0x50 && buf[i + 1] == 0x4b && buf[i + 2] == 0x05 && buf[i + 3] == 0x06
      i -= 1
    end

    i == -1 ? nil : size - buf_size + i
  end

  private def read_directory_end(directory_end_offset)
    @io.pos = directory_end_offset

    signature = read UInt32
    if signature != Zip::END_OF_CENTRAL_DIRECTORY_HEADER_SIGNATURE
      raise Error.new("Expected end of central directory header signature, not 0x#{signature.to_s(16)}")
    end

    read Int16                     # number of this disk
    read Int16                     # disk start
    read Int16                     # number of entries in disk
    entries_size = read Int16      # number of total entries
    read UInt32                    # size of the central directory
    directory_offset = read UInt32 # offset of central directory
    comment_length = read UInt16   # comment length
    if comment_length != 0
      @comment = @io.read_string(comment_length)
    end
    {entries_size, directory_offset}
  end

  private def read_entries(directory_offset, entries_size)
    @io.pos = directory_offset

    entries_size.times do
      signature = read UInt32
      if signature != Zip::CENTRAL_DIRECTORY_HEADER_SIGNATURE
        raise Error.new("Expected directory header signature, not 0x#{signature.to_s(16)}")
      end

      entry = Entry.new(@io)
      @entries << entry
      @entries_by_filename[entry.filename] = entry
    end
  end

  private def read(type)
    @io.read_bytes(type, IO::ByteFormat::LittleEndian)
  end

  # An entry inside a `Zip::File`.
  #
  # Use the `open` method to read from it.
  class Entry
    include FileInfo

    # :nodoc:
    def initialize(@io : IO)
      super(at_central_directory_header: io)
    end

    # Yields an `IO` to read this entry's contents.
    # Multiple entries can be opened and read concurrently.
    def open
      @io.read_at(data_offset.to_i32, compressed_size.to_i32) do |io|
        io = decompressor_for(io, is_sized: true)
        checksum_reader = ChecksumReader.new(io, filename, verify: crc32)
        yield checksum_reader
      end
    end

    private getter(data_offset : UInt32) do
      # Apparently a zip entry might have different extra bytes
      # in the local file header and central directory header,
      # so to know the data offset we must read them again.
      #
      # The bytes inside a local file header, from the signature
      # and up to the extra length field, sum up 30 bytes.
      #
      # This 30 and 22 constants are burned inside the zip spec and
      # will never change.
      @io.read_at(offset.to_i32, 30) do |io|
        # at least check that the signature is OK (these are 4 bytes)
        signature = read(io, UInt32)
        if signature != FileInfo::SIGNATURE
          raise Zip::Error.new("Wrong local file header signature (expected 0x#{FileInfo::SIGNATURE.to_s(16)}, got 0x#{signature.to_s(16)})")
        end

        # Skip most of the headers except filename length and extra length
        # (skip 22, so we already read 26 bytes)
        io.skip(22)

        # With these two we read 4 bytes more, so we are at 30 bytes
        filename_length = read(io, UInt16)
        extra_length = read(io, UInt16)

        # The data of this entry comes at the local file header offset
        # plus 30 bytes (the ones we just skipped) plus skipping the
        # filename's bytes plus skipping the extra bytes.
        @offset + 30 + filename_length + extra_length
      end
    end
  end
end
