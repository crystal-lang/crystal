require "./lib_wasi"

module Crystal::System::Random
  def self.random_bytes(buf : Bytes) : Nil
    err = LibWasi.random_get(buf, buf.size)
    raise RuntimeError.from_os_error("random_get", err) unless err.success?
  end

  def self.next_u : UInt8
    buf = uninitialized UInt8
    random_bytes(pointerof(buf).to_slice(1))
    buf
  end
end
