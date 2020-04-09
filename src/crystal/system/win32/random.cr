require "c/ntsecapi"

module Crystal::System::Random
  def self.random_bytes(buf : Bytes) : Nil
    if LibC.RtlGenRandom(buf, buf.size) == 0
      raise RuntimeError.from_winerror("RtlGenRandom")
    end
  end

  def self.next_u : UInt8
    buf = uninitialized UInt8[1]
    random_bytes(buf.to_slice)
    buf.unsafe_as(UInt8)
  end
end
