#include <ck_brlock.h>

ck_brlock_t brlock_init() {
  ck_brlock_t lock = CK_BRLOCK_INITIALIZER;
  return lock;
}

ck_brlock_reader_t brlock_reader_init() {
  ck_brlock_reader_t reader = CK_BRLOCK_READER_INITIALIZER;
  return reader;
}

void brlock_read_register(ck_brlock_t *lock, ck_brlock_reader_t *reader) {
  ck_brlock_read_register(lock, reader);
}

void brlock_read_lock(ck_brlock_t *lock, ck_brlock_reader_t *reader) {
  ck_brlock_read_lock(lock, reader);
}

void brlock_read_unlock(ck_brlock_reader_t *reader) {
  ck_brlock_read_unlock(reader);
}

void brlock_write_lock(ck_brlock_t *lock) {
  ck_brlock_write_lock(lock);
}

void brlock_write_unlock(ck_brlock_t *lock) {
  ck_brlock_write_unlock(lock);
}
