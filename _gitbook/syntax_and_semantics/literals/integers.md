# Integers

There are four signed integer types: [Int8](http://crystal-lang.org/api/Int8.html), [Int16](http://crystal-lang.org/api/Int16.html), [Int32](http://crystal-lang.org/api/Int32.html) and [Int64](http://crystal-lang.org/api/Int64.html), being able to represent numbers of 8, 16, 32 and 64 bits respectively.

There are four unsigned integer types: [UInt8](http://crystal-lang.org/api/UInt8.html), [UInt16](http://crystal-lang.org/api/UInt16.html), [UInt32](http://crystal-lang.org/api/UInt32.html) and [UInt64](http://crystal-lang.org/api/UInt64.html).

An integer literal is an optional `+` or `-` sign, followed by
a sequence of digits and underscores, optionally followed by a suffix.
If no suffix is present, the literal's type is the lowest betwen `Int32`, `Int64` and `UInt64`
in which the number fits:

```ruby
1      # Int32

1_i8   # Int8
1_i16  # Int16
1_i32  # Int32
1_i64  # Int64

1_u8   # UInt8
1_u16  # UInt16
1_u32  # UInt32
1_u64  # UInt64

+10    # Int32
-20    # Int32

2147483648          # Int64
9223372036854775808 # UInt64
```

The underscore `_` before the suffix is optional.

Underscores can be used to make some numbers more readable:

```ruby
1_000_000 # better than 1000000
```

Binary numbers start with `0b`:

```ruby
0b1101 # == 13
```

Octal numbers start with a zero:

```ruby
0123 # == 83
```

Hexadecimal numbers start with `0x`:

```ruby
0xFE012D # == 16646445
0xfe012d # == 16646445
```
