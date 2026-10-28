require "c/stdlib"

module Crystal::System::Random
  def self.random_bytes(buf : Bytes) : Nil
    LibC.arc4random_buf(buf, buf.size)
  end

  def self.next_u : UInt8
    buf = uninitialized UInt8
    random_bytes(pointerof(buf).to_slice(1))
    buf
  end
end
