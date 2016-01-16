#include <ck_rwlock.h>

ck_rwlock_t rwlock_init() {
  ck_rwlock_t lock = CK_RWLOCK_INITIALIZER;
  return lock;
}

void rwlock_read_lock(ck_rwlock_t *lock) {
  ck_rwlock_read_lock(lock);
}

void rwlock_read_unlock(ck_rwlock_t *lock) {
  ck_rwlock_read_unlock(lock);
}

void rwlock_write_lock(ck_rwlock_t *lock) {
  ck_rwlock_write_lock(lock);
}

void rwlock_write_unlock(ck_rwlock_t *lock) {
  ck_rwlock_write_unlock(lock);
}
