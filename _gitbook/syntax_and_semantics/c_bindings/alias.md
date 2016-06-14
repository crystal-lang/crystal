# alias

An `alias` declaration inside a `lib` declares a C `typedef`:

```crystal
lib X
  alias MyInt = Int32
end
```

Now `Int32` and `MyInt` are interchangeable:

```crystal
lib X
  alias MyInt = Int32

  fun some_fun(value : MyInt)
end

X.some_fun 1 # OK
```

An `alias` is most useful to avoid writing long types over and over, but also to declare a type based on compile-time flags:

```crystal
lib C
  {% if flag?:(x86_64) %}
    alias SizeT = Int64
  {% else %}
    alias SizeT = Int32
  {% end %}

  fun memcmp(p1 : Void*, p2 : Void*, size : C::SizeT) : Int32
end
```

Refer to the [type grammar](../type_grammar.html) for the notation used in alias types.
