require "spec"
require "io/hexdump"

describe IO::Hexdump do
  describe "read" do
    it "prints hexdump" do
      ascii_table = <<-EOF
        00000000  20 21 22 23 24 25 26 27  28 29 2a 2b 2c 2d 2e 2f   !"#$%&'()*+,-./
        00000010  30 31 32 33 34 35 36 37  38 39 3a 3b 3c 3d 3e 3f  0123456789:;<=>?
        00000020  40 41 42 43 44 45 46 47  48 49 4a 4b 4c 4d 4e 4f  @ABCDEFGHIJKLMNO
        00000030  50 51 52 53 54 55 56 57  58 59 5a 5b 5c 5d 5e 5f  PQRSTUVWXYZ[\\]^_
        00000040  60 61 62 63 64 65 66 67  68 69 6a 6b 6c 6d 6e 6f  `abcdefghijklmno
        00000050  70 71 72 73 74 75 76 77  78 79 7a 7b 7c 7d 7e 7f  pqrstuvwxyz{|}~.
        00000060  80 81 82 83 84                                    .....
        EOF

      IO.pipe do |r, w|
        io = IO::Memory.new(ascii_table.bytesize)
        r = IO::Hexdump.new(r, output: io, read: true)

        slice = Bytes.new(101) { |i| i.to_u8 + 32 }
        w.write(slice)

        buf = uninitialized UInt8[101]
        r.read_fully(buf.to_slice).should eq(101)
        buf.to_slice.should eq(slice)

        io.to_s.should eq("#{ascii_table}\n")
      end
    end
  end

  describe "write" do
    it "prints hexdump" do
      ascii_table = <<-EOF
        00000000  20 21 22 23 24 25 26 27  28 29 2a 2b 2c 2d 2e 2f   !"#$%&'()*+,-./
        00000010  30 31 32 33 34 35 36 37  38 39 3a 3b 3c 3d 3e 3f  0123456789:;<=>?
        00000020  40 41 42 43 44 45 46 47  48 49 4a 4b 4c 4d 4e 4f  @ABCDEFGHIJKLMNO
        00000030  50 51 52 53 54 55 56 57  58 59 5a 5b 5c 5d 5e 5f  PQRSTUVWXYZ[\\]^_
        00000040  60 61 62 63 64 65 66 67  68 69 6a 6b 6c 6d 6e 6f  `abcdefghijklmno
        00000050  70 71 72 73 74 75 76 77  78 79 7a 7b 7c 7d 7e 7f  pqrstuvwxyz{|}~.
        EOF

      IO.pipe do |r, w|
        io = IO::Memory.new(ascii_table.bytesize)
        w = IO::Hexdump.new(w, output: io, write: true)

        slice = Bytes.new(96) { |i| i.to_u8 + 32 }
        w.write(slice)

        buf = uninitialized UInt8[96]
        r.read_fully(buf.to_slice).should eq(96)
        buf.to_slice.should eq(slice)

        io.to_s.should eq("#{ascii_table}\n")
      end
    end
  end
end
