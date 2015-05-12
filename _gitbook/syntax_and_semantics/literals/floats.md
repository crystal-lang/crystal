# Floats

There are two floating point types, [Float32](http://crystal-lang.org/api/Float32.html) and [Float64](http://crystal-lang.org/api/Float64.html),
which correspond to the [binary32](http://en.wikipedia.org/wiki/Single_precision_floating-point_format)
and [binary64](http://en.wikipedia.org/wiki/Double_precision_floating-point_format)
types defined by IEEE.

A floating point literal is an optional `+` or `-` sign, followed by
a sequence of numbers or underscores, followed by a dot,
followed by numbers or underscores, followed by an optional exponent suffix,
followed by an optional type suffix. If no suffix is present, the literal's type is `Float64`.

```ruby
1.0      # Float64
1.0_f32  # Float32
1_f32    # Float32

1e10     # Float64
1.5e10   # Float64
1.5e-7   # Float64

+1.3     # Float64
-0.5     # Float64
```

The underscore `_` before the suffix is optional.

Underscores can be used to make some numbers more readable:

```ruby
1_000_000.111_111 # better than 1000000.111111
```
