module FileUtils
  extend self

  def cmp(filename1, filename2)
    return false unless File.size(filename1) == File.size(filename2)

    File.open(filename1, "rb") do |file1|
      File.open(filename2, "rb") do |file2|
        compare_stream(file1, file2)
      end
    end
  end

  def compare_stream(stream1, stream2)
    buf1 :: UInt8[1024]
    buf2 :: UInt8[1024]

    while true
      read1 = stream1.read(buf1.buffer, 1024)
      read2 = stream2.read(buf2.buffer, 1024)

      return false if read1 != read2
      return false if !buf1.buffer.memcmp(buf2.buffer, read1)
      return true if read1 == 0
    end
  end
end
