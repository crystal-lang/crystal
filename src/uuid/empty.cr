struct UUID
  # Empty UUID.
  @@empty_bytes = StaticArray(UInt8, 16).new { 0_u8 }

  # Returns empty UUID (aka nil UUID where all bytes are set to `0`).
  def self.empty
    UUID.new @@empty_bytes
  end

  # Resets UUID to an empty one.
  def empty!
    @bytes = @@empty_bytes
  end
end
