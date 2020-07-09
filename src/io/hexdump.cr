# IO object that prints an hexadecimal dump of all transferred data.
#
# Especially useful for debugging binary protocols on an IO, to understand
# better when and how data is sent or received.
#
# By default `IO::Hexdump` won't print anything; you must specify which of
# `read`, `write` or both you want to print.
#
# Example:
# ```
# require "io/hexdump"
# socket = IO::Memory.new("abc")
# io = IO::Hexdump.new(socket, output: STDERR, read: true)
# ```
#
# When data is read from *io* it will print something akin to the following on
# STDERR:
# ```text
# 00000000  50 52 49 20 2a 20 48 54  54 50 2f 32 2e 30 0d 0a  PRI * HTTP/2.0..
# 00000010  0d 0a 53 4d 0d 0a 0d 0a                           ..SM....
# 00000000  00 00 00 04                                       ....
# 00000000  00                                                .
# 00000000  00 00 00 00                                       ....
# ```
class IO::Hexdump < IO
  def initialize(@io : IO, @output : IO = STDERR, @read = false, @write = false)
  end

  def read(buf : Bytes)
    @io.read(buf).tap do |read_bytes|
      @output.puts buf[0, read_bytes].hexdump if @read && read_bytes
    end
  end

  def write(buf : Bytes) : Nil
    return if buf.empty?

    @io.write(buf).tap do
      @output.puts buf.hexdump if @write
    end
  end

  delegate :peek, :close, :closed?, :flush, :tty?, :pos, :pos=, :seek, to: @io
end
