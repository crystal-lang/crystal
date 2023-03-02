/*
 * Compile with `cl.exe /LD win32_interpreter_stub.c`
 * FIXME: implement fixed-precision float printing in pure Crystal so that
 * we don't need these two functions at all (Ryu-printf or jk-jeon/floff)
 */

#include <stdio.h>
#include <stdarg.h>

__declspec(dllexport) int __crystal_printf(const char *format, ...) {
    va_list args;
    va_start(args, format);
    int result = vprintf(format, args);
    va_end(args);
    return result;
}

__declspec(dllexport) int __crystal_snprintf(char *buffer, size_t count, const char *format, ...) {
    va_list args;
    va_start(args, format);
    int result = vsnprintf(buffer, count, format, args);
    va_end(args);
    return result;
}
