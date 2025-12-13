module Sync
  # General type to abstract `Sync::Mutex` and `Sync::RWLock` that can both be
  # used by `Sync::ConditionVariable`.
  module Lockable
    protected abstract def wait(cv : Pointer(CV)) : Nil
  end
end
