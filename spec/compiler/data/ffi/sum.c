#include <stdarg.h>
#include <stdint.h>
#include "../visibility.h"

// all the integral return types must be at least as large as the register size
// to avoid integer promotion by FFI!

EXPORT int64_t answer()
{
    return 42;
}

EXPORT int64_t sum(int32_t a, int32_t b, int32_t c)
{
    return a + b + c;
}

EXPORT void sum_primitive_types(
    uint8_t a, int8_t b,
    uint16_t c, int16_t d,
    uint32_t e, int32_t f,
    uint64_t g, int64_t h,
    float i, double j,
    int64_t *k)
{
    *k = a + b + c + d + e + f + g + h + (int64_t)i + (int64_t)j + *k;
}

struct test_struct
{
    int8_t b;
    int16_t s;
    int32_t i;
    int64_t j;
    float f;
    double d;
    void *p;
};

EXPORT int64_t sum_struct(struct test_struct s)
{
    int64_t *p = (int64_t *)s.p;
    *p = s.b + s.s + s.i + s.j + s.f + s.d + *p;
    return *p;
}

EXPORT int64_t sum_array(int32_t ary[4])
{
    int64_t sum = 0;
    for (int32_t i = 0; i < 4; i++)
    {
        sum += ary[i];
    }
    return sum;
}

EXPORT int64_t sum_variadic(int32_t count, ...)
{
    va_list ap;
    int32_t j;
    int64_t sum = 0;

    va_start(ap, count); /* Requires the last fixed parameter (to get the address) */
    for (j = 0; j < count; j++)
    {
        sum += va_arg(ap, int32_t); /* Increments ap to the next argument. */
    }
    va_end(ap);

    return sum;
}

EXPORT struct test_struct make_struct(int8_t b, int16_t s, int32_t i, int64_t j, float f, double d, void *p)
{
    struct test_struct t;
    t.b = b;
    t.s = s;
    t.i = i;
    t.j = j;
    t.f = f;
    t.d = d;
    t.p = p;
    return t;
}
