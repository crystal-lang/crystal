# Compile-time flags

Types, methods and generally any part of your code can be conditionally defined based on some flags available at compile time. These flags are by default the result of executing `uname -m -s`, split by whitespace and lowercased.

```bash
$ uname -m -s
Darwin x86_64

# so the flags are: darwin, x86_64
```

Additionally, if a program is compiled with `--release`, the `release` flag will be true.

You can test these flags with `ifdef`:

```ruby
ifdef x86_64
  # some specific code for 64 bits platforms
else
  # some specific code for non-64 bits platforms
end
```

You can use `&&`, `||` and `|`:

```ruby
ifdef linux && x86_64
  # some specific code for linux 64 bits
end
```

These flags are generally used in C bindings to conditionally define types and functions. For example the very well known `size_t` type is defined like this in Crystal:

```ruby
lib C
  ifdef x86_64
    alias SizeT = UInt64
  else
    alias SizeT = UInt32
  end
end
```

**Note:** conditionally defining fields of a C struct or union is not currently supported. The whole type definition must be defined separately.

```ruby
lib C
  struct SomeStruct
    # Error: the next line gives a parser error
    ifdef linux
      some_field : Int32
    else
      some_field : Int64
    end
  end

  # OK
  ifdef linux
    struct SomeStruct
      some_field : Int32
    end
  else
    struct SomeStruct
      some_field : Int64
    end
  end
end
```

This restriction might be lifted in the future.
