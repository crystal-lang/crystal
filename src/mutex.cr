require "./sync/mutex"

# A fiber-safe mutex.
#
# Provides deadlock protection by default. Attempting to re-lock the mutex from
# the same fiber will raise an exception. Trying to unlock an unlocked mutex, or
# a mutex locked by another fiber will raise an exception.
#
# The reentrant protection maintains a lock count. Attempting to re-lock the
# mutex from the same fiber will increment the lock count. Attempting to unlock
# the counter from the same fiber will decrement the lock count, eventually
# releasing the lock when the lock count returns to 0. Attempting to unlock an
# unlocked mutex, or a mutex locked by another fiber will raise an exception.
#
# You also disable all protections with `unchecked`. Attempting to re-lock the
# mutex from the same fiber will deadlock. Any fiber can unlock the mutex, even
# if it wasn't previously locked.
alias Mutex = Sync::Mutex
