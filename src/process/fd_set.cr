struct Process::FdSet
  NFDBITS = sizeof(Int32) * 8

  def initialize
    @fdset :: Int32[32]
  end

  def set(io)
    @fdset[io.fd / NFDBITS] |= 1 << (io.fd % NFDBITS)
  end

  def is_set(io)
    @fdset[io.fd / NFDBITS] & 1 << (io.fd % NFDBITS) != 0
  end

  def to_unsafe
    pointerof(@fdset)
  end
end

