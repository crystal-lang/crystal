# The BufferedIO mixin enhances the IO module with seek support for input/output buffering.
module IO::Buffered::Seeker
  # Rewinds the wrapped IO.
  abstract def unbuffered_rewind

  # Rewinds the underlying IO.
  def rewind
    unbuffered_rewind
    @in_buffer_rem = Slice.new(Pointer(UInt8).null, 0)
  end
end
