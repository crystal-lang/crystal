require "spec"

private class PartialReaderIO < IO
  @slice : Bytes

  def initialize(data : String)
    @slice = data.to_slice
  end

  def read(slice : Bytes)
    return 0 if @slice.size == 0
    max_read_size = {slice.size, @slice.size}.min
    read_size = rand(1..max_read_size)
    slice.copy_from(@slice[0, read_size])
    @slice += read_size
    read_size
  end

  def write(slice : Bytes) : NoReturn
    raise "write"
  end
end

private class MemoryIOWithoutPeek < IO::Memory
  def peek
    nil
  end
end

private class MemoryIOWithFixedPeek < IO::Memory
  property peek_size = 0

  def peek
    Slice.new(@buffer + @pos, {@bytesize - @pos, peek_size}.min)
  end
end

describe "IO::Delimited" do
  describe "#read" do
    context "without peeking" do
      it "doesn't read past the limit" do
        io = MemoryIOWithoutPeek.new("abcderzzrfgzr")
        delimited = IO::Delimited.new(io, read_delimiter: "zr")

        delimited.gets_to_end.should eq("abcderz")
        io.gets_to_end.should eq("fgzr")
      end

      it "doesn't read past the limit (char-by-char)" do
        io = MemoryIOWithoutPeek.new("abcderzzrfg")
        delimited = IO::Delimited.new(io, read_delimiter: "zr")

        delimited.read_char.should eq('a')
        delimited.read_char.should eq('b')
        delimited.read_char.should eq('c')
        delimited.read_char.should eq('d')
        delimited.read_char.should eq('e')
        delimited.read_char.should eq('r')
        delimited.read_char.should eq('z')
        delimited.read_char.should eq(nil)
        delimited.read_char.should eq(nil)
        delimited.read_char.should eq(nil)
        delimited.read_char.should eq(nil)

        io.read_char.should eq('f')
        io.read_char.should eq('g')
      end

      it "doesn't clobber active_delimiter_buffer" do
        io = MemoryIOWithoutPeek.new("ab12312")
        delimited = IO::Delimited.new(io, read_delimiter: "12345")

        delimited.gets_to_end.should eq("ab12312")
      end

      it "handles the delimiter at the start" do
        io = MemoryIOWithoutPeek.new("ab12312")
        delimited = IO::Delimited.new(io, read_delimiter: "ab1")

        delimited.read_char.should eq(nil)
      end

      it "handles the delimiter at the end" do
        io = MemoryIOWithoutPeek.new("ab12312z")
        delimited = IO::Delimited.new(io, read_delimiter: "z")

        delimited.gets_to_end.should eq("ab12312")
      end

      it "handles nearly a delimiter at the end" do
        io = MemoryIOWithoutPeek.new("ab12312")
        delimited = IO::Delimited.new(io, read_delimiter: "122")

        delimited.gets_to_end.should eq("ab12312")
      end

      it "doesn't clobber the buffer on closely-offset partial matches" do
        io = MemoryIOWithoutPeek.new("abab1234abcdefgh")
        delimited = IO::Delimited.new(io, read_delimiter: "abcdefgh")

        delimited.gets_to_end.should eq("abab1234")
      end
    end

    context "with partial read" do
      it "handles partial reads" do
        io = PartialReaderIO.new("abab1234abcdefgh")
        delimited = IO::Delimited.new(io, read_delimiter: "abcdefgh")

        delimited.gets_to_end.should eq("abab1234")
      end
    end

    context "with peeking" do
      it "returns empty when there's no data" do
        io = IO::Memory.new("")
        delimited = IO::Delimited.new(io, read_delimiter: "zr")

        delimited.peek.should eq("".to_slice)
        delimited.gets_to_end.should eq("")
        io.gets_to_end.should eq("")
      end

      it "doesn't read past the limit" do
        io = IO::Memory.new("abcderzzrfgzr")
        delimited = IO::Delimited.new(io, read_delimiter: "zr")

        delimited.peek.should eq("abcderz".to_slice)
        delimited.gets_to_end.should eq("abcderz")
        io.gets_to_end.should eq("fgzr")
      end

      it "doesn't read past the limit, single byte" do
        io = IO::Memory.new("abcderzzrfgzr")
        delimited = IO::Delimited.new(io, read_delimiter: "f")

        delimited.peek.should eq("abcderzzr".to_slice)
        delimited.gets_to_end.should eq("abcderzzr")
        io.gets_to_end.should eq("gzr")
      end

      it "doesn't read past the limit (char-by-char)" do
        io = IO::Memory.new("abcderzzrfg")
        delimited = IO::Delimited.new(io, read_delimiter: "zr")

        delimited.read_char.should eq('a')
        delimited.read_char.should eq('b')
        delimited.read_char.should eq('c')
        delimited.read_char.should eq('d')
        delimited.read_char.should eq('e')
        delimited.read_char.should eq('r')
        delimited.read_char.should eq('z')
        delimited.read_char.should eq(nil)
        delimited.read_char.should eq(nil)
        delimited.read_char.should eq(nil)
        delimited.read_char.should eq(nil)

        io.read_char.should eq('f')
        io.read_char.should eq('g')
      end

      it "doesn't clobber active_delimiter_buffer" do
        io = IO::Memory.new("ab12312")
        delimited = IO::Delimited.new(io, read_delimiter: "12345")

        delimited.peek.should eq("ab123".to_slice)
        delimited.gets_to_end.should eq("ab12312")
      end

      it "handles the delimiter at the start" do
        io = IO::Memory.new("ab12312")
        delimited = IO::Delimited.new(io, read_delimiter: "ab1")

        delimited.peek.should eq(Bytes.empty)
        delimited.read_char.should eq(nil)
      end

      it "handles the delimiter at the end" do
        io = IO::Memory.new("ab12312z")
        delimited = IO::Delimited.new(io, read_delimiter: "z")

        delimited.peek.should eq("ab12312".to_slice)
        delimited.gets_to_end.should eq("ab12312")
      end

      it "handles nearly a delimiter at the end" do
        io = IO::Memory.new("ab12312")
        delimited = IO::Delimited.new(io, read_delimiter: "122")

        delimited.peek.should eq("ab123".to_slice)
        delimited.gets_to_end.should eq("ab12312")
      end

      it "doesn't clobber the buffer on closely-offset partial matches" do
        io = IO::Memory.new("abab1234abcdefgh")
        delimited = IO::Delimited.new(io, read_delimiter: "abcdefgh")

        delimited.peek.should eq("abab1234".to_slice)
        delimited.gets_to_end.should eq("abab1234")
      end

      it "handles the case of peek matching first byte, not having enough room, but rest not matching" do
        #                                 not a delimiter
        #                                    ---
        io = MemoryIOWithFixedPeek.new("abcdefwhi")
        #                               -------
        #                                peek
        io.peek_size = 7
        delimited = IO::Delimited.new(io, read_delimiter: "fgh")

        delimited.peek.should eq("abcde".to_slice)
        delimited.gets_to_end.should eq("abcdefwhi")
        delimited.gets_to_end.should eq("")
        io.gets_to_end.should eq("")
      end

      it "handles the case of peek matching first byte, not having enough room, but rest not immediately matching (with a potential match afterwards)" do
        #                                 not a delimiter, but the second 'f' will actually match the delimiter
        #                                    ---
        io = MemoryIOWithFixedPeek.new("abcdeffghijk")
        #                               -------
        #                                peek
        io.peek_size = 7
        delimited = IO::Delimited.new(io, read_delimiter: "fgh")

        delimited.peek.should eq("abcde".to_slice)
        delimited.gets_to_end.should eq("abcdef")
        delimited.gets_to_end.should eq("")
        io.gets_to_end.should eq("ijk")
      end

      it "handles the case of peek matching first byte, not having enough room, but later matching" do
        #                                  delimiter
        #                                    ---
        io = MemoryIOWithFixedPeek.new("abcdefghijk")
        #                               -------
        #                                peek
        io.peek_size = 7
        delimited = IO::Delimited.new(io, read_delimiter: "fgh")

        delimited.peek.should eq("abcde".to_slice)
        delimited.gets_to_end.should eq("abcde")
        delimited.gets_to_end.should eq("")
        io.gets_to_end.should eq("ijk")
      end

      it "handles the case of peek matching first byte, not having enough room, but later not matching" do
        #                                 not a delimiter
        #                                    ---
        io = MemoryIOWithFixedPeek.new("abcdefgwijkfghhello")
        #                               -------    ---
        #                                peek    delimiter
        io.peek_size = 7
        delimited = IO::Delimited.new(io, read_delimiter: "fgh")

        delimited.peek.should eq("abcde".to_slice)
        delimited.gets_to_end.should eq("abcdefgwijk")
        delimited.gets_to_end.should eq("")
        io.gets_to_end.should eq("hello")
      end

      it "handles the case of peek matching first byte, not having enough room, later only partially matching" do
        #                                  delimiter
        #                                    ------------
        io = MemoryIOWithFixedPeek.new("abcdefghijklmnopqrst")
        #                               -------~~~~~~~
        #                                peek   peek
        io.peek_size = 7
        delimited = IO::Delimited.new(io, read_delimiter: "fghijklmnopq")

        delimited.peek.should eq("abcde".to_slice)
        delimited.gets_to_end.should eq("abcde")
        delimited.gets_to_end.should eq("")
        io.gets_to_end.should eq("rst")
      end

      it "peeks, everything matches but we can't know what will happen after that" do
        io = MemoryIOWithFixedPeek.new("fgh")
        io.peek_size = 2
        delimited = IO::Delimited.new(io, read_delimiter: "fgh")

        delimited.peek.should be_nil
      end

      it "handles the case of the active delimited buffer including the delimiter" do
        #                              delimiter
        #                                ---
        io = MemoryIOWithFixedPeek.new("aaabcde")
        #                               --
        #                              peek
        io.peek_size = 2
        delimited = IO::Delimited.new(io, read_delimiter: "aab")

        delimited.peek.should be_nil
        delimited.gets_to_end.should eq("a")
        delimited.gets_to_end.should eq("")
        io.gets_to_end.should eq("cde")
      end

      it "can peek if first byte found but doesn't fully match, and there's that first byte again in the peek buffer" do
        #                                 delimiter
        #                                   -----
        io = MemoryIOWithFixedPeek.new("holhhello")
        #                               ----
        #                               peek
        io.peek_size = 4
        delimited = IO::Delimited.new(io, read_delimiter: "hello")

        delimited.peek.should eq("hol".to_slice)
      end

      it "can peek if first byte found but doesn't fully match, and the byte isn't there in the peek buffer" do
        #                                 delimiter
        #                                   -----
        io = MemoryIOWithFixedPeek.new("holahello")
        #                               ----
        #                               peek
        io.peek_size = 4
        delimited = IO::Delimited.new(io, read_delimiter: "hello")

        delimited.peek.should eq("hola".to_slice)
      end
    end
  end

  describe "#gets with peeking when can't peek" do
    it "gets" do
      io = MemoryIOWithFixedPeek.new("abcdefghel")
      io.peek_size = 7

      delimited = IO::Delimited.new(io, read_delimiter: "hello")

      # We first peek "abcdefg".
      # The delimiter's first byte isn't there so we read everything.
      # Next we peek "hel". It matches the delimiter's beginning
      # but `peek` can't tell whether there's more content or not
      # after that, and it can't return an empty buffer because that
      # means EOF. So it must return `nil`. So `IO#gets` should
      # handle this case where `peek` becomes `nil`.
      delimited.gets.should eq("abcdefghel")
    end

    it "peeks" do
      io = MemoryIOWithFixedPeek.new("hel")
      io.peek_size = 1

      delimited = IO::Delimited.new(io, read_delimiter: "hello")
      delimited.read(Bytes.new(1))

      delimited.peek.should eq("el".to_slice)
    end
  end

  describe "#write" do
    it "raises" do
      delimited = IO::Delimited.new(IO::Memory.new, read_delimiter: "zr")
      expect_raises(IO::Error, "Can't write to IO::Delimited") do
        delimited.puts "test string"
      end
    end
  end

  describe "#close" do
    it "stops reading" do
      io = IO::Memory.new "abcdefg"
      delimited = IO::Delimited.new(io, read_delimiter: "zr")

      delimited.read_char.should eq('a')
      delimited.read_char.should eq('b')

      delimited.close
      delimited.closed?.should eq(true)
      expect_raises(IO::Error, "Closed stream") do
        delimited.read_char
      end
    end

    it "closes the underlying stream if sync_close is true" do
      io = IO::Memory.new "abcdefg"
      delimited = IO::Delimited.new(io, read_delimiter: "zr", sync_close: true)
      delimited.sync_close?.should eq(true)

      io.closed?.should eq(false)
      delimited.close
      io.closed?.should eq(true)
    end
  end
end
