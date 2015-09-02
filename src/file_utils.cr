module FileUtils
  extend self

  def cmp(filename1 : String, filename2 : String)
    return false unless File.size(filename1) == File.size(filename2)

    File.open(filename1, "rb") do |file1|
      File.open(filename2, "rb") do |file2|
        cmp(file1, file2)
      end
    end
  end

  def cmp(stream1 : IO, stream2 : IO)
    buf1 :: UInt8[1024]
    buf2 :: UInt8[1024]

    while true
      read1 = cmp_read stream1, buf1.to_slice
      read2 = cmp_read stream2, buf2.to_slice

      return false if read1 != read2
      return false if buf1.buffer.memcmp(buf2.buffer, read1) != 0
      return true if read1 == 0
    end
  end

  private def cmp_read io, slice
    io.read slice
  rescue IO::EOFError
    0
  end
end
