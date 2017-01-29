require "./file_info"

# Writes (streams) zip entries to an `IO`.
#
# ### Example
#
# ```
# File.open("./file.zip", "w") do |file|
#   Zip::Writer.open(file) do |zip|
#     # Add a file with a String content
#     zip.add "foo.txt", "contents of foo"
#
#     # Add a file and write data to it through an IO
#     zip.add("bar.txt") do |io|
#       io << "contents of bar"
#     end
#
#     # Add a file by referencing a file in the filesystem
#     # (the file is automatically closed after this call)
#     zip.add("baz.txt", File.open("./some_file.txt"))
#   end
# end
# ```
class Zip::Writer
  # Whether to close the enclosed `IO` when closing this writer.
  property? sync_close = false

  # Returns `true` if this writer is closed.
  getter? closed = false

  # Sets the zip file comment
  setter comment = ""

  # Creates a new writer to the given *io*.
  def initialize(@io : IO, @sync_close = false)
    @entries = [] of Entry
    @compressed_size_counter = ChecksumWriter.new
    @uncompressed_size_counter = ChecksumWriter.new(compute_crc32: true)

    # Keep track of how many bytes we write, because we need
    # that to write the offset of each local file header and some other info
    @written = 0_u32
  end

  # Creates a new writer to the given *filename*.
  def self.new(filename : String)
    new(::File.new(filename, "w"), sync_close: true)
  end

  # Creates a new writer to the given *io*, yields it to the given block,
  # and closes it at the end.
  def self.open(io : IO, sync_close = false)
    writer = new(io, sync_close: sync_close)
    yield writer ensure writer.close
  end

  # Creates a new writer to the given *filename*, yields it to the given block,
  # and closes it at the end.
  def self.open(filename : String)
    writer = new(filename)
    yield writer ensure writer.close
  end

  # Adds an entry that will have the given *filename* and current
  # time (`Time.now`) and yields an `IO` to write that entry's
  # contents.
  def add(filename : String)
    add(Entry.new(filename)) do |io|
      yield io
    end
  end

  # Adds an entry and yields `IO` to write that entry's contents.
  #
  # You can choose the Entry's compression method before adding it.
  #
  # * If the STORED compression method is used, its crc32, compressed
  # size and uncompressed size **must** be set and be correct with
  # respect to the data that will be written to the yielded `IO`.
  # * If the DEFLATED compression method is used, crc32, compresed
  # size and uncompressed size will be computed from the data
  # written to the yielded IO.
  #
  # You can also set the Entry's time (which is `Time.now` by default)
  #  and extra data before adding it to the zip stream.
  def add(entry : Entry)
    # bit 3: unknown compression size (not needed for STORED, by if left out it doesn't work...)
    entry.general_purpose_bit_flag |= (1 << 3)
    # bit 11: require UTF-8 set
    entry.general_purpose_bit_flag |= (1 << 11)
    entry.offset = @written

    @written += entry.to_io(@io)

    case entry.compression_method
    when .stored?
      if entry.compressed_size != entry.uncompressed_size
        raise Error.new "Entry compressed size (#{entry.compressed_size}) is not equal to its uncompressed size (#{entry.uncompressed_size})"
      end

      @uncompressed_size_counter.io = @io
      yield @uncompressed_size_counter
    when .deflated?
      @compressed_size_counter.io = @io
      io = Flate::Writer.new(@compressed_size_counter)
      @uncompressed_size_counter.io = io
      yield @uncompressed_size_counter
      io.close
    else
      raise "Unsupported compression method: #{entry.compression_method}"
    end

    @written += @compressed_size_counter.count

    crc32 = @uncompressed_size_counter.crc32.to_u32
    uncompressed_size = @uncompressed_size_counter.count

    if entry.compression_method.stored?
      compressed_size = uncompressed_size
    else
      compressed_size = @compressed_size_counter.count
    end

    if entry.compression_method.stored?
      if entry.crc32 != crc32
        raise Error.new("Entry CRC32 mistmacth (#{entry.crc32} given but was #{crc32})")
      end

      if entry.uncompressed_size != uncompressed_size
        raise Error.new("Entry uncompressed size mistmatch (#{entry.uncompressed_size} given but was #{uncompressed_size})")
      end
    else
      entry.crc32 = crc32
      entry.compressed_size = compressed_size
      entry.uncompressed_size = uncompressed_size
    end

    # A data descriptor is not needed for the STORED method
    # (because we know how many bytes we need to read)
    unless entry.compression_method.stored?
      @written += entry.write_data_descriptor(@io)
    end

    @entries << entry
  end

  # Adds an entry that will have *string* as its contents.
  def add(filename_or_entry : String | Entry, string : String)
    add(filename_or_entry) do |io|
      io << string
    end
  end

  # Adds an entry that will have *bytes* as its contents.
  def add(filename_or_entry : String | Entry, bytes : Bytes)
    add(filename_or_entry) do |io|
      io.write(bytes)
    end
  end

  # Adds an entry that will have its data copied from the given *data*.
  # If the given *data* is a `::File`, it is automatically closed
  # after data is copied from it.
  def add(filename_or_entry : String | Entry, data : IO)
    add(filename_or_entry) do |io|
      IO.copy(data, io)
      data.close if data.is_a?(::File)
    end
  end

  # Adds a directory entry that will have the given *name*.
  def add_dir(name)
    name = name + '/' unless name.ends_with?('/')
    add(Entry.new(name)) { }
  end

  # Closes this zip writer.
  def close
    return if @closed
    @closed = true

    start_offset = @written
    write_central_directory

    write_end_of_central_directory(start_offset, @written - start_offset)
    @io.close if @sync_close
  end

  private def write_central_directory
    @entries.each do |entry|
      write Zip::CENTRAL_DIRECTORY_HEADER_SIGNATURE # 4
      write Zip::VERSION                            # version made by (2)
      write Zip::VERSION                            # version needed to extract (2)
      @written += 8                                 # the 8 bytes we just wrote

      @written += entry.meta_to_io(@io)

      write entry.comment.bytesize.to_u16 # file comment length (2)
      write 0_u16                         # disk number start (2)
      write 0_u16                         # internal file attribute (2)
      write 0_u32                         # external file attribute (4)
      write entry.offset                  # relative offset of local header (4)
      @written += 14                      # the 14 bytes we just wrote

      @io << entry.filename
      @written += entry.filename.bytesize

      @io.write(entry.extra)
      @written += entry.extra.size

      @io << entry.comment
      @written += entry.comment.bytesize
    end
  end

  private def write_end_of_central_directory(offset, size)
    write Zip::END_OF_CENTRAL_DIRECTORY_HEADER_SIGNATURE
    write 0_u16                    # number of this disk
    write 0_u16                    # disk start
    write @entries.size.to_u16     # number of entries in disk
    write @entries.size.to_u16     # number of total entries
    write size.to_u32              # size of the central directory
    write offset.to_u32            # offset of central directory
    write @comment.bytesize.to_u16 # comment length
    @io << @comment                # comment
  end

  private def write(value)
    @io.write_bytes(value, IO::ByteFormat::LittleEndian)
  end

  # An entry to write into a `Zip::Writer`.
  class Entry
    include FileInfo
  end
end
