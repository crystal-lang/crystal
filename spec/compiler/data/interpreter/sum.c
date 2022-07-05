#include <stdarg.h>
#include "../visibility.h"

EXPORT float sum_float(int count, ...) {
  va_list args;
  float total = 0;

  va_start(args, count);
  for (int i = 0; i < count; i++) {
    total += va_arg(args, double);
  }
  va_end(args);

  return total;
}

EXPORT long sum_int(int count, ...) {
  va_list args;
  long total = 0;

  va_start(args, count);
  for (int i = 0; i < count; i++) {
    total += va_arg(args, long);
  }
  va_end(args);

  return total;
}

EXPORT int simple_sum_int(int a, int b) {
  return a + b;
}
