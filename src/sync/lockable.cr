module Sync
  # General type to abstract lockable types such as `Sync::Mutex` and
  # `Sync::RWLock` to be used interchangeably by other types, for example
  # `Sync::ConditionVariable`.
  module Lockable
    protected abstract def wait(cv : Pointer(CV)) : Nil
  end
end
