#include <stdarg.h>

int answer()
{
    return 42;
}

int sum(int a, int b, int c)
{
    return a + b + c;
}

void sum_primitive_types(
    unsigned char a, signed char b,
    unsigned short c, signed short d,
    unsigned long e, signed long f,
    unsigned long long g, signed long long h,
    float i, double j,
    long *k)
{
    *k = a + b + c + d + e + f + g + h + (long)i + (long)j + *k;
}

struct test_struct
{
    char b;
    short s;
    int i;
    long long j;
    float f;
    double d;
    int *p;
};

int sum_struct(struct test_struct s)
{
    *s.p = s.b + s.s + s.i + s.j + s.f + s.d + *(s.p);
    return *s.p;
}

int sum_variadic(int count, ...)
{
    va_list ap;
    int j;
    int sum = 0;

    va_start(ap, count); /* Requires the last fixed parameter (to get the address) */
    for (j = 0; j < count; j++)
    {
        sum += va_arg(ap, int); /* Increments ap to the next argument. */
    }
    va_end(ap);

    return sum;
}

struct test_struct make_struct(char b, short s, int i, long long j, float f, double d, void *p)
{
    static struct test_struct t;
    t.b = b;
    t.s = s;
    t.i = i;
    t.j = j;
    t.f = f;
    t.d = d;
    t.p = p;
    return t;
}
