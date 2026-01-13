# Synchronization primitives to build concurrent-safe and parallel-safe data
# structures, so we can embrace concurrency and parallelism with more serenity.
#
# Communication through a `Channel` should be preferred whenever possible, but
# sometimes we need to protect critical sections manually, for example to build
# higher level constructs, or to protect a mutable global constant:
#
# - `Sync::Mutex` to protect critical sections using mutual exclusion.
# - `Sync::RWLock` to protect critical sections using shared access and mutual
#   exclusion.
# - `Sync::ConditionVariable` to synchronize critical sections together.
# - `Sync::Exclusive(T)` to protect a value `T` using mutual exclusion.
# - `Sync::Shared(T)` to protect a value `T` using a mix of shared access and
#   mutual exclusion.
module Sync
end
