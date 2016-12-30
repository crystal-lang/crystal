class SpinLock
  @lock = Atomic(UInt8).new(0_u8)

  def lock
    loop do
      next if @lock.get == 1_u8
      _, locked = @lock.compare_and_set(0_u8, 1_u8)
      break if locked
    end
  end

  def unlock
    @lock.lazy_set(0_u8)
  end

  def synchronize
    lock
    begin
      yield
    ensure
      unlock
    end
  end
end
