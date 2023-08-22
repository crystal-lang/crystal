require "compress/gzip"
require "spec"

# This spec tests piping a file with a size of more than
# UInt32::MAX bytes through GZip::Writer and GZ::Reader.
# Zipping and unzipping so many bytes takes some time,
# so this spec is quite slow.
it "Gzip file larger than UInt32::MAX" do
  read, write = IO.pipe
  bytes_written = 0_i64
  bytes_read = 0_i64

  spawn do
    slice = Slice.new(1024, 0_u8, read_only: true)

    Compress::Gzip::Writer.open(write) do |writer|
      target_bytes = UInt32::MAX.to_i64 + 1
      while bytes_written < target_bytes
        writer.write(slice)
        bytes_written += slice.bytesize
      end
    end

    write.close
  end

  Compress::Gzip::Reader.open(read) do |reader|
    slice = Slice.new(1024, 0_u8)

    while true
      read_bytes = reader.read(slice)
      break if read_bytes == 0
      bytes_read += read_bytes
    end

    read.close
  end

  bytes_read.should eq bytes_written
  bytes_read.should be > UInt32::MAX
end
