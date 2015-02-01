struct IO::FdSet
  NFDBITS = sizeof(Int32) * 8

  def self.from_ios(ios)
    fdset = new
    ios.try &.each do |io|
      fdset.set io
    end
    fdset
  end

  def initialize
    @fdset :: Int32[32]
    @fdset = StaticArray(Int32, 32).new(0)
  end

  def set(io)
    @fdset[io.fd / NFDBITS] |= 1 << (io.fd % NFDBITS)
  end

  def is_set(io)
    @fdset[io.fd / NFDBITS] & 1 << (io.fd % NFDBITS) != 0
  end

  def to_unsafe
    pointerof(@fdset) as Void*
  end
end

