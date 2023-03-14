require "./lib_wasi"

module Crystal::System::Random
  def self.random_bytes(buf : Bytes) : Nil
    err = LibWasi.random_get(buf, buf.size)
    raise RuntimeError.from_os_error("random_get", err) unless err.success?
  end

  def self.next_u : UInt8
    buf = uninitialized UInt8[1]
    random_bytes(buf.to_slice)
    buf.unsafe_as(UInt8)
  end
end
