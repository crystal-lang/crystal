@[Extern(union: true)]
struct Foo
  @x : Float32
  @y = uninitialized UInt32
  @z = uninitialized UInt8[4]

  def initialize(@x)
  end
end

raise "wrong endianness" unless IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian

x = Foo.new(1.0_f32)
# print: x
# lldb-check: $0 = (x = 1065353216, y = 1, z = "\0\0\x80?")
# gdb-check: $1 = {x = 1065353216, y = 1, z = "\000\000\200?"}
debugger
