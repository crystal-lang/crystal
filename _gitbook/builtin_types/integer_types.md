# Integer types

There are four signed integer types: `Int8`, `Int16`, `Int32` and `Int64`, being able to represent numbers of 8, 16, 32 and 64 bits respectively. There are four unsigned integer types: `UInt8`, `UInt16`, `UInt32` and `UInt64`.

An integer literal is an optional `+` or `-` sign, followed by  sequence of digits and underscores, optionally followed by a suffix. If no suffix is present, the literal's type is `Int32`.

``` ruby
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
```

The underscore `_` before the suffix is optional.

Underscores can be used to make some numbers more readable:

``` ruby
1_000_000 # better than 1000000
```

Binary numbers start with `0b`:

``` ruby
0b1101 # == 13
```

Octal numbers start with a zero:

``` ruby
0123 # == 83
```

Hexadecimal numbers start with `0x`:

``` ruby
0xFE012D # == 16646445
0xfe012d # == 16646445
```

You can convert an integer to some other integer type using these methods: `to_i8`, `to_i16`, `to_i32`, `to_i64`, `to_u8`, `to_u16`, `to_u32`, `to_u64`. There are also `to_i` and `to_u`, which are just synonims of `to_i32` and `to_u32` respectively.

To convert an integer to a floating point type you can use these methods: `to_f32` and `to_f64`. There is also `to_f`, which is just a synonim of `to_f64`.

To covert an integer to a `Char` you can use `ord`.
