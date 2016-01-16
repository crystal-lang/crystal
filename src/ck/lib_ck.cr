@[Link(ldflags: "#{__DIR__}/ext/ck_ext.o")]
lib LibCK
  struct RWLock
    writers : LibC::UInt
    n_readers : LibC::UInt
  end

  fun rwlock_init : RWLock
  fun rwlock_read_lock(RWLock*)
  fun rwlock_read_unlock(RWLock*)
  fun rwlock_write_lock(RWLock*)
  fun rwlock_write_unlock(RWLock*)

  struct BRLockReader
    n_readers : LibC::UInt
    previous : BRLockReader*
    next : BRLockReader*
  end

  struct BRLock
    readers : BRLockReader*
    writer : LibC::UInt
  end

  fun brlock_init : BRLock
  fun brlock_reader_init : BRLockReader
  fun brlock_read_register(lock : BRLock*, reader : BRLockReader*)
  fun brlock_read_lock(lock : BRLock*, reader : BRLockReader*)
  fun brlock_read_unlock(reader : BRLockReader*)
  fun brlock_write_lock(lock : BRLock*)
  fun brlock_write_unlock(lock : BRLock*)
end
