# Compile-time flags

Types, methods and generally any part of your code can be conditionally defined based on some flags available at compile time. These flags are by default read from the hosts [LLVM Target Triple](http://llvm.org/docs/LangRef.html#target-triple), split on `-`. To get the target you can execute `llvm-config --host-target`.

```bash
$ llvm-config --host-target
x86_64-unknown-linux-gnu

# so the flags are: x86_64, unknown, linux, gnu
```

Additionally, if a program is compiled with `--release`, the `release` flag will be set.

You can test these flags with the `flag?` macro method:

```crystal
{% if flag?(:x86_64) %}
  # some specific code for 64 bits platforms
{% else %}
  # some specific code for non-64 bits platforms
{% end %}
```

It returns true or false, so you can use `&&` and `||` just normally:

```crystal
{% if flag?(:linux) && flag?(:x86_64) %}
  # some specific code for linux 64 bits
{% end %}
```

These flags are generally used in C bindings to conditionally define types and functions. For example the very well known `size_t` type is defined like this in Crystal:

```crystal
lib C
  {% if flag?(:x86_64) %}
    alias SizeT = UInt64
  {% else %}
    alias SizeT = UInt32
  {% end %}
end
```
