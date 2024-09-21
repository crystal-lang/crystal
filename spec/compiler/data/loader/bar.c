#include "../visibility.h"

LOCAL int foo() {
  return 42;
}

EXPORT int bar() {
  return foo() + 100;
}
