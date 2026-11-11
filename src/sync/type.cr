module Sync
  enum Type
    # The lock doesn't do any checks. Trying to relock will cause a deadlock,
    # unlocking from any fiber is undefined behavior.
    Unchecked

    # The lock checks whether the current fiber owns the lock (relock), or
    # whether the fiber that owns the lock is waiting on a lock own by the
    # current fiber. Both cases will raise an `Error::Deadlock`.
    #
    # Trying to unlock when unlocked or while another fiber holds the lock will
    # raise an `Error`.
    Checked

    # Same as `Checked` with the difference that the lock allows the same fiber
    # to relock as many times as needed, then must be unlocked as many times as
    # it was re-locked.
    #
    # Regarding `RWLock`, reentrancy only affects the exclusive (write) lock,
    # because a reentrant read lock can cause a deadlock if another fiber is
    # trying to lock write.
    Reentrant
  end
end
