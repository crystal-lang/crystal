{% skip_file unless flag?(:bsd) || flag?(:darwin) %}

require "c/stdlib"

module Crystal::System::Random
  # Fills *buffer* with random bytes using arc4random.
  def self.random_bytes(buffer : Bytes) : Nil
    LibC.arc4random_buf(buffer.to_unsafe.as(Void*), buffer.size)
  end

  def self.next_u : UInt32
    LibC.arc4random
  end
end
