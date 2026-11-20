# An IO object that does nothing, yet always succeeds and never fails.
#
# Any attempt to read results in end-of-file (EOF). Any data written is
# immediately discarded.
#
# Can be used in place of another IO when there is nothing to read, or when the
# output can be discarded.
class IO::Null < IO
  # Always returns 0 (reached EOF).
  def read(slice : Bytes)
    0
  end

  # Returns immediately (discards *slice*).
  def write(slice : Bytes) : Nil
  end
end
