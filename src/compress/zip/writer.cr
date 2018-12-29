require "./file_info"
require "./serializer"

# Writes (streams) zip entries to an `IO`.
#
# ### Example
#
# ```
# require "compress/zip"
#
# File.open("./file.zip", "w") do |file|
#   Compress::Zip::Writer.open(file) do |zip|
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
class Compress::Zip::Writer
  # Gets raised if you try to add the same filename to a ZIP archive twice
  class DuplicateEntryFilename < ArgumentError
  end

  # Whether to close the enclosed `IO` when closing this writer.
  property? sync_close = false

  # Returns `true` if this writer is closed.
  getter? closed = false

  # Sets the zip file comment
  setter comment = ""

  # Creates a new writer to the given *io*.
  def initialize(io : IO, @sync_close = false)
    @raw_io = io
    @written = Zip::OutputCounter.new # keeps track of how many bytes we write
    @io = IO::MultiWriter.new(@raw_io, @written)

    @entries = [] of Entry
    @filenames = Set(String).new

    @serializer = Zip::Serializer.new
  end

  # Creates a new writer to the given *filename*.
  def self.new(filename : Path | String)
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
  def self.open(filename : Path | String)
    writer = new(filename)
    yield writer ensure writer.close
  end

  # Adds an entry that will have the given *filename* and current
  # time (`Time.utc`) and yields an `IO` to write that entry's
  # contents.
  def add(filename : Path | String)
    add(Entry.new(filename.to_s)) do |io|
      yield io
    end
  end

  # Adds an Entry and yields `IO` for writing that entry's contents. After the IO
  # has been written and the block terminates will write out the accumulated CRC32
  # for the entry and the sizes as the data descriptor.
  #
  # Entry can be configured the same way as for `add()` without the block, however
  # the bit 3 of the general_purpose_bit_flag is going to be forcibly set, and the
  # compressed/uncompressed sizes and CRC32 are going to be reset to 0.
  def add(entry : Entry)
    # Configure the entry for data descriptor use
    # bit 3: "use data descriptor" flag - if it is set, the crc32 and sizes
    # must be written as 0 in the local entry header
    entry.general_purpose_bit_flag |= (1 << 3)

    # These three fields have to be set to 0
    entry.crc32 = 0_u32
    entry.compressed_size = 0_u64
    entry.uncompressed_size = 0_u64

    add(entry) # Without the block it will write out the local file header only

    # For the compressed data length (how much data goes into the archive for
    # this particular entry) we can use our global write counter
    entry_body_starts_at = @written.to_u64
    uncompressed_size_counter = Zip::OutputCounter.new
    crc32_writer = Zip::CRC32Writer.new
    case entry.compression_method
    when .stored?
      output_io = IO::MultiWriter.new(@io, uncompressed_size_counter, crc32_writer)
      yield output_io
    when .deflated?
      deflater = Compress::Deflate::Writer.new(@io)
      output_io = IO::MultiWriter.new(deflater, uncompressed_size_counter, crc32_writer)
      yield output_io
      deflater.close # Needed to flush the accumulated deflate buffers that might be remaining
    else
      raise "Unsupported compression method: #{entry.compression_method}"
    end

    entry.crc32 = crc32_writer.to_u32
    entry.uncompressed_size = uncompressed_size_counter.bytes_written
    entry.compressed_size = @written.to_u64 - entry_body_starts_at

    # A data descriptor is necessary _always_ if the gp_flags bit 3 is set (the current implementation always uses it)
    @serializer.write_data_descriptor(io: @io, crc32: entry.crc32, compressed_size: entry.compressed_size, uncompressed_size: entry.uncompressed_size)
  end

  # Adds an Entry to the Writer and writes out its local file header.
  #
  # Calling the method without the block does not enable data descriptors, so the
  # CRC32 for the entry has to be set upfront, as well as the correct `compressed_size`
  # and `uncompressed_size`
  #
  # You can choose the Entry's compression method before adding it.
  # You can also set the Entry's time (which is `Time.utc` by default)
  #  and extra data before adding it to the zip stream.
  def add(entry : Entry)
    if @filenames.includes?(entry.filename)
      raise DuplicateEntryFilename.new("Entry named #{entry.filename.inspect} has already been added to the archive")
    else
      @filenames.add(entry.filename)
    end

    # Set bit 11 (EFS) telling the reader that the filename is stored in UTF-8. Not needef for ASCII strings
    unless entry.filename.ascii_only?
      entry.general_purpose_bit_flag |= (1 << 11)
    end

    entry.offset = @written.to_u64 # where the local file header will start in the archive
    @serializer.write_local_file_header(io: @io,
      filename: entry.filename,
      compressed_size: entry.compressed_size,
      uncompressed_size: entry.uncompressed_size,
      crc32: entry.crc32,
      gp_flags: entry.general_purpose_bit_flag,
      mtime: entry.time,
      storage_mode: entry.compression_method.to_i,
      additional_extra_fields: entry.extra)
    @entries << entry
    # The caller can then write the full compressed file contents into the target @io
  end

  # Adds an entry that will have *string* as its contents.
  def add(filename_or_entry : Path | String | Entry, string : String) : Nil
    add(filename_or_entry) do |io|
      io << string
    end
  end

  # Adds an entry that will have *bytes* as its contents.
  def add(filename_or_entry : Path | String | Entry, bytes : Bytes) : Nil
    add(filename_or_entry) do |io|
      io.write(bytes)
    end
  end

  # Adds an entry that will have its data copied from the given *data*.
  # If the given *data* is a `::File`, it is automatically closed
  # after data is copied from it.
  def add(filename_or_entry : Path | String | Entry, data : IO) : Nil
    add(filename_or_entry) do |io|
      IO.copy(data, io)
      data.close if data.is_a?(::File)
    end
  end

  # Adds a directory entry that will have the given *name*.
  def add_dir(name) : Nil
    name = name + '/' unless name.ends_with?('/')
    add(Entry.new(name)) { }
  end

  # Closes this zip writer.
  def close : Nil
    return if @closed
    @closed = true

    central_directory_at = @written.to_u64
    write_central_directory
    write_end_of_central_directory(central_directory_at, @written.to_u64 - central_directory_at)

    @io.close if @sync_close
  end

  # Advance the internal offset by a number of bytes.
  # This can be useful for esimating the size of the resulting ZIP archive
  # without having access to the contents of files that are going to be
  # included in the archive later.
  def simulate_write(by : Int)
    @written.simulate_write(by)
  end

  # How many bytes have been written into the destination IO so far
  def written
    @written.to_u64
  end

  private def write_central_directory
    @entries.each do |entry|
      @serializer.write_central_directory_file_header(io: @io,
        filename: entry.filename,
        compressed_size: entry.compressed_size,
        uncompressed_size: entry.uncompressed_size,
        crc32: entry.crc32,
        gp_flags: entry.general_purpose_bit_flag,
        mtime: Time.utc,
        storage_mode: entry.compression_method.to_i,
        local_file_header_location: entry.offset,
        additional_extra_fields: entry.extra)
    end
  end

  private def write_end_of_central_directory(offset, size)
    @serializer.write_end_of_central_directory(io: @io,
      start_of_central_directory_location: offset,
      central_directory_size: size,
      num_files_in_archive: @entries.size)
  end

  # An entry to write into a `Zip::Writer`.
  class Entry
    include FileInfo
  end
end
