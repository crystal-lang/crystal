# lib

A `lib` declaration groups C functions and types that belong to a library.

```ruby
lib LibPCRE("pcre")
end
```

Although not enforced by the compiler, a `lib`'s name usually starts with `Lib`.

Here, `"pcre"` is the name of the library that will be passed to the linker (for example as `-lpcre`). The name can be ommited if the library is implicitly linked, as in the case of libc.

If the name is a string that has its contents enclosed with backticks, it denotes a shell command that is executed and whose output is passed to the linker.

```ruby
lib LibPCRE("`pkg-config libpcre --libs`")
end
```

**Note:** in the future the linker flags will probably be specified with attributes or with a better mechanism.
