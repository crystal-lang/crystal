{% skip_file unless flag?(:unix) && !flag?(:openbsd) && !flag?(:linux) %}

require "./urandom"

module Crystal::System::Random
  def self.random_bytes(buf : Bytes) : Nil
    Crystal::System::Urandom.random_bytes(buf)
  end

  def self.next_u : UInt8
    buf = uninitialized UInt8[1]
    random_bytes(buf.to_slice)
    buf.unsafe_at(0)
  end
end
