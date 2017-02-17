#include <stdio.h>

void (*debug_helper_func)() = 0;

void __crystal_debug_helper();

void __debug_helper() {
  void *p = &__crystal_debug_helper;
}
